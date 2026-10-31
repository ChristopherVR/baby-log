import 'dart:typed_data';

/// Bluetooth protocol spoken by Momcozy breast pumps (M5 Pro / BP380, M9,
/// M9 Pro, M10, Air 1), worked out from the Momcozy app so we can talk to
/// pumps we own. Pure bytes in, bytes out: the Bluetooth link lives elsewhere.
///
/// Every message is one frame:
///
///     AA 55 | cmdType | cmd | len | payload | checksum
///
/// The checksum is the inverted byte sum of everything before it, taken over
/// the plain payload. Once paired the payload is XOR'd with a one-byte key the
/// pump hands out in its device info, except for the commands in [_plainCmds].

const momcozyServiceUuid = '0000af00-0000-1000-8000-00805f9b34fb';
const momcozyWriteUuid = '0000af01-0000-1000-8000-00805f9b34fb';
const momcozyNotifyUuid = '0000af02-0000-1000-8000-00805f9b34fb';

/// Newer firmware moves the same service to these.
const momcozyServiceUuidV3 = '524f4f54-9000-0080-0010-000000010001';
const momcozyNotifyUuidV3 = '524f4f54-9000-0080-0010-000000010002';
const momcozyWriteUuidV3 = '524f4f54-9000-0080-0010-000000010003';

/// The app always negotiates this MTU and splits payloads to fit.
const momcozyMtu = 128;

abstract final class PumpCmd {
  static const deviceInfo = 0xF0;
  static const setClock = 0xF2;
  static const countdown = 0xF4;
  static const identity = 0xF7;
  static const shutdown = 0xFC;
  static const encrypt = 0xFD;
  static const status = 0xB0;
  static const statusPush = 0xD0;
  static const historyCount = 0xBA;
  static const history = 0xBB;
  static const control = 0xC0;
  static const setSide = 0xC1;
  static const fullMilkSwitch = 0xC7;
  static const heating = 0xCA;
  static const postureSwitch = 0xCB;
  static const autoPauseSwitch = 0xCD;
  static const pausePush = 0xD3;
  static const error = 0x1F;
}

/// Commands whose payload is never encrypted, in either direction.
const _plainCmds = {PumpCmd.deviceInfo, PumpCmd.encrypt, PumpCmd.identity};

/// Payload the app sends with [PumpCmd.deviceInfo] to start a connection.
const _helloPayload = [0xAA, 0x55, 0x11, 0x00];

enum PumpModel {
  m9(1),
  air1(3),
  m5Pro(7),
  m10(16),
  m9Pro(0);

  final int code;
  const PumpModel(this.code);

  /// The Momcozy app treats any code it does not know as an M9 Pro.
  static PumpModel fromCode(int code) => PumpModel.values.firstWhere(
    (m) => m.code == code,
    orElse: () => PumpModel.m9Pro,
  );

  /// Highest suction level.
  int get maxLevel => this == m5Pro ? 9 : 12;
}

/// The pump's product code if [manufacturerData] (one whole manufacturer
/// data entry of the advert) is a Momcozy pump. A BP380 sends
/// `aa 07 10 <mac reversed>`: Momcozy puts its 0xAA marker and the product
/// code where Bluetooth expects a company id, so Android reports company
/// 0x07AA with the other 7 bytes.
int? momcozyProductCode(List<int> manufacturerData) {
  if (manufacturerData.length != 9 || manufacturerData[0] != 0xAA) return null;
  return manufacturerData[1];
}

/// [momcozyProductCode] for data already split into company id and payload.
int? momcozyProductCodeOf(int companyId, List<int> payload) =>
    momcozyProductCode([companyId & 0xFF, companyId >> 8 & 0xFF, ...payload]);

/// Service the pumps list in their advert.
const momcozyAdvertService = '0000af30-0000-1000-8000-00805f9b34fb';

enum PumpMode {
  massage(1),
  expression(2),
  mixed(3),
  custom(4),
  auto(5);

  final int code;
  const PumpMode(this.code);

  static PumpMode? fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// Run state in status packets and history records. Seen on a BP380: 0 while
/// switched on but not pumping (including after a pause), 1 while pumping,
/// 3 once switched off. 2 never showed up.
enum PumpRunState {
  stopped(0),
  running(1),
  paused(2),
  off(3);

  final int code;
  const PumpRunState(this.code);

  static PumpRunState? fromCode(int code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

class PumpFrame {
  /// 0 from the phone; from the pump 1 is a reply, 3 a status pushed after a
  /// command, and 4 a status pushed on its own (e.g. a button press).
  final int cmdType;
  final int cmd;

  /// Already decrypted.
  final Uint8List payload;

  PumpFrame(this.cmd, List<int> payload, {this.cmdType = 0})
    : payload = Uint8List.fromList(payload);

  @override
  String toString() =>
      'PumpFrame(${_hex([cmd])} type $cmdType: ${_hex(payload)})';
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');

int _checksum(Iterable<int> bytes) =>
    ~bytes.fold<int>(0, (a, b) => a + b) & 0xFF;

/// Encodes one frame. [key] is the pump's XOR key (0 before pairing).
Uint8List encodePumpFrame(
  int cmd,
  List<int> payload, {
  int key = 0,
  int cmdType = 0,
}) {
  if (payload.length > momcozyMtu - 6) {
    throw ArgumentError('payload too long for one frame');
  }
  final head = [0xAA, 0x55, cmdType & 0xFF, cmd & 0xFF, payload.length];
  final sum = _checksum([...head, ...payload]);
  final k = _plainCmds.contains(cmd) ? 0 : key & 0xFF;
  return Uint8List.fromList([...head, for (final b in payload) b ^ k, sum]);
}

/// Turns notification chunks back into frames. Chunks may split or join
/// frames; bytes that do not form a valid frame are skipped.
class PumpFrameReader {
  /// The pump's XOR key; set it once the device info has been read.
  int key = 0;

  final _buf = <int>[];

  List<PumpFrame> add(List<int> chunk) {
    _buf.addAll(chunk);
    final out = <PumpFrame>[];
    while (true) {
      final start = _findHeader();
      if (start < 0) {
        // Keep a lone trailing AA: it may start the next chunk's frame.
        final keep = _buf.isNotEmpty && _buf.last == 0xAA;
        _buf.clear();
        if (keep) _buf.add(0xAA);
        break;
      }
      if (start > 0) _buf.removeRange(0, start);
      if (_buf.length < 6) break;
      final len = _buf[4];
      if (len > momcozyMtu - 6) {
        _buf.removeAt(0);
        continue;
      }
      if (_buf.length < len + 6) break;
      final cmdType = _buf[2], cmd = _buf[3];
      final k = _plainCmds.contains(cmd) ? 0 : key;
      final payload = [for (final b in _buf.sublist(5, 5 + len)) b ^ k];
      if (_checksum([..._buf.sublist(0, 5), ...payload]) != _buf[5 + len]) {
        _buf.removeAt(0);
        continue;
      }
      _buf.removeRange(0, len + 6);
      out.add(PumpFrame(cmd, payload, cmdType: cmdType));
    }
    return out;
  }

  int _findHeader() {
    for (var i = 0; i + 1 < _buf.length; i++) {
      if (_buf[i] == 0xAA && _buf[i + 1] == 0x55) return i;
    }
    return -1;
  }
}

int _at(List<int> b, int i) => i < b.length ? b[i] : 0;

int _u16be(List<int> b, int i) => (_at(b, i) << 8) | _at(b, i + 1);

/// What the pump says about itself in reply to [PumpCommands.hello].
class PumpDeviceInfo {
  final int productCode;
  final int hardwareVersion;
  final int firmwareVersion;
  final String serial;

  /// XOR key for every later payload; 0 means no encryption. The pump's own
  /// "encrypted" flag reads 0 even when it uses a key, so the app (and we)
  /// go by the key alone.
  final int key;

  PumpDeviceInfo({
    required this.productCode,
    required this.hardwareVersion,
    required this.firmwareVersion,
    required this.serial,
    required this.key,
  });

  PumpModel get model => PumpModel.fromCode(productCode);
  bool get encrypted => key != 0;

  /// The M5 Pro has a longer serial number, which moves the key back.
  static PumpDeviceInfo parse(List<int> p, PumpModel model) {
    final snEnd = model == PumpModel.m5Pro ? 45 : 43;
    final sn = p.length >= snEnd ? p.sublist(10, snEnd) : const <int>[];
    return PumpDeviceInfo(
      productCode: _at(p, 0),
      hardwareVersion: _at(p, 2),
      firmwareVersion: _at(p, 3),
      serial: String.fromCharCodes(sn.where((c) => c >= 0x20 && c < 0x7F))
          .trim(),
      key: _at(p, snEnd + 1),
    );
  }
}

/// Live state, sent in reply to [PumpCmd.status] and pushed as
/// [PumpCmd.statusPush] while the pump runs.
class PumpStatus {
  final int battery;
  final int runStateCode;
  final int sideCode;
  final int modeCode;
  final int level;
  final int frequency;

  /// Seconds since the session started, and into the current mode.
  final int totalSeconds;
  final int modeSeconds;
  final int modeTotalSeconds;

  /// Milk collected so far, as the pump estimates it (ml). Always 0 on the
  /// BP380, which has no volume sensor.
  final int milkMl;
  final int errorCode;

  PumpStatus({
    required this.battery,
    required this.runStateCode,
    required this.sideCode,
    required this.modeCode,
    required this.level,
    required this.frequency,
    required this.totalSeconds,
    required this.modeSeconds,
    required this.modeTotalSeconds,
    required this.milkMl,
    required this.errorCode,
  });

  PumpRunState? get runState => PumpRunState.fromCode(runStateCode);
  PumpMode? get mode => PumpMode.fromCode(modeCode);

  /// Which breast this pump is set to: 0 left, 1 right. With two pumps each
  /// reports its own side.
  bool get isRight => sideCode == 1;

  static PumpStatus parse(List<int> p) => PumpStatus(
    battery: _at(p, 0).clamp(0, 100),
    runStateCode: _at(p, 1),
    sideCode: _at(p, 2),
    modeCode: _at(p, 3),
    level: _at(p, 4),
    frequency: _at(p, 7),
    totalSeconds: _u16be(p, 8),
    modeSeconds: _u16be(p, 10),
    milkMl: _at(p, 12),
    errorCode: _at(p, 13),
    modeTotalSeconds: _u16be(p, 14),
  );

  @override
  String toString() =>
      'PumpStatus(battery $battery%, state $runStateCode, side $sideCode, '
      'mode $modeCode, level $level, ${totalSeconds}s, ${milkMl}ml, '
      'error $errorCode)';
}

/// What a history record says happened.
enum PumpEvent {
  powerKey(1),
  modeKey(2),
  levelUp(3),
  levelDown(4),
  sideKey(5),
  charging(6),
  poweredOn(7),
  poweredOff(8),
  lowBatteryOff(9),
  timeoutOff(10),
  autoPause(11),
  overflow(12);

  final int code;
  const PumpEvent(this.code);

  static PumpEvent? fromCode(int code) {
    for (final e in values) {
      if (e.code == code) return e;
    }
    return null;
  }
}

/// One entry of the event log the pump keeps while it is away from the
/// phone. Sessions are rebuilt from these. Reading them with
/// [PumpCommands.history] removes them from the pump, so only one app gets
/// each record.
class PumpHistoryRecord {
  final DateTime time;
  final int eventCode;
  final int runStateCode;
  final int modeCode;
  final int level;
  final int battery;
  final int milkMl;
  final int vibration;
  final int heating;
  final int posture;

  PumpHistoryRecord({
    required this.time,
    required this.eventCode,
    required this.runStateCode,
    required this.modeCode,
    required this.level,
    required this.battery,
    required this.milkMl,
    required this.vibration,
    required this.heating,
    required this.posture,
  });

  PumpEvent? get event => PumpEvent.fromCode(eventCode);
  PumpRunState? get runState => PumpRunState.fromCode(runStateCode);
  PumpMode? get mode => PumpMode.fromCode(modeCode);

  static const size = 16;

  /// The timestamp is big-endian UTC seconds, like [PumpCommands.setClock].
  static PumpHistoryRecord parse(List<int> r) {
    final secs = _at(r, 0) << 24 | _at(r, 1) << 16 | _at(r, 2) << 8 | _at(r, 3);
    return PumpHistoryRecord(
      time: DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true),
      eventCode: _at(r, 4),
      runStateCode: _at(r, 5),
      modeCode: _at(r, 6),
      level: _at(r, 7),
      battery: _at(r, 8),
      milkMl: _at(r, 9),
      vibration: _at(r, 10),
      heating: _at(r, 11),
      posture: _at(r, 12),
    );
  }

  /// Records in a [PumpCmd.history] reply: a count byte, the records, and
  /// one trailing byte.
  static List<PumpHistoryRecord> parseBatch(List<int> p) {
    if (p.length < 2) return [];
    final body = p.sublist(1, p.length - 1);
    return [
      for (var i = 0; i + size <= body.length; i += size)
        parse(body.sublist(i, i + size)),
    ];
  }
}

/// Number of records waiting in the pump, from a [PumpCmd.historyCount] reply.
int parseHistoryCount(List<int> p) => _u16be(p, 0);

/// Builds the frames the app sends. [key] is 0 until [PumpDeviceInfo.key]
/// is known.
class PumpCommands {
  int key = 0;

  Uint8List _frame(int cmd, [List<int> payload = const []]) =>
      encodePumpFrame(cmd, payload, key: key);

  /// First message after connecting; the reply is a [PumpDeviceInfo].
  Uint8List hello() => _frame(PumpCmd.deviceInfo, _helloPayload);

  /// Confirms the key from [PumpDeviceInfo]; reply has cmdType 1 on success.
  Uint8List confirmKey(int key) => _frame(PumpCmd.encrypt, [key & 0xFF]);

  /// Sets the pump's clock, which stamps its history records.
  Uint8List setClock(DateTime now) {
    final s = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    return _frame(PumpCmd.setClock, [
      s >> 24 & 0xFF,
      s >> 16 & 0xFF,
      s >> 8 & 0xFF,
      s & 0xFF,
    ]);
  }

  Uint8List status() => _frame(PumpCmd.status);
  Uint8List historyCount() => _frame(PumpCmd.historyCount);
  Uint8List history() => _frame(PumpCmd.history);

  /// Switches the pump off; the app's "stop" does this.
  Uint8List shutdown() => _frame(PumpCmd.shutdown, [1]);

  /// Starts or pauses the pump and sets its mode and level, the way the
  /// app's control screen does. For both breasts the app sends the same
  /// command to each pump.
  Uint8List control({
    required PumpRunState state,
    required PumpMode mode,
    required int level,
    int customMode = 1,
    int customLevel = 1,
    int frequency = 1,
  }) => _frame(PumpCmd.control, [
    state.code,
    mode.code,
    level < 1 ? 1 : level,
    customMode,
    customLevel < 1 ? 1 : customLevel,
    frequency,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
  ]);

  Uint8List setSwitch(int cmd, bool on) => _frame(cmd, [on ? 1 : 0]);
}

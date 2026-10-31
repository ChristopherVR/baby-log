import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'pump_session.dart';

/// The firmware channel of Momcozy pumps, which run on a JieLi chip: JieLi's
/// RCSP protocol on GATT service 0xAE00. Before it answers anything else the
/// pump wants a challenge/response handshake built on Bluetooth's legacy E1
/// function with JieLi's stock key.

const jieliServiceUuid = '0000ae00-0000-1000-8000-00805f9b34fb';
const jieliWriteUuid = '0000ae01-0000-1000-8000-00805f9b34fb';
const jieliNotifyUuid = '0000ae02-0000-1000-8000-00805f9b34fb';

/// JieLi's default auth key and the fixed address it is used with.
const _authKey = [
  0x06, 0x77, 0x5f, 0x87, 0x91, 0x8d, 0xd4, 0x23, //
  0x00, 0x5d, 0xf1, 0xd8, 0xcf, 0x0c, 0x14, 0x2b,
];
const _authAddress = [0x11, 0x22, 0x33, 0x33, 0x22, 0x11];

// ---------------------------------------------------------------- SAFER+ / E1

/// Byte positions where SAFER+ uses XOR (the others use addition).
const _xorAt = {0, 3, 4, 7, 8, 11, 12, 15};

/// The "Armenian shuffle" between the PHT layers.
const _shuffle = [8, 11, 12, 15, 2, 1, 6, 5, 10, 9, 14, 13, 0, 7, 4, 3];

final _exp = () {
  final t = List.filled(256, 0);
  var v = 1;
  for (var i = 0; i < 256; i++) {
    t[i] = v & 0xFF; // 45^128 = 256 is stored as 0
    v = (v * 45) % 257;
  }
  return t;
}();

final _log = () {
  final t = List.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    t[_exp[i]] = i;
  }
  return t;
}();

/// The 17 round keys of SAFER+ for a 128-bit key.
List<List<int>> _roundKeys(List<int> key) {
  final reg = [...key, key.fold<int>(0, (a, b) => a ^ b)];
  final keys = <List<int>>[List.of(key)];
  for (var p = 2; p <= 17; p++) {
    for (var i = 0; i < 17; i++) {
      reg[i] = ((reg[i] << 3) | (reg[i] >> 5)) & 0xFF;
    }
    keys.add([
      for (var i = 0; i < 16; i++)
        (reg[(p - 1 + i) % 17] + _exp[_exp[(17 * p + i + 1) & 0xFF]]) & 0xFF,
    ]);
  }
  return keys;
}

/// SAFER+ encryption (Bluetooth's Ar); with [prime], Ar' which adds the
/// input back in before the third round.
List<int> _safer(List<int> key, List<int> input, {bool prime = false}) {
  final k = _roundKeys(key);
  var x = List.of(input);
  for (var r = 0; r < 8; r++) {
    if (prime && r == 2) {
      x = [
        for (var i = 0; i < 16; i++)
          _xorAt.contains(i) ? x[i] ^ input[i] : (x[i] + input[i]) & 0xFF,
      ];
    }
    final k1 = k[2 * r], k2 = k[2 * r + 1];
    for (var i = 0; i < 16; i++) {
      if (_xorAt.contains(i)) {
        x[i] = _exp[x[i] ^ k1[i]];
        x[i] = (x[i] + k2[i]) & 0xFF;
      } else {
        x[i] = _log[(x[i] + k1[i]) & 0xFF];
        x[i] ^= k2[i];
      }
    }
    for (var layer = 0; layer < 4; layer++) {
      for (var i = 0; i < 16; i += 2) {
        final a = x[i], b = x[i + 1];
        x[i] = (2 * a + b) & 0xFF;
        x[i + 1] = (a + b) & 0xFF;
      }
      if (layer < 3) x = [for (final j in _shuffle) x[j]];
    }
  }
  final last = k[16];
  return [
    for (var i = 0; i < 16; i++)
      _xorAt.contains(i) ? x[i] ^ last[i] : (x[i] + last[i]) & 0xFF,
  ];
}

/// Offsets for the second key of E1 (Bluetooth core spec, EQ 15).
const _keyOffsets = [233, 229, 223, 193, 179, 167, 149, 131];

/// Bluetooth's E1: SRES and ACO for [rand], as 16 bytes.
List<int> e1(List<int> key, List<int> rand, List<int> address) {
  // Even bytes of the first half and odd bytes of the second are added to,
  // the rest are XOR'd.
  final offsetKey = [
    for (var i = 0; i < 16; i++)
      (i < 8) == i.isEven
          ? (key[i] + _keyOffsets[i % 8]) & 0xFF
          : key[i] ^ _keyOffsets[i % 8],
  ];
  final first = _safer(key, rand);
  final mixed = [
    for (var i = 0; i < 16; i++) ((first[i] ^ rand[i]) + address[i % 6]) & 0xFF,
  ];
  return _safer(offsetKey, mixed, prime: true);
}

/// The answer the pump expects for its 16-byte [challenge].
List<int> jieliAuthResponse(List<int> challenge) =>
    e1(_authKey, challenge, _authAddress);

// ---------------------------------------------------------------- RCSP frames

/// One RCSP frame: `FE DC BA | flag | opcode | len(2) | payload | EF`.
class RcspFrame {
  /// Bit 7: a command (else a response); bit 6: a response is wanted.
  final int flag;
  final int opcode;
  final Uint8List payload;

  RcspFrame(this.flag, this.opcode, List<int> payload)
    : payload = Uint8List.fromList(payload);

  bool get isCommand => flag & 0x80 != 0;

  /// For responses: 0 is OK.
  int get status => isCommand || payload.isEmpty ? 0 : payload[0];

  /// Parameters after the status and sequence number of a response.
  List<int> get params => payload.length <= (isCommand ? 1 : 2)
      ? const []
      : payload.sublist(isCommand ? 1 : 2);

  Uint8List encode() => Uint8List.fromList([
    0xFE, 0xDC, 0xBA, flag, opcode, //
    payload.length >> 8 & 0xFF, payload.length & 0xFF,
    ...payload,
    0xEF,
  ]);
}

/// Reassembles RCSP frames from notification chunks.
class RcspReader {
  final _buf = <int>[];

  List<RcspFrame> add(List<int> chunk) {
    _buf.addAll(chunk);
    final out = <RcspFrame>[];
    while (true) {
      final start = _start();
      if (start < 0) {
        // Keep a header split across chunks (FE or FE DC at the end).
        var keep = 0;
        if (_buf.isNotEmpty && _buf.last == 0xFE) keep = 1;
        if (_buf.length > 1 &&
            _buf[_buf.length - 2] == 0xFE &&
            _buf.last == 0xDC) {
          keep = 2;
        }
        _buf.removeRange(0, _buf.length - keep);
        break;
      }
      if (start > 0) _buf.removeRange(0, start);
      if (_buf.length < 8) break;
      final len = _buf[5] << 8 | _buf[6];
      if (_buf.length < len + 8) break;
      if (_buf[7 + len] != 0xEF) {
        _buf.removeAt(0);
        continue;
      }
      out.add(RcspFrame(_buf[3], _buf[4], _buf.sublist(7, 7 + len)));
      _buf.removeRange(0, len + 8);
    }
    return out;
  }

  /// Part of a frame is waiting for the rest.
  bool get busy => _buf.isNotEmpty;

  int _start() {
    for (var i = 0; i + 2 < _buf.length; i++) {
      if (_buf[i] == 0xFE && _buf[i + 1] == 0xDC && _buf[i + 2] == 0xBA) {
        return i;
      }
    }
    return -1;
  }
}

/// What the pump's JieLi chip says about itself (GetTargetInfo, 0x03).
class JieliTargetInfo {
  /// Exact firmware version, e.g. "1.0.2.5".
  final String? version;
  final int? versionCode;
  final int? battery;

  /// Keeps the old firmware bootable while updating: an interrupted update
  /// cannot leave the pump unusable.
  final bool? dualBank;
  final bool? needsBootLoader;

  /// Every record by type, for the pump lab.
  final Map<int, List<int>> records;

  JieliTargetInfo({
    this.version,
    this.versionCode,
    this.battery,
    this.dualBank,
    this.needsBootLoader,
    this.records = const {},
  });

  /// Parses the length-type-value records of the reply (length counts the
  /// type byte).
  static JieliTargetInfo parse(List<int> p) {
    final records = <int, List<int>>{};
    var i = 0;
    while (i < p.length) {
      final len = p[i];
      if (len < 1 || i + 1 + len > p.length) break;
      records[p[i + 1]] = p.sublist(i + 2, i + 1 + len);
      i += 1 + len;
    }
    final v = records[5];
    final code = v != null && v.length >= 2 ? v[0] << 8 | v[1] : null;
    final ota = records[8];
    final sys = records[1];
    return JieliTargetInfo(
      versionCode: code,
      version: code == null
          ? null
          : '${code >> 12 & 15}.${code >> 8 & 15}.${code >> 4 & 15}.${code & 15}',
      battery: sys != null && sys.isNotEmpty ? sys[0] : null,
      dualBank: ota != null && ota.isNotEmpty ? ota[0] == 1 : null,
      needsBootLoader: ota != null && ota.length > 1 ? ota[1] == 1 : null,
      records: records,
    );
  }
}

class JieliException implements Exception {
  final String message;
  JieliException(this.message);
  @override
  String toString() => message;
}

/// Talks to the pump's JieLi chip: authenticates, then asks about the
/// firmware. Read-only: nothing here changes the pump.
class JieliSession {
  final PumpTransport transport;
  final Duration timeout;
  final Random _random;

  JieliSession(
    this.transport, {
    this.timeout = const Duration(seconds: 5),
    Random? random,
  }) : _random = random ?? Random.secure() {
    _sub = transport.incoming.listen(_onChunk);
  }

  late final StreamSubscription<List<int>> _sub;
  final _reader = RcspReader();
  final _auth = StreamController<List<int>>.broadcast();
  final _frames = StreamController<RcspFrame>.broadcast();
  bool authed = false;
  int _sn = 0;

  /// Raw packets both ways, for the pump lab.
  final log = <PumpLogLine>[];

  void _onChunk(List<int> chunk) {
    log.add(PumpLogLine(DateTime.now(), false, chunk));
    // Handshake messages are raw (00/01 + 16 bytes, 02 "pass"); anything
    // else is an RCSP frame or part of one.
    final raw =
        !_reader.busy &&
        chunk.isNotEmpty &&
        chunk[0] != 0xFE &&
        (chunk.length == 17 || chunk.length == 5);
    if (raw) {
      _auth.add(chunk);
    } else {
      for (final f in _reader.add(chunk)) {
        _frames.add(f);
      }
    }
  }

  Future<void> _send(List<int> bytes) {
    log.add(PumpLogLine(DateTime.now(), true, bytes));
    return transport.send(Uint8List.fromList(bytes));
  }

  /// Waits for a handshake message; set up before sending so nothing is
  /// missed. A timeout before it is awaited is not reported twice.
  Future<List<int>> _nextAuth(bool Function(List<int>) want) {
    final f = _auth.stream
        .firstWhere(want)
        .timeout(
          timeout,
          onTimeout: () => throw JieliException('The pump did not answer'),
        );
    f.ignore();
    return f;
  }

  static const _pass = [0x02, 0x70, 0x61, 0x73, 0x73]; // 02 "pass"

  /// The challenge/response both ways that JieLi chips require.
  Future<void> authenticate() async {
    final theirChallenge = _nextAuth((b) => b.length == 17 && b[0] == 0x00);
    // "Reset auth flag", then our challenge.
    await _send(const [
      0xFE,
      0xDC,
      0xBA,
      0xC0,
      0x06,
      0x00,
      0x02,
      0x00,
      0x01,
      0xEF,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ours = List.generate(16, (_) => _random.nextInt(256));
    final answer = _nextAuth((b) => b.length == 17 && b[0] == 0x01);
    await _send([0x00, ...ours]);
    final got = await answer;
    final want = jieliAuthResponse(ours);
    for (var i = 0; i < 16; i++) {
      if (got[i + 1] != want[i]) {
        throw JieliException('The pump answered the check wrongly');
      }
    }
    final done = _nextAuth((b) => b.length == 5 && b[0] == 0x02);
    await _send(_pass);
    final challenge = await theirChallenge;
    await _send([0x01, ...jieliAuthResponse(challenge.sublist(1))]);
    await done;
    authed = true;
  }

  Future<RcspFrame> _command(int opcode, List<int> params) async {
    final sn = _sn = (_sn + 1) & 0xFF;
    final reply = _frames.stream
        .firstWhere((f) => !f.isCommand && f.opcode == opcode)
        .timeout(
          timeout,
          onTimeout: () => throw JieliException('The pump did not answer'),
        );
    reply.ignore();
    await _send(RcspFrame(0xC0, opcode, [sn, ...params]).encode());
    final f = await reply;
    if (f.status != 0) {
      throw JieliException('The pump refused (status ${f.status})');
    }
    return f;
  }

  /// Version, battery and how the pump updates. Authenticates first.
  Future<JieliTargetInfo> targetInfo() async {
    if (!authed) await authenticate();
    final f = await _command(0x03, const [0xFF, 0xFF, 0xFF, 0xFF, 0x00]);
    return JieliTargetInfo.parse(f.params);
  }

  void dispose() {
    _sub.cancel();
    _auth.close();
    _frames.close();
  }
}

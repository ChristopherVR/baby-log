import 'dart:async';

import 'package:flutter/foundation.dart';

import 'momcozy.dart';

/// The Bluetooth link to one pump, kept apart so sessions can be tested
/// without a radio.
abstract class PumpTransport {
  /// Notification chunks from the pump.
  Stream<List<int>> get incoming;
  Future<void> send(Uint8List bytes);
}

/// One line of the raw packet log.
class PumpLogLine {
  final DateTime at;
  final bool outgoing;
  final Uint8List bytes;

  PumpLogLine(this.at, this.outgoing, List<int> bytes)
    : bytes = Uint8List.fromList(bytes);

  @override
  String toString() {
    final t = at.toIso8601String().substring(11, 23);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    return '$t ${outgoing ? 'TX' : 'RX'} $hex';
  }
}

class PumpException implements Exception {
  final String message;
  PumpException(this.message);
  @override
  String toString() => message;
}

/// Talks to one connected pump: pairs, follows its status, sends controls
/// and reads its history.
class PumpSession extends ChangeNotifier {
  final PumpTransport transport;

  /// How long to wait for a reply before trying again.
  final Duration replyTimeout;

  PumpSession(
    this.transport, {
    this.replyTimeout = const Duration(seconds: 3),
  }) {
    _sub = transport.incoming.listen(_onChunk);
  }

  final _reader = PumpFrameReader();
  final _cmds = PumpCommands();
  final _waiting = <int, Completer<PumpFrame>>{};
  late final StreamSubscription<List<int>> _sub;

  PumpDeviceInfo? info;
  PumpStatus? status;
  bool ready = false;

  /// Raw packets both ways, newest last.
  final log = <PumpLogLine>[];
  static const _logLimit = 3000;

  final _frames = StreamController<PumpFrame>.broadcast();

  /// Every frame the pump sends, decrypted.
  Stream<PumpFrame> get frames => _frames.stream;

  /// Set when the user picked the model because the pump did not say.
  PumpModel? modelOverride;

  PumpModel get model => modelOverride ?? info?.model ?? PumpModel.m5Pro;

  void _addLog(bool outgoing, List<int> bytes) {
    log.add(PumpLogLine(DateTime.now(), outgoing, bytes));
    if (log.length > _logLimit) log.removeRange(0, log.length - _logLimit);
  }

  void _onChunk(List<int> chunk) {
    _addLog(false, chunk);
    for (final f in _reader.add(chunk)) {
      _frames.add(f);
      if (f.cmd == PumpCmd.status || f.cmd == PumpCmd.statusPush) {
        final st = status = PumpStatus.parse(f.payload);
        lastStatusAt = DateTime.now();
        if (st.runState == _wantState &&
            st.mode == _wantMode &&
            st.level == _wantLevel) {
          _wantAt = null;
        }
        notifyListeners();
      }
      // Replies are cmdType 1; status pushes (3, 4) never answer a request.
      if (f.cmdType == 1) _waiting.remove(f.cmd)?.complete(f);
    }
  }

  Future<void> _send(Uint8List frame) async {
    _addLog(true, frame);
    await transport.send(frame);
  }

  Future<void> _queue = Future.value();

  /// Sends [frame] and waits for the reply to [cmd], trying twice. Requests
  /// go one at a time, like the Momcozy app sends them.
  Future<PumpFrame> _request(int cmd, Uint8List Function() frame) {
    final result = _queue.then((_) => _exchange(cmd, frame));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<PumpFrame> _exchange(int cmd, Uint8List Function() frame) async {
    for (var attempt = 0; ; attempt++) {
      final c = Completer<PumpFrame>();
      _waiting[cmd] = c;
      await _send(frame());
      try {
        return await c.future.timeout(replyTimeout);
      } on TimeoutException {
        _waiting.remove(cmd);
        if (attempt >= 1) {
          throw PumpException(
            'No reply from the pump (0x${cmd.toRadixString(16)})',
          );
        }
      }
    }
  }

  /// Pairs with the pump the way the Momcozy app does: device info, key
  /// confirmation, first status, then the clock.
  Future<void> start() async {
    final hello = await _request(PumpCmd.deviceInfo, _cmds.hello);
    final code = hello.payload.isEmpty ? 0 : hello.payload[0];
    final i = PumpDeviceInfo.parse(
      hello.payload,
      modelOverride ?? PumpModel.fromCode(code),
    );
    info = i;
    if (i.key != 0) {
      final ok = await _request(PumpCmd.encrypt, () => _cmds.confirmKey(i.key));
      if (ok.cmdType != 1) throw PumpException('The pump refused the key');
      _reader.key = i.key;
      _cmds.key = i.key;
    }
    await refreshStatus();
    await _request(PumpCmd.setClock, () => _cmds.setClock(DateTime.now()));
    ready = true;
    notifyListeners();
  }

  Future<PumpStatus?> refreshStatus() async {
    await _request(PumpCmd.status, _cmds.status);
    return status;
  }

  int _clampLevel(int level) => level.clamp(1, model.maxLevel);

  /// Sets state, mode and level in one go; anything left out stays as the
  /// pump last reported it.
  Future<void> control({PumpRunState? state, PumpMode? mode, int? level}) {
    // Show the change at once; the pump confirms it a moment later.
    _wantState = state ?? shownState ?? PumpRunState.stopped;
    _wantMode = mode ?? shownMode ?? PumpMode.massage;
    _wantLevel = _clampLevel(level ?? shownLevel);
    _wantAt = DateTime.now();
    notifyListeners();
    // Built when its turn comes, so quick taps send the latest wish.
    return _request(
      PumpCmd.control,
      () => _cmds.control(
        state: _wantState!,
        mode: _wantMode!,
        level: _wantLevel!,
      ),
    );
  }

  // What the user last asked for, shown until the pump reports it, or for
  // a few seconds if it says otherwise.
  PumpRunState? _wantState;
  PumpMode? _wantMode;
  int? _wantLevel;
  DateTime? _wantAt;
  static const _settle = Duration(seconds: 3);

  bool get _wanting =>
      _wantAt != null && DateTime.now().difference(_wantAt!) < _settle;

  PumpRunState? get shownState =>
      (_wanting ? _wantState : null) ?? status?.runState;
  PumpMode? get shownMode => (_wanting ? _wantMode : null) ?? status?.mode;
  int get shownLevel => (_wanting ? _wantLevel : null) ?? status?.level ?? 1;

  /// A request is waiting for its reply.
  bool get busy => _waiting.isNotEmpty;

  DateTime? lastStatusAt;

  Future<void> resume() => control(state: PumpRunState.running);
  Future<void> pause() => control(state: PumpRunState.stopped);

  Future<void> setMode(PumpMode mode) => control(mode: mode);

  Future<void> changeLevel(int delta) => control(level: shownLevel + delta);

  /// Switches the pump off, as the Momcozy app's stop does.
  Future<void> switchOff() => _request(PumpCmd.shutdown, _cmds.shutdown);

  /// Reads (and so removes) every event record the pump has stored.
  Future<List<PumpHistoryRecord>> readHistory() async {
    final out = <PumpHistoryRecord>[];
    for (var i = 0; i < 64; i++) {
      final count = await _request(PumpCmd.historyCount, _cmds.historyCount);
      if (parseHistoryCount(count.payload) == 0) break;
      final batch = await _request(PumpCmd.history, _cmds.history);
      final records = PumpHistoryRecord.parseBatch(batch.payload);
      if (records.isEmpty) break;
      out.addAll(records);
    }
    return out;
  }

  @override
  void dispose() {
    _sub.cancel();
    for (final c in _waiting.values) {
      if (!c.isCompleted) c.completeError(PumpException('Disconnected'));
    }
    _waiting.clear();
    _frames.close();
    super.dispose();
  }
}

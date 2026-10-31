import 'dart:async';
import 'dart:typed_data';

import 'package:baby_app/src/momcozy.dart';
import 'package:baby_app/src/pump_session.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> hex(String s) => [
  for (final b in s.split(' ')) int.parse(b, radix: 16),
];

/// Device info from a real BP380 (key 0x53).
final _info = hex(
  'aa 55 01 f0 35 07 01 0c 14 00 00 00 00 0b 00 4d 35 50 30 42 50 33 38 30 47 '
  '52 44 41 43 31 31 30 41 44 30 43 30 34 30 45 36 37 44 32 31 31 30 39 36 38 '
  '00 53 00 00 00 00 00 00 45',
);

/// A pretend BP380 that answers like the real one did in a capture.
class FakePump implements PumpTransport {
  final _out = StreamController<List<int>>.broadcast();
  final _reader = PumpFrameReader();
  final sent = <PumpFrame>[];
  var key = 0;
  var status = [97, 0, 1, 1, 9, 1, 1, 1, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0];
  final history = <List<int>>[];

  /// Commands to leave unanswered, once per entry, to test retries.
  final ignoreOnce = <int>[];

  @override
  Stream<List<int>> get incoming => _out.stream;

  void _reply(int cmd, [List<int> payload = const []]) => scheduleMicrotask(
    () => _out.add(encodePumpFrame(cmd, payload, key: key, cmdType: 1)),
  );

  @override
  Future<void> send(Uint8List bytes) async {
    for (final f in _reader.add(bytes)) {
      sent.add(f);
      if (ignoreOnce.remove(f.cmd)) continue;
      switch (f.cmd) {
        case PumpCmd.deviceInfo:
          scheduleMicrotask(() => _out.add(_info));
        case PumpCmd.encrypt:
          _reply(PumpCmd.encrypt);
          key = f.payload[0];
          _reader.key = key;
        case PumpCmd.status:
          _reply(PumpCmd.status, status);
        case PumpCmd.historyCount:
          _reply(PumpCmd.historyCount, [0, history.length]);
        case PumpCmd.history:
          final batch = history.take(4).toList();
          history.removeRange(0, batch.length);
          _reply(PumpCmd.history, [
            batch.length,
            for (final r in batch) ...r,
            0,
          ]);
        default:
          _reply(f.cmd);
      }
    }
  }
}

List<int> record(int secs, int event, int state) => [
  secs >> 24 & 0xFF, secs >> 16 & 0xFF, secs >> 8 & 0xFF, secs & 0xFF,
  event, state, 1, 9, 97, 0, 0, 0, 0, 0, 0, 0, //
];

void main() {
  test('pairs like the Momcozy app and then talks encrypted', () async {
    final pump = FakePump();
    final s = PumpSession(pump);
    await s.start();

    expect(pump.sent.map((f) => f.cmd), [
      PumpCmd.deviceInfo,
      PumpCmd.encrypt,
      PumpCmd.status,
      PumpCmd.setClock,
    ]);
    expect(pump.sent[1].payload, [0x53]);
    expect(s.ready, isTrue);
    expect(s.info!.serial, 'M5P0BP380GRDAC110AD0C040E67D2110968');
    expect(s.status!.battery, 97);
    expect(s.status!.isRight, isTrue);
    expect(s.log.where((l) => l.outgoing), hasLength(4));
  });

  test('controls build on what was last asked for', () async {
    final pump = FakePump();
    final s = PumpSession(pump);
    await s.start();

    await s.resume();
    await s.changeLevel(20);
    expect(pump.sent[4].payload.sublist(0, 3), [1, 1, 9]);
    expect(pump.sent[5].payload.sublist(0, 3), [1, 1, 9]);

    await s.setMode(PumpMode.expression);
    expect(pump.sent.last.payload.sublist(0, 3), [1, 2, 9]);
    await s.switchOff();
    expect(pump.sent.last.cmd, PumpCmd.shutdown);
  });

  test('reads history in batches until the pump is empty', () async {
    final pump = FakePump();
    final base = DateTime.utc(2026, 10, 31, 4).millisecondsSinceEpoch ~/ 1000;
    pump.history.addAll([
      for (var i = 0; i < 6; i++) record(base + i * 60, i.isEven ? 1 : 8, 1),
    ]);
    final s = PumpSession(pump);
    await s.start();

    final rs = await s.readHistory();
    expect(rs, hasLength(6));
    expect(rs.last.time, DateTime.utc(2026, 10, 31, 4, 5));
    expect(pump.history, isEmpty);
  });

  test('asks again when a reply goes missing', () async {
    final pump = FakePump()..ignoreOnce.add(PumpCmd.status);
    final s = PumpSession(pump, replyTimeout: const Duration(milliseconds: 50));
    await s.start();
    expect(pump.sent.where((f) => f.cmd == PumpCmd.status), hasLength(2));
  });

  test('gives up after two missing replies and keeps working', () async {
    final pump = FakePump();
    final s = PumpSession(pump, replyTimeout: const Duration(milliseconds: 50));
    await s.start();
    pump.ignoreOnce.addAll([PumpCmd.shutdown, PumpCmd.shutdown]);
    await expectLater(s.switchOff(), throwsA(isA<PumpException>()));
    await expectLater(s.resume(), completes);
  });

  test('quick taps show at once and each step counts', () async {
    final pump = FakePump()..status[4] = 4;
    final s = PumpSession(pump);
    await s.start();
    final a = s.changeLevel(1);
    final b = s.changeLevel(1);
    expect(s.shownLevel, 6);
    await Future.wait([a, b]);
    final levels = [
      for (final f in pump.sent)
        if (f.cmd == PumpCmd.control) f.payload[2],
    ];
    expect(levels.last, 6);
  });
}

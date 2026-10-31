import 'package:baby_app/src/momcozy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hello frame matches the bytes the Momcozy app sends', () {
    expect(PumpCommands().hello(), [
      0xAA, 0x55, 0x00, 0xF0, 0x04, 0xAA, 0x55, 0x11, 0x00, 0xFC, //
    ]);
  });

  test('payloads are XOR\'d but the checksum covers the plain bytes', () {
    final frame = encodePumpFrame(0xC0, [0x01, 0x02], key: 0x10);
    expect(frame.sublist(5, 7), [0x11, 0x12]);
    final plainSum = 0xAA + 0x55 + 0x00 + 0xC0 + 0x02 + 0x01 + 0x02;
    expect(frame.last, ~plainSum & 0xFF);
  });

  test('pairing commands stay unencrypted even with a key', () {
    final cmds = PumpCommands()..key = 0x5A;
    expect(cmds.confirmKey(0x5A).sublist(3, 6), [0xFD, 0x01, 0x5A]);
    expect(cmds.hello().sublist(5, 9), [0xAA, 0x55, 0x11, 0x00]);
  });

  test('reader reassembles split, joined and noisy chunks', () {
    final status = List.filled(18, 0)
      ..[0] = 80
      ..[1] = 1
      ..[3] = 2
      ..[4] = 5
      ..[8] = 0x01
      ..[9] = 0x2C
      ..[12] = 45;
    final a = encodePumpFrame(PumpCmd.statusPush, status, key: 0x5A);
    final b = encodePumpFrame(PumpCmd.historyCount, [0x00, 0x03], key: 0x5A);
    final stream = [0x00, 0x13, ...a, ...b];
    final reader = PumpFrameReader()..key = 0x5A;

    final frames = [
      ...reader.add(stream.sublist(0, 7)),
      ...reader.add(stream.sublist(7, 20)),
      ...reader.add(stream.sublist(20)),
    ];
    expect(frames.map((f) => f.cmd), [
      PumpCmd.statusPush,
      PumpCmd.historyCount,
    ]);

    final s = PumpStatus.parse(frames[0].payload);
    expect(s.battery, 80);
    expect(s.runState, PumpRunState.running);
    expect(s.mode, PumpMode.expression);
    expect(s.level, 5);
    expect(s.totalSeconds, 300);
    expect(s.milkMl, 45);
    expect(parseHistoryCount(frames[1].payload), 3);
  });

  test('reader drops a frame with a bad checksum and keeps going', () {
    final bad = encodePumpFrame(PumpCmd.status, [1, 2, 3]);
    bad[bad.length - 1] ^= 0xFF;
    final good = encodePumpFrame(PumpCmd.status, [4, 5, 6]);
    final frames = PumpFrameReader().add([...bad, ...good]);
    expect(frames, hasLength(1));
    expect(frames.single.payload, [4, 5, 6]);
  });

  test('clock is a big-endian UTC unix time', () {
    final f = PumpCommands().setClock(DateTime.utc(2026, 1, 1));
    final s = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000;
    expect(f.sublist(5, 9), [
      s >> 24 & 0xFF,
      s >> 16 & 0xFF,
      s >> 8 & 0xFF,
      s & 0xFF,
    ]);
  });

  test('adverts are recognised by the 0xAA company code', () {
    expect(momcozyProductCode([0xAA, 7, 1, 0, 0, 0, 0, 0, 0]), 7);
    // A real BP380 advert, as Android splits it: company 0x07AA + 7 bytes.
    expect(
      momcozyProductCodeOf(0x07AA, [0x10, 0xd7, 0x05, 0xa7, 0x10, 0xc1, 0xda]),
      7,
    );
    expect(momcozyProductCodeOf(0x05D6, [0x08, 0, 0x4a, 0x4c, 0x41]), isNull);
    expect(momcozyProductCode([0xAB, 7, 1, 0, 0, 0, 0, 0, 0]), isNull);
    expect(PumpModel.fromCode(7), PumpModel.m5Pro);
    expect(PumpModel.fromCode(99), PumpModel.m9Pro);
  });

  // Frames captured from two BP380 pumps talking to the Momcozy app.
  group('BP380 capture', () {
    List<int> hex(String s) => [
      for (final b in s.split(' ')) int.parse(b, radix: 16),
    ];

    const info =
        'aa 55 01 f0 35 07 01 0c 14 00 00 00 00 0b 00 4d 35 50 30 42 50 33 38 '
        '30 47 52 44 41 43 31 31 30 41 44 30 43 30 34 30 45 36 37 44 32 31 31 '
        '30 39 36 38 00 53 00 00 00 00 00 00 45';

    test('device info gives the model, serial and key', () {
      final f = PumpFrameReader().add(hex(info)).single;
      expect(f.cmdType, 1);
      final i = PumpDeviceInfo.parse(f.payload, PumpModel.m5Pro);
      expect(i.model, PumpModel.m5Pro);
      expect(i.serial, 'M5P0BP380GRDAC110AD0C040E67D2110968');
      expect(i.firmwareVersion, 20);
      expect(i.key, 0x53);
      expect(i.encrypted, isTrue);
    });

    test('status decrypts with the key', () {
      final reader = PumpFrameReader()..key = 0x53;
      final f = reader
          .add(
            hex(
              'aa 55 01 b0 12 32 53 52 52 5a 52 52 52 53 56 53 56 53 53 53 53 '
              '53 53 c4',
            ),
          )
          .single;
      final s = PumpStatus.parse(f.payload);
      expect(s.battery, 97);
      expect(s.runState, PumpRunState.stopped);
      expect(s.isRight, isTrue);
      expect(s.mode, PumpMode.massage);
      expect(s.level, 9);
      expect(s.totalSeconds, 5);
    });

    test('history records come out in order', () {
      final reader = PumpFrameReader()..key = 0x53;
      final f = reader
          .add(
            hex(
              'aa 55 01 bb 42 57 39 b6 34 ac 52 52 52 5a 32 53 53 53 53 53 53 '
              '53 39 b6 3b 52 5b 52 52 5a 32 53 53 53 53 53 53 53 39 b6 3d f4 '
              '54 52 52 5a 32 53 53 53 53 53 53 53 39 b6 3d ff 52 53 52 5a 32 '
              '53 53 53 53 53 53 53 53 04',
            ),
          )
          .single;
      final rs = PumpHistoryRecord.parseBatch(f.payload);
      expect(rs.map((r) => r.event), [
        PumpEvent.powerKey,
        PumpEvent.poweredOff,
        PumpEvent.poweredOn,
        PumpEvent.powerKey,
      ]);
      expect(rs.first.time, DateTime.utc(2026, 10, 31, 4, 1, 3));
      expect(rs.first.runState, PumpRunState.running);
      expect(rs.first.level, 9);
      expect(rs.first.battery, 97);
      expect(rs.last.runState, PumpRunState.stopped);
    });

    test('commands match what the app sent', () {
      final a = PumpCommands()..key = 0x53;
      expect(
        a.setClock(DateTime.utc(2026, 10, 31, 4, 29, 33)),
        hex('aa 55 00 f2 04 39 b6 3d fe a0'),
      );
      final b = PumpCommands()..key = 0x01;
      expect(
        b.control(
          state: PumpRunState.running,
          mode: PumpMode.massage,
          level: 4,
        ),
        hex('aa 55 00 c0 0a 00 00 05 00 00 00 fe fe fe fe 31'),
      );
      expect(b.shutdown(), hex('aa 55 00 fc 01 00 02'));
      expect(b.confirmKey(0x01), hex('aa 55 00 fd 01 01 01'));
    });
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:baby_app/src/jieli.dart';
import 'package:baby_app/src/pump_session.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

void main() {
  test('auth answers a JieLi challenge like a real device did', () {
    // Published capture (Quarkslab, "A Modern Tale of Blinkenlights").
    expect(
      jieliAuthResponse(hex('ABB2CDC69BB454110E827441213DDC87')),
      hex('61721F97C869523CCCE093D7F849CA02'),
    );
  });

  test('frames survive being split across notifications', () {
    final frame = RcspFrame(0x00, 0x03, [0, 7, 3, 5, 0x10, 0x25]).encode();
    final r = RcspReader();
    expect(r.add(frame.sublist(0, 4)), isEmpty);
    final f = r.add(frame.sublist(4)).single;
    expect((f.opcode, f.status), (0x03, 0));
    expect(f.params, [3, 5, 0x10, 0x25]);
  });

  test('target info gives version, battery and backup support', () {
    final i = JieliTargetInfo.parse([
      5, 1, 80, 50, 100, 0, //  system info: battery 80
      3, 5, 0x10, 0x25, //       version 1.0.2.5
      5, 8, 1, 0, 0, 0, //       OTA settings: dual bank
    ]);
    expect(i.battery, 80);
    expect(i.version, '1.0.2.5');
    expect(i.dualBank, isTrue);
    expect(i.needsBootLoader, isFalse);
  });

  test('handshake both ways, then target info', () async {
    final chip = FakeJieli();
    final s = JieliSession(chip, timeout: const Duration(seconds: 1));
    final info = await s.targetInfo();
    expect(s.authed, isTrue);
    expect(chip.checkedUs, isTrue);
    expect(info.version, '0.0.1.9');
    expect(info.dualBank, isFalse);
  });

  test('a wrong answer from the chip stops the handshake', () async {
    final chip = FakeJieli()..lie = true;
    final s = JieliSession(chip, timeout: const Duration(seconds: 1));
    await expectLater(s.authenticate(), throwsA(isA<JieliException>()));
    expect(s.authed, isFalse);
  });
}

/// A pretend JieLi chip running the device side of RCSP.
class FakeJieli implements PumpTransport {
  final _out = StreamController<List<int>>.broadcast();
  final _reader = RcspReader();
  final _mine = List.generate(16, (i) => i * 7 & 0xFF);
  bool lie = false;
  bool checkedUs = false;

  @override
  Stream<List<int>> get incoming => _out.stream;

  void _emit(List<int> b) => scheduleMicrotask(() => _out.add(b));

  @override
  Future<void> send(Uint8List b) async {
    if (b[0] == 0xFE) {
      for (final f in _reader.add(b)) {
        if (f.opcode == 0x03) {
          _emit(
            RcspFrame(0x00, 0x03, [
              0, f.payload[0], //
              3, 5, 0x00, 0x19,
              5, 8, 0, 1, 0, 0,
            ]).encode(),
          );
        }
      }
      return;
    }
    if (b.length == 17 && b[0] == 0x00) {
      final answer = jieliAuthResponse(b.sublist(1));
      if (lie) answer[0] ^= 1;
      _emit([0x01, ...answer]);
    } else if (b.length == 5 && b[0] == 0x02) {
      _emit([0x00, ..._mine]);
    } else if (b.length == 17 && b[0] == 0x01) {
      final want = jieliAuthResponse(_mine);
      checkedUs = List.generate(16, (i) => b[i + 1] == want[i]).every((x) => x);
      if (checkedUs) _emit([0x02, 0x70, 0x61, 0x73, 0x73]);
    }
  }
}

import 'dart:convert';

import 'package:baby_app/src/qr_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payload survives being split into codes and scanned out of order', () {
    final payload = {
      'app': 'babylog-qr',
      'entries': [for (var i = 0; i < 300; i++) {'id': 'e$i', 'type': 'feed', 'time': 1792000000000 + i * 60000}],
    };
    final codes = QrTransfer.encode(payload);
    expect(codes.length, greaterThan(1));

    final collector = QrCollector();
    for (final c in codes.reversed) {
      expect(collector.add(c), isTrue);
      expect(collector.add(c), isFalse, reason: 'the same code twice counts once');
    }
    expect(collector.done, isTrue);
    expect(jsonEncode(collector.result()), jsonEncode(payload));
  });

  test('a new set of codes from the other phone starts over', () {
    final first = QrTransfer.encode({'n': List.filled(2000, 'a')});
    final second = QrTransfer.encode({'n': 'b'});
    final collector = QrCollector()..add(first.first);
    collector.add(second.single);
    expect(collector.done, isTrue);
    expect(collector.result()['n'], 'b');
  });

}

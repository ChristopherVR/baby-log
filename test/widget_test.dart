import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Medication.slots', () {
    test('times a day spreads doses over 24 hours from the start time', () {
      final med = Medication(name: 'Iron', mode: ScheduleMode.timesPerDay, count: 3, startMinutes: 7 * 60);
      expect(med.slots, [7 * 60, 15 * 60, 23 * 60]);
    });

    test('every X hours restarts each day at the start time', () {
      final med = Medication(name: 'Pain', mode: ScheduleMode.everyHours, count: 5, startMinutes: 8 * 60);
      expect(med.slots, [4 * 60, 8 * 60, 13 * 60, 18 * 60, 23 * 60]);
    });

    test('once a day', () {
      final med = Medication(name: 'Vit', count: 1, startMinutes: 9 * 60 + 30);
      expect(med.slots, [9 * 60 + 30]);
    });
  });

  group('mergeInto', () {
    test('newest copy wins and deletes propagate', () {
      final t0 = DateTime(2026, 1, 1, 10);
      final a = Entry(id: 'x', type: EntryType.nappy, time: t0, nappy: NappyKind.pee, updatedAt: t0);
      final edited = Entry(id: 'x', type: EntryType.nappy, time: t0, nappy: NappyKind.both, updatedAt: t0.add(const Duration(minutes: 1)));
      final current = {'x': a};

      expect(mergeInto(current, [edited]), isTrue);
      expect(current['x']!.nappy, NappyKind.both);

      // An older copy arriving later does not overwrite.
      expect(mergeInto(current, [a]), isFalse);
      expect(current['x']!.nappy, NappyKind.both);

      final deleted = Entry.fromJson({...edited.toJson(), 'deleted': true, 'updatedAt': t0.add(const Duration(minutes: 2)).millisecondsSinceEpoch})!;
      mergeInto(current, [deleted]);
      expect(current['x']!.deleted, isTrue);
    });

    test('exact ties resolve the same way on both phones', () {
      final t = DateTime(2026, 1, 1, 10);
      final a = Entry(id: 'x', type: EntryType.nappy, time: t, nappy: NappyKind.pee, updatedAt: t);
      final b = Entry(id: 'x', type: EntryType.nappy, time: t, nappy: NappyKind.poo, updatedAt: t);
      final phone1 = {'x': a}, phone2 = {'x': b};
      mergeInto(phone1, [b]);
      mergeInto(phone2, [a]);
      expect(phone1['x']!.nappy, phone2['x']!.nappy);
    });

    test('mergeChanged reports only new or newer records', () {
      final t = DateTime(2026, 1, 1, 10);
      final old = Entry(id: 'a', type: EntryType.feed, time: t, updatedAt: t);
      final current = {'a': old};
      final changed = mergeChanged(current, [
        old,
        Entry(id: 'b', type: EntryType.feed, time: t, updatedAt: t),
      ]);
      expect(changed.map((e) => e.id), ['b']);
    });

    test('entries round-trip through JSON', () {
      final e = Entry(type: EntryType.feed, time: DateTime(2026, 3, 4, 5, 6), side: FeedSide.right, durationMin: 12);
      final back = Entry.fromJson(e.toJson())!;
      expect(back.side, FeedSide.right);
      expect(back.durationMin, 12);
      expect(back.time, e.time);
    });
  });

  test('pairing QR round-trips', () {
    final info = PairInfo.parse(PairInfo('192.168.1.23', 8766, '482913').toUri())!;
    expect((info.host, info.port, info.key), ('192.168.1.23', 8766, '482913'));
    expect(PairInfo.parse('https://example.com'), isNull);
  });

  test('bug-fix versions sync freely, feature versions need accepting', () {
    AppState.appVersion = '1.2.0';
    expect(AppState.sameFeatures('1.2.1'), isTrue);
    expect(AppState.sameFeatures('1.3.0'), isFalse);
    expect(AppState.sameFeatures(olderVersion), isFalse);
  });
}

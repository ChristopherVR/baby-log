import 'dart:io';

import 'package:baby_app/src/history_stats.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/history_page.dart';
import 'package:baby_app/src/ui/home_page.dart';
import 'package:baby_app/src/ui/sheets.dart';
import 'package:baby_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late Directory dir;
  late AppState app;
  setUp(() async {
    await initializeDateFormatting('en');
    dir = await Directory.systemTemp.createTemp('sleep-history-');
    app = await AppState.loadForTesting(
      File('${dir.path}/app.json'),
      persist: false,
    );
  });
  tearDown(() async {
    app.dispose();
    await app.pendingSave;
    await dir.delete(recursive: true);
  });

  test(
    'nap survives restart; completed nap merges and stale end is ignored',
    () async {
      app.dispose();
      app = await AppState.loadForTesting(File('${dir.path}/persist.json'));
      final start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      );
      expect(app.startSleep(time: start), isTrue);
      expect(app.startSleep(), isFalse);
      await app.pendingSave;
      final loaded = await AppState.loadForTesting(File(app.dataFilePath));
      final other = await AppState.loadForTesting(
        File('${dir.path}/other.json'),
        persist: false,
      );
      try {
        final nap = loaded.activeSleep!;
        expect(nap.time, start);
        expect(
          loaded.endSleep(
            nap,
            time: start.subtract(const Duration(minutes: 1)),
          ),
          isFalse,
        );
        expect(
          loaded.endSleep(nap, time: start.add(const Duration(hours: 1))),
          isTrue,
        );
        expect(loaded.endSleep(nap), isFalse);
        final imported = other.importBackup(loaded.exportBackup());
        expect(imported.entries, 1);
        expect(other.activeSleep, isNull);
        expect(
          other.entries.single.endTime,
          start.add(const Duration(hours: 1)),
        );
        other.deleteEntry(other.entries.single);
        expect(other.counts['sleep'], 0);
      } finally {
        loaded.dispose();
        other.dispose();
        await loaded.pendingSave;
      }
    },
  );

  test('ongoing naps stay with their baby when switching profiles', () {
    final firstBaby = app.activeBabyId;
    app.startSleep();
    final firstNap = app.activeSleep!;
    app.addBaby('Second baby');
    expect(app.activeSleep, isNull);
    expect(app.startSleep(), isTrue);
    final secondNap = app.activeSleep!;
    expect(secondNap.id, isNot(firstNap.id));
    app.selectBaby(firstBaby);
    expect(app.activeSleep!.id, firstNap.id);
    app.endSleep(firstNap);
    expect(app.activeSleep, isNull);
    expect(app.entries.any((e) => e.id == secondNap.id), isFalse);
  });

  test(
    'daily and hourly totals count mixed nappies, clip dates and split sleep',
    () {
      final now = DateTime(2026, 10, 18, 12);
      final stats = HistoryStats(
        [
          Entry(
            type: EntryType.nappy,
            time: DateTime(2026, 10, 17, 14),
            nappy: NappyKind.both,
          ),
          Entry(
            type: EntryType.nappy,
            time: DateTime(2026, 10, 18, 9),
            nappy: NappyKind.pee,
          ),
          Entry(
            type: EntryType.nappy,
            time: DateTime(2026, 10, 18, 9),
            nappy: NappyKind.poo,
            deleted: true,
          ),
          Entry(type: EntryType.feed, time: DateTime(2026, 10, 17, 14)),
          Entry(type: EntryType.feed, time: DateTime(2026, 10, 18, 13)),
          Entry(type: EntryType.feed, time: DateTime(2026, 10, 16, 14)),
          Entry(
            type: EntryType.sleep,
            time: DateTime(2026, 10, 16, 23),
            endTime: DateTime(2026, 10, 17, 1),
          ),
          Entry(
            type: EntryType.sleep,
            time: DateTime(2026, 10, 17, 23, 30),
            endTime: DateTime(2026, 10, 18, 1),
          ),
          Entry(type: EntryType.sleep, time: DateTime(2026, 10, 18, 11)),
        ],
        now: now,
        days: 2,
      );
      expect(stats.pee, [1, 1]);
      expect(stats.poo, [1, 0]);
      expect(stats.feedByHour[14], 1);
      expect(stats.feedByHour.reduce((a, b) => a + b), 1);
      expect(stats.pooByHour[14], 1);
      expect(stats.peeByHour[9], 1);
      expect(stats.sleepHours, [1.5, 2.0]);
    },
  );

  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: MaterialApp(
          theme: babyTheme(),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final feed in [true, false]) {
    testWidgets(
      '${feed ? "feed" : "nappy"} selection offers end nap and keep sleeping',
      (tester) async {
        app.startSleep(
          time: DateTime.now().subtract(const Duration(minutes: 30)),
        );
        await open(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showSheet(
                context,
                feed ? const FeedSheet() : const NappySheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Has the nap finished?'), findsOneWidget);
        await tester.tap(find.text('Still sleeping'));
        await tester.pumpAndSettle();
        expect(app.activeSleep, isNotNull);
        // Dismiss the new-entry form, then reopen and end the nap.
        Navigator.of(tester.element(find.text(feed ? 'Feed' : 'Nappy change')))
            .pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('End nap'));
        await tester.pumpAndSettle();
        expect(app.activeSleep, isNull);
        expect(app.entries.single.endTime, isNotNull);
        expect(find.text(feed ? 'Feed' : 'Nappy change'), findsOneWidget);
      },
    );
  }

  testWidgets('manual start and end and history sleep filter', (tester) async {
    await open(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showSheet(context, const SleepSheet()),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start nap'));
    await tester.pumpAndSettle();
    expect(app.activeSleep, isNotNull);
    await open(tester, HomePage(onSeeHistory: () {}, onSeeRoutines: () {}));
    await tester.tap(find.text('End nap'));
    await tester.pumpAndSettle();
    expect(app.activeSleep, isNull);
    await open(tester, const HistoryPage());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sleep'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all six charts render on a narrow screen and range changes work',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      app.addEntry(Entry(type: EntryType.feed, time: DateTime.now()));
      await open(tester, const HistoryPage());
      await tester.tap(find.text('Charts'));
      await tester.pumpAndSettle();
      expect(find.text('Wees per day'), findsOneWidget);
      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle();
      for (final title in [
        'Poos per day',
        'Sleep hours per day',
        'Feeds by hour',
        'Poos by hour',
        'Wees by hour',
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

import 'dart:io';

import 'package:baby_app/src/history_stats.dart';
import 'package:baby_app/src/history_period.dart';
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
import 'package:intl/intl.dart';

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

  testWidgets('charts tab renders daily and hourly views on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    app.addEntry(Entry(type: EntryType.feed, time: DateTime.now()));
    await open(tester, const HistoryPage());
    await tester.tap(find.text('Charts'));
    await tester.pumpAndSettle();
    expect(find.text('Wees per day'), findsOneWidget);
    expect(find.byType(EntryTile), findsNothing);
    final firstDate = HistoryPeriod.recent(DateTime.now(), 7).start!;
    final firstBar = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label ==
              'Feeds per day, ${DateFormat('d MMM').format(firstDate)}: 0',
    );
    await tester.ensureVisible(firstBar);
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: firstBar, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('${DateFormat('EEE d MMM yyyy').format(firstDate)} · 0'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('30 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    for (final title in [
      'Poos per day',
      'Sleep hours per day',
      'Feed minutes per day',
      'Bottle ml per day',
      'Pills per day',
      'Next-day estimate',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.scrollUntilVisible(
      find.text('By hour'),
      -400,
      scrollable: find
          .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('By hour'));
    await tester.pumpAndSettle();
    for (final title in [
      'Feeds by hour',
      'Wees by hour',
      'Poos by hour',
      'Sleep hours by hour',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Activity log'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryTile), findsOneWidget);
  });

  test('explicit day and hour clip counts and sleep at both boundaries', () {
    final stats = HistoryStats(
      [
        Entry(
          type: EntryType.sleep,
          time: DateTime(2026, 10, 16, 23),
          endTime: DateTime(2026, 10, 18, 2),
        ),
        Entry(
          type: EntryType.feed,
          time: DateTime(2026, 10, 17, 9),
          durationMin: 12,
          amountMl: 40,
        ),
        Entry(
          type: EntryType.feed,
          time: DateTime(2026, 10, 17, 10),
          amountMl: 100,
        ),
        Entry(
          type: EntryType.nappy,
          time: DateTime(2026, 10, 17, 9, 59),
          nappy: NappyKind.both,
        ),
        Entry(type: EntryType.pill, time: DateTime(2026, 10, 17, 9, 30)),
      ],
      now: DateTime(2026, 10, 19, 12),
      days: 7,
      period: HistoryPeriod(
        start: DateTime(2026, 10, 17),
        end: DateTime(2026, 10, 17),
        hour: 9,
      ),
    );
    expect(stats.feeds, [1]);
    expect(stats.feedMinutes, [12]);
    expect(stats.bottleMl, [40]);
    expect(stats.pills, [1]);
    expect(stats.pee, [1]);
    expect(stats.poo, [1]);
    expect(stats.sleepHours, [1.0]);
    expect(stats.sleepByHour[9], 1);
    expect(stats.sleepByHour[10], 0);
  });

  test(
    'estimates exclude today, include empty days and require logged days',
    () {
      final now = DateTime(2026, 10, 21, 12);
      final entries = [
        for (final day in [17, 18, 19, 21, 21, 21])
          Entry(type: EntryType.feed, time: DateTime(2026, 10, day, 10)),
      ];
      final stats = HistoryStats(entries, now: now, days: 5);
      expect(stats.canEstimate, isTrue);
      expect(stats.completedIndexes.length, 4);
      expect(stats.estimate(stats.feeds), 0.75);
      expect(HistoryStats(entries, now: now, days: 3).canEstimate, isFalse);
    },
  );

  testWidgets('log day and hour filters combine with type', (tester) async {
    final today = HistoryPeriod.day(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    app.addEntry(
      Entry(
        type: EntryType.feed,
        time: yesterday.add(const Duration(hours: 9)),
      ),
    );
    app.addEntry(
      Entry(
        type: EntryType.feed,
        time: yesterday.add(const Duration(hours: 10)),
      ),
    );
    app.addEntry(
      Entry(
        type: EntryType.nappy,
        time: yesterday.add(const Duration(hours: 9)),
      ),
    );
    await open(tester, const HistoryPage());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yesterday'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(find.text('No entries match these filters'), findsOneWidget);
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('09:00 – 09:59').last,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00 – 09:59').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Feeds'),
      150,
      scrollable: find
          .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
          .first,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Feeds'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(EntryTile),
      150,
      scrollable: find
          .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
          .first,
    );
    expect(find.byType(EntryTile), findsOneWidget);
    final tile = tester.widget<EntryTile>(find.byType(EntryTile));
    expect(tile.entry.time.hour, 9);
    expect(tile.entry.type, EntryType.feed);
    expect(tester.takeException(), isNull);
  });
}

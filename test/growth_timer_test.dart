import 'dart:convert';
import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/growth.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/qr_transfer.dart';
import 'package:baby_app/src/routines.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/growth_page.dart';
import 'package:baby_app/src/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jB1sAAAAASUVORK5CYII=';

void main() {
  late Directory dir;
  late AppState app;
  final extras = <AppState>[];
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('baby-growth-test-');
    app = await AppState.loadForTesting(File('${dir.path}/baby.json'));
    AppState.appVersion = '1.5.0';
  });
  tearDown(() async {
    for (final state in [app, ...extras]) {
      state.dispose();
      await state.pendingSave;
    }
    extras.clear();
    await dir.delete(recursive: true);
  });

  test(
    'legacy profiles load, birthday and photo survive renaming and restart',
    () async {
      expect(
        BabyProfile.fromJson({'id': 'legacy', 'name': 'Baby'})!.dateOfBirth,
        isNull,
      );
      app.saveBabyProfile(
        name: 'Robin',
        dateOfBirth: DateTime(2026, 1, 31),
        photo: pixel,
      );
      app.setBabyName('Robyn');
      await app.pendingSave;
      final restored = await AppState.loadForTesting(File(app.dataFilePath));
      extras.add(restored);
      expect(restored.activeBaby.name, 'Robyn');
      expect(restored.activeBaby.dateOfBirth, DateTime(2026, 1, 31));
      expect(restored.activeBaby.photo, pixel);
      expect(ageInMonths(DateTime(2026, 1, 31), DateTime(2026, 2, 28)), 1);
      expect(ageInMonths(DateTime(2026, 1, 31), DateTime(2026, 3, 30)), 1);
    },
  );

  test(
    'growth backup and QR sync include photos, edits and deletions per baby',
    () async {
      app.saveBabyProfile(
        name: 'Robin',
        dateOfBirth: DateTime(2026, 1, 1),
        photo: pixel,
      );
      final first = GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime(2026, 2, 1),
        weightKg: 4.2,
        heightCm: 54,
        photo: pixel,
      );
      expect(app.saveGrowth(first), isTrue);
      app.addBaby('Sibling');
      expect(app.growthEntries, isEmpty);
      final sibling = app.activeBabyId;
      app.saveGrowth(
        GrowthEntry(
          babyId: sibling,
          date: DateTime(2026, 2, 2),
          note: 'First smile',
        ),
      );
      app.selectBaby(defaultBabyId);
      expect(app.growthEntries.single.id, first.id);
      final other = await AppState.loadForTesting(
        File('${dir.path}/other.json'),
      );
      extras.add(other);
      expect(other.importBackup(app.exportBackup()).growth, 2);
      expect(other.importBackup(app.exportBackup()).growth, 0);
      expect(other.growthEntries.single.photo, pixel);
      expect(other.activeBaby.photo, pixel);
      app.setGrowthDeleted(first, true);
      final collector = QrCollector();
      for (final code in app.qrCodesFor(null)) {
        collector.add(code);
      }
      other.receiveQr(collector.result());
      expect(other.growthEntries, isEmpty);
      other.selectBaby(sibling);
      expect(other.growthEntries.single.note, 'First smile');
      other.selectBaby(defaultBabyId);
      app.setGrowthDeleted(first, false);
      final restoredCollector = QrCollector();
      for (final code in app.qrCodesFor(null)) {
        restoredCollector.add(code);
      }
      other.receiveQr(restoredCollector.result());
      expect(other.growthEntries.single.weightKg, 4.2);
      // Old backups cannot resurrect a deleted record.
      final oldBackup = app.exportBackup();
      app.setGrowthDeleted(first, true);
      app.importBackup(oldBackup);
      expect(app.growthEntries, isEmpty);
    },
  );

  test('growth rejects empty, invalid, future and pre-birth measurements', () {
    app.saveBabyProfile(name: 'Baby', dateOfBirth: DateTime(2026, 1, 1));
    for (final entry in [
      GrowthEntry(babyId: defaultBabyId, date: DateTime(2026, 2, 1)),
      GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime(2026, 2, 1),
        weightKg: -1,
      ),
      GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime(2026, 2, 1),
        heightCm: double.nan,
      ),
      GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime(2025, 12, 1),
        weightKg: 4,
      ),
      GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime.now().add(const Duration(days: 1)),
        weightKg: 4,
      ),
    ]) {
      expect(app.saveGrowth(entry), isFalse);
    }
    expect(
      GrowthEntry.fromJson({'id': 'x', 'babyId': defaultBabyId, 'date': 'bad'}),
      isNull,
    );
  });

  test(
    'pause/resume excludes every break, persists, and guards the baby',
    () async {
      app.addBaby('Sibling');
      final sibling = app.activeBabyId;
      app.selectBaby(defaultBabyId);
      final start = DateTime(2026, 10, 20, 10);
      app.startFeedTimer(FeedSide.left, now: start);
      app.startFeedTimer(
        FeedSide.right,
        now: start.add(const Duration(minutes: 1)),
      );
      expect(app.timerSide, FeedSide.left);
      app.pauseFeedTimer(now: start.add(const Duration(minutes: 3)));
      app.pauseFeedTimer(now: start.add(const Duration(minutes: 4)));
      expect(
        app.feedElapsed(start.add(const Duration(hours: 1))),
        const Duration(minutes: 3),
      );
      expect(app.timerActiveOrigin, isNull);
      expect(app.selectBaby(sibling), isFalse);
      await app.pendingSave;
      final restored = await AppState.loadForTesting(File(app.dataFilePath));
      extras.add(restored);
      expect(restored.timerPaused, isTrue);
      expect(restored.feedElapsed(), const Duration(minutes: 3));
      restored.resumeFeedTimer(now: start.add(const Duration(minutes: 5)));
      // Next reminder at 10:07 = 5 active minutes after the 2-minute break.
      expect(
        restored.timerActiveOrigin!.add(const Duration(minutes: 5)),
        start.add(const Duration(minutes: 7)),
      );
      restored.pauseFeedTimer(now: start.add(const Duration(minutes: 8)));
      restored.resumeFeedTimer(now: start.add(const Duration(minutes: 10)));
      restored.stopFeedTimer(now: start.add(const Duration(minutes: 12)));
      expect(restored.lastFeed!.durationMin, 8);
      expect(restored.lastFeed!.time, start);
      expect(restored.lastFeed!.babyId, defaultBabyId);
      expect(restored.timerActiveOrigin, isNull);
      expect(restored.selectBaby(sibling), isTrue);
      expect(
        jsonDecode(restored.exportBackup()).containsKey('timerStart'),
        isFalse,
      );
    },
  );

  test(
    'stop while paused saves active time; cancel and toggle cancel reminders',
    () {
      final start = DateTime(2026, 10, 20, 10);
      app.startFeedTimer(FeedSide.right, now: start);
      app.setTimerReminders(false);
      expect(app.timerActiveOrigin, isNull);
      app.setTimerReminders(true);
      expect(app.timerActiveOrigin, start);
      app.pauseFeedTimer(now: start.add(const Duration(minutes: 5)));
      app.stopFeedTimer(now: start.add(const Duration(hours: 2)));
      expect(app.lastFeed!.durationMin, 5);
      app.startFeedTimer(FeedSide.left, now: start);
      app.stopFeedTimer(save: false);
      expect(app.entries.length, 1);
      expect(app.timerPausedAt, isNull);
      expect(app.timerActiveOrigin, isNull);
    },
  );

  testWidgets('small phone creates and edits measurements and profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    app.dispose();
    app = (await tester.runAsync(
      () =>
          AppState.loadForTesting(File('${dir.path}/ui.json'), persist: false),
    ))!;
    app.setupDone = true;
    app.setBabyName('Robin');
    await tester.pumpWidget(
      BabyApp(state: app, now: () => DateTime(2026, 10, 20, 12)),
    );
    await tester.tap(find.text('Growth').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a moment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Weight',
      ),
      '4,25',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Height',
      ),
      '55',
    );
    await tester.ensureVisible(find.text('Save moment'));
    await tester.tap(find.text('Save moment'));
    await tester.pumpAndSettle();
    expect(app.growthEntries.single.weightKg, 4.25);
    expect(app.growthEntries.single.heightCm, 55);
    await tester.tap(find.byTooltip('Edit profile').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Baby’s name',
      ),
      'Robyn',
    );
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(app.babyName, 'Robyn');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (width, textScale) in [(320.0, 1.0), (280.0, 1.0), (320.0, 1.5)]) {
    testWidgets(
      'feeding controls pause, resume and save at $width with text scale $textScale',
      (tester) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.reset);
        app.dispose();
        app = (await tester.runAsync(
          () => AppState.loadForTesting(
            File('${dir.path}/timer-ui.json'),
            persist: false,
          ),
        ))!;
        app.setupDone = true;
        app.startFeedTimer(FeedSide.left);
        await tester.pumpWidget(
          BabyApp(state: app, now: () => DateTime(2026, 10, 20, 12)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final homeScroll = find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Pause to burp'),
          200,
          scrollable: homeScroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pause to burp'));
        await tester.pump();
        expect(app.timerPaused, isTrue);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Resume feeding'));
        await tester.pump();
        expect(app.timerPaused, isFalse);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Stop & save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stop & save'));
        await tester.pump();
        expect(app.lastFeed, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('charts show sparse measurements and equal dates in dark mode', (
    tester,
  ) async {
    app.dispose();
    app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('${dir.path}/charts.json'),
        persist: false,
      ),
    ))!;
    app.setupDone = true;
    app.saveGrowth(
      GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime(2026, 1, 1),
        weightKg: 4,
      ),
    );
    app.saveGrowth(
      GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime(2026, 1, 1),
        weightKg: 4,
      ),
    );
    app.saveGrowth(
      GrowthEntry(
        babyId: defaultBabyId,
        date: DateTime(2026, 2, 1),
        heightCm: 50,
      ),
    );
    await tester.pumpWidget(
      BabyApp(state: app, now: () => DateTime(2026, 10, 20, 22)),
    );
    await tester.tap(find.text('Growth').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(
        of: find.byType(GrowthPage),
        matching: find.byType(ListView),
      ),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    expect(find.text('4 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

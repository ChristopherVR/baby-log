import 'dart:convert';
import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/notifications.dart';
import 'package:baby_app/src/qr_transfer.dart';
import 'package:baby_app/src/routines.dart';
import 'package:baby_app/src/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late AppState app;
  final extraStates = <AppState>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('baby-routines-test-');
    app = await AppState.loadForTesting(File('${dir.path}/log.json'));
    AppState.appVersion = '1.3.0';
  });
  tearDown(() async {
    app.dispose();
    await app.pendingSave;
    for (final state in extraStates) {
      state.dispose();
      await state.pendingSave;
    }
    extraStates.clear();
    await dir.delete(recursive: true);
  });

  test('recurrence handles selected days, exact time and next week', () {
    final bath = Routine(
      babyId: defaultBabyId,
      name: 'Bath time',
      minutes: 18 * 60,
      weekdays: [1, 3, 5],
    );
    expect(bath.nextAt(DateTime(2026, 10, 19, 17)), DateTime(2026, 10, 19, 18));
    expect(bath.nextAt(DateTime(2026, 10, 19, 18)), DateTime(2026, 10, 19, 18));
    expect(bath.nextAt(DateTime(2026, 10, 19, 19)), DateTime(2026, 10, 21, 18));
    final monday = Routine(babyId: defaultBabyId, name: 'Bath', weekdays: [1]);
    expect(
      monday.nextAt(DateTime(2026, 10, 19, 19)),
      DateTime(2026, 10, 26, 18),
    );
    expect(bath.copyWith(enabled: false).nextAt(DateTime.now()), isNull);
    expect(bath.copyWith(deleted: true).nextAt(DateTime.now()), isNull);
    expect(
      Routine.fromJson({
        ...bath.toJson(),
        'weekdays': [0, 8],
      }),
      isNull,
    );
    expect(Routine.fromJson({...bath.toJson(), 'minutes': 1440}), isNull);
  });

  test('legacy backups retain the original baby and logs after adding a baby', () {
    final feed = Entry(type: EntryType.feed, time: DateTime(2026, 10, 17, 8));
    app.importBackup(
      jsonEncode({
        'app': 'babylog',
        'babyName': 'Markus',
        'entries': [feed.toJson()],
      }),
    );
    expect(app.babyName, 'Markus');
    expect(app.lastFeed?.id, feed.id);
    app.setFeedReminder(on: true, minutes: 120);
    app.addBaby('Ella');
    expect(app.babyName, 'Ella');
    expect(app.entries, isEmpty);
    expect(app.feedReminderOn, isFalse);
    final nappy = Entry(
      type: EntryType.nappy,
      time: DateTime.now(),
      nappy: NappyKind.pee,
    );
    app.addEntry(nappy);
    app.selectBaby(defaultBabyId);
    expect(app.lastFeed?.id, feed.id);
    expect(app.lastNappy, isNull);
    expect(app.feedReminderOn, isTrue);
    expect(app.feedReminderMinutes, 120);
    // An edit must keep its baby even if another profile is currently selected.
    app.updateEntry(
      Entry(
        id: nappy.id,
        type: EntryType.nappy,
        time: nappy.time,
        nappy: NappyKind.poo,
      ),
    );
    expect(app.lastNappy, isNull);
    app.selectBaby(app.babies.firstWhere((b) => b.name == 'Ella').id);
    expect(app.lastNappy?.nappy, NappyKind.poo);
  });

  test('a running feed timer keeps the original profile', () {
    app.startFeedTimer(FeedSide.left);
    app.addBaby('Ella');
    final ella = app.babies.firstWhere((b) => b.name == 'Ella');
    expect(app.activeBabyId, defaultBabyId);
    expect(app.selectBaby(ella.id), isFalse);
    app.stopFeedTimer();
    expect(app.lastFeed?.babyId, defaultBabyId);
    expect(app.selectBaby(ella.id), isTrue);
    expect(app.lastFeed, isNull);
  });

  test(
    'profiles, routines and local reminder preferences survive restart',
    () async {
      app.setBabyName('Markus');
      final routine = Routine(
        babyId: defaultBabyId,
        name: 'Bath time',
        weekdays: [2, 4, 6],
        notes: 'Before bedtime',
      );
      app.saveRoutine(routine, remind: true);
      app.addBaby('Ella');
      final active = app.activeBabyId;
      app.saveRoutine(
        Routine(babyId: active, name: 'Bedtime', minutes: 19 * 60),
      );
      app.setFeedReminder(on: true, minutes: 150);
      await app.pendingSave;
      final loaded = await AppState.loadForTesting(File(app.dataFilePath));
      extraStates.add(loaded);
      expect(loaded.activeBabyId, active);
      expect(loaded.routines.single.name, 'Bedtime');
      expect(loaded.feedReminderMinutes, 150);
      loaded.selectBaby(defaultBabyId);
      expect(loaded.routines.single.weekdays, [2, 4, 6]);
      expect(loaded.routines.single.notes, 'Before bedtime');
      expect(loaded.routineRemindsHere(loaded.routines.single), isTrue);
      expect(loaded.feedReminderOn, isFalse);
      await loaded.pendingSave;
    },
  );

  test(
    'QR sync and backup preserve baby identity and routine deletion',
    () async {
      app.setBabyName('Markus');
      app.saveRoutine(
        Routine(babyId: defaultBabyId, name: 'Bath time', weekdays: [1, 3, 5]),
      );
      app.addBaby('Ella');
      app.saveRoutine(Routine(babyId: app.activeBabyId, name: 'Bedtime'));
      final collector = QrCollector();
      for (final code in app.qrCodesFor(null)) {
        collector.add(code);
      }
      final other = await AppState.loadForTesting(
        File('${dir.path}/other.json'),
      );
      final copy = await AppState.loadForTesting(File('${dir.path}/copy.json'));
      extraStates.add(other);
      extraStates.add(copy);
      other.receiveQr(collector.result());
      expect(other.babies.map((b) => b.name), containsAll(['Markus', 'Ella']));
      expect(other.activeBabyId, defaultBabyId);
      expect(other.routines.single.name, 'Bath time');
      final imported = copy.importBackup(app.exportBackup());
      expect(imported.routines, 2);
      final bath = app.babies.firstWhere((b) => b.name == 'Markus');
      app.selectBaby(bath.id);
      app.saveRoutine(app.routines.single.copyWith(deleted: true));
      final merge = copy.importBackup(app.exportBackup());
      expect(merge.routines, 1);
      expect(copy.routines, isEmpty);
      expect(copy.importBackup(app.exportBackup()).routines, 0);
      await other.pendingSave;
      await copy.pendingSave;
    },
  );

  test('routine and feed notification payloads preserve the intended baby', () {
    for (final kind in ['routine', 'feed']) {
      final info = ReminderInfo(
        id: 1001,
        kind: kind,
        babyId: 'ella',
        title: 'Bath',
        body: 'Evening',
      );
      expect(ReminderInfo.parse(info.toPayload())!.babyId, 'ella');
      expect(ReminderInfo.parse(info.withId(920).toPayload())!.babyId, 'ella');
    }
  });

  for (final keyboardHeight in [0.0, 320.0]) {
    testWidgets(
      'routine save clears bottom navigation with keyboard height $keyboardHeight',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 780);
        tester.view.viewPadding = const FakeViewPadding(bottom: 48);
        tester.view.padding = FakeViewPadding(
          bottom: keyboardHeight == 0 ? 48 : 0,
        );
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        addTearDown(tester.view.reset);
        app.dispose();
        app = (await tester.runAsync(
          () => AppState.loadForTesting(
            File('${dir.path}/layout.json'),
            persist: false,
          ),
        ))!;
        app.setupDone = true;
        await tester.pumpWidget(BabyApp(state: app));
        await tester.tap(find.text('Routines').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add routine'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, 'Bath time'));

        final save = find.widgetWithText(FilledButton, 'Save routine');
        final scrollable = find.ancestor(
          of: save,
          matching: find.byType(SingleChildScrollView),
        );
        await tester.drag(scrollable, const Offset(0, -1200));
        await tester.pumpAndSettle();
        final button = tester.getRect(save);
        final obscuredHeight = keyboardHeight == 0 ? 48 : keyboardHeight;
        expect(button.bottom, lessThanOrEqualTo(780 - obscuredHeight - 24));
        expect(button.top, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(app.routines.single.name, 'Bath time');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'create a bath routine, validate days and switch baby in the app',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      app.dispose();
      app = (await tester.runAsync(
        () => AppState.loadForTesting(
          File('${dir.path}/widget.json'),
          persist: false,
        ),
      ))!;
      app.setupDone = true;
      app.setBabyName('Markus');
      await tester.pumpWidget(BabyApp(state: app));
      await tester.tap(find.text('Routines').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Set up bath time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up bath time'));
      await tester.pumpAndSettle();
      for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        await tester.tap(find.widgetWithText(FilterChip, day));
      }
      await tester.ensureVisible(find.text('Save routine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save routine'));
      await tester.pumpAndSettle();
      expect(find.text('Choose at least one day'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Sat'));
      await tester.tap(find.text('Save routine'));
      await tester.pumpAndSettle();
      expect(app.routines.single.name, 'Bath time');
      expect(app.routines.single.weekdays, [6]);
      await tester.ensureVisible(find.text('Mark done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save completion'));
      await tester.pumpAndSettle();
      expect(find.text('Enter who did the routine'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate((widget) => widget is TextFormField),
        'Dad',
      );
      await tester.tap(find.text('Save completion'));
      await tester.pumpAndSettle();
      expect(app.routineHistory().single.doneBy, 'Dad');
      expect(find.textContaining('Last done:'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'History'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dad'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove completion'));
      await tester.pumpAndSettle();
      expect(app.routineHistory(), isEmpty);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(app.routineHistory().single.doneBy, 'Dad');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add baby'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((widget) => widget is TextFormField),
        'Ella',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add baby'));
      await tester.pumpAndSettle();
      expect(app.babyName, 'Ella');
      expect(find.text('Set up bath time'), findsOneWidget);
      expect(app.routines, isEmpty);
      expect(app.routineHistory(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await app.pendingSave;
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}

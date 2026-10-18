import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/nighttime.dart';
import 'package:baby_app/src/ui/settings_page.dart';
import 'package:baby_app/src/ui/theme.dart';
import 'package:baby_app/src/ui/update_card.dart';
import 'package:baby_app/src/updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Updates extends AppUpdates {
  int checks = 0;
  @override
  Future<void> check({bool manual = false}) async {
    expect(manual, isTrue);
    checks++;
    checking = true;
    notifyListeners();
  }

  void finish() {
    checking = false;
    available = AppRelease('1.4.99', Uri.parse(releaseRepository), 1234);
    notifyListeners();
  }
}

void main() {
  setUp(() async => initializeDateFormatting('en'));
  tearDown(() => Baby.dark = false);

  test('nighttime runs from 18:00 through 05:59 in local time', () {
    expect(isNighttime(DateTime(2026, 10, 17, 17, 59)), isFalse);
    expect(isNighttime(DateTime(2026, 10, 17, 18)), isTrue);
    expect(isNighttime(DateTime(2026, 10, 18)), isTrue);
    expect(isNighttime(DateTime(2026, 10, 18, 5, 59)), isTrue);
    expect(isNighttime(DateTime(2026, 10, 18, 6)), isFalse);
  });

  testWidgets(
    'whole app switches at dusk and dawn and preserves daytime appearance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final app = (await tester.runAsync(
        () => AppState.loadForTesting(
          File('unused-nighttime-test.json'),
          persist: false,
        ),
      ))!;
      addTearDown(app.dispose);
      var now = DateTime(2026, 10, 17, 17, 59, 59);
      await tester.pumpWidget(BabyApp(state: app, now: () => now));
      await tester.pumpAndSettle();
      expect(Baby.dark, isFalse);
      expect(find.byType(NighttimeNotice), findsNothing);
      now = DateTime(2026, 10, 17, 18);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(Baby.dark, isTrue);
      expect(find.text('Dark mode for nighttime · until 6 am'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness,
        Brightness.dark,
      );
      expect(find.text('Nighttime'), findsNothing);
      expect(app.appearance, 'light');
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(NighttimeNotice), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.dark,
      );
      now = DateTime(2026, 10, 18, 6);
      await tester.pump(const Duration(hours: 12));
      await tester.pumpAndSettle();
      expect(Baby.dark, isFalse);
      expect(find.byType(NighttimeNotice), findsNothing);
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.light,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness,
        Brightness.light,
      );
      app.setAppearance('dark');
      await tester.pumpAndSettle();
      expect(Baby.dark, isTrue);
      expect(find.byType(NighttimeNotice), findsNothing);
      now = DateTime(2026, 10, 18, 18);
      await tester.pump(const Duration(hours: 12));
      await tester.pumpAndSettle();
      expect(Baby.dark, isTrue);
      expect(find.byType(NighttimeNotice), findsOneWidget);
      now = DateTime(2026, 10, 19, 6);
      await tester.pump(const Duration(hours: 12));
      await tester.pumpAndSettle();
      expect(Baby.dark, isTrue);
      expect(find.byType(NighttimeNotice), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('nighttime is applied immediately and refreshed on resume', (
    tester,
  ) async {
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-nighttime-resume-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    var now = DateTime(2026, 10, 17, 23);
    await tester.pumpWidget(BabyApp(state: app, now: () => now));
    await tester.pumpAndSettle();
    expect(Baby.dark, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 10, 18, 7);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(Baby.dark, isFalse);
    app.appPaused();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'undo is actionable and automatically dismisses after 5 seconds',
    (tester) async {
      var undos = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showUndo(context, 'Saved', () => undos++),
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(undos, 0);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undos, 1);
      expect(find.text('Undo'), findsNothing);
    },
  );

  testWidgets(
    'version update dialog checks on opening and shows progress and result',
    (tester) async {
      final updates = _Updates();
      addTearDown(updates.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppUpdates(context, updates: updates),
                child: const Text('App version'),
              ),
            ),
          ),
        ),
      );
      expect(updates.checks, 0);
      await tester.tap(find.text('App version'));
      // The indeterminate progress indicator keeps animating until completion.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(updates.checks, 1);
      expect(find.text('Checking for updates…'), findsOneWidget);
      updates.finish();
      await tester.pumpAndSettle();
      expect(find.text('New update available: 1.4.99'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
      expect(find.text('Check for updates'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('App updates'), findsNothing);
    },
  );

  testWidgets('settings update search leads to tappable app version', (
    tester,
  ) async {
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-settings-updates-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Check for updates');
    await tester.pumpAndSettle();
    expect(find.text('App version'), findsOneWidget);
    expect(find.text('App updates'), findsNothing);
    await tester.tap(find.text('App version'));
    await tester.pumpAndSettle();
    expect(find.text('App updates'), findsOneWidget);
  });
}

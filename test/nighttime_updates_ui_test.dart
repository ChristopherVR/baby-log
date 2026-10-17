import 'dart:io';

import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/nighttime_banner.dart';
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
    'nighttime remains explicit in light mode and disappears by day',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: babyTheme(),
          home: Scaffold(
            body: NighttimeIndicator(time: DateTime(2026, 10, 17, 21, 30)),
          ),
        ),
      );
      expect(find.text('Nighttime'), findsOneWidget);
      expect(find.text('21:30'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
      expect(Baby.dark, isFalse);
      expect(
        Theme.of(tester.element(find.text('Nighttime'))).brightness,
        Brightness.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: babyTheme(),
          home: Scaffold(
            body: NighttimeIndicator(time: DateTime(2026, 10, 18, 6)),
          ),
        ),
      );
      expect(find.text('Nighttime'), findsNothing);
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

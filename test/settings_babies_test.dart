import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUp(() async => initializeDateFormatting('en'));

  testWidgets('settings lists every baby and lets you select and add', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-settings-babies-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    app.completeSetup();
    app.setBabyName('Markus');
    final noah = app.addBaby('Noah', select: false)!;
    expect(app.activeBaby.name, 'Markus');
    await tester.pumpWidget(BabyApp(state: app));
    await tester.pumpAndSettle();
    openSettings(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    expect(find.text("Baby's name"), findsNothing);
    expect(find.text('Babies'), findsOneWidget);
    expect(find.text('Noah'), findsOneWidget);
    expect(find.textContaining('Selected'), findsOneWidget);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(app.activeBabyId, noah);
    expect(find.text('Select'), findsOneWidget);
    // The summary card shows the selected baby with a tappable photo.
    expect(find.byTooltip('Change photo'), findsOneWidget);
    // Tapping a baby opens that baby's profile.
    await tester.tap(find.text('Markus').last);
    await tester.pumpAndSettle();
    expect(find.text('Save profile'), findsOneWidget);
    expect(find.text('Markus'), findsWidgets);
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(EditableText),
      ),
      'Markus Jr',
    );
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(app.babies.map((b) => b.name), contains('Markus Jr'));
    expect(app.activeBabyId, noah);
    expect(tester.takeException(), isNull);
  });
}

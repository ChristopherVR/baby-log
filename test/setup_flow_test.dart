import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUp(() async => initializeDateFormatting('en'));

  for (final reduce in [false, true]) {
    testWidgets(
      'setup walks all steps on a narrow, large-text screen (reduced motion: $reduce)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: reduce);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final app = (await tester.runAsync(
          () => AppState.loadForTesting(
            File('unused-setup-flow-test.json'),
            persist: false,
          ),
        ))!;
        addTearDown(app.dispose);
        FlutterError.onError = (d) => debugPrint(d.toString());
        await tester.pumpWidget(BabyApp(state: app));
        await tester.pumpAndSettle();
        expect(find.byType(SetupPage), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          final ex = tester.takeException();
          expect(ex, isNull, reason: 'step $i');
        }
        expect(find.text('You are all set!'), findsOneWidget);
      },
    );
  }

  testWidgets('setup can add more than one baby and keeps the first selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-setup-two-babies-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    FlutterError.onError = (d) => debugPrint(d.toString());
    await tester.pumpWidget(BabyApp(state: app));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Markus');
    await tester.tap(find.text('Add another baby'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).last, 'Noah');
    await tester.tap(find.text('Add another baby'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.tap(find.byTooltip('Remove').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(app.setupDone, isTrue);
    expect(app.babies.map((b) => b.name).toSet(), {'Markus', 'Noah'});
    expect(app.babyName, 'Markus');
    expect(tester.takeException(), isNull);
  });
}

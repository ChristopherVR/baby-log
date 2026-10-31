import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/routines.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/growth_page.dart';
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

  Future<AppState> start(WidgetTester tester, String file) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(File(file), persist: false),
    ))!;
    addTearDown(app.dispose);
    FlutterError.onError = (d) => debugPrint(d.toString());
    await tester.pumpWidget(BabyApp(state: app));
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('setup answers become the profile and the feed default', (
    tester,
  ) async {
    final app = await start(tester, 'unused-setup-answers-test.json');
    await next(tester);
    await tester.enterText(find.byType(TextField), 'Mia');
    await next(tester);
    expect(find.text('When was Mia born?'), findsOneWidget);
    final today = DateTime.now();
    final day = today.day == 1 ? 1 : today.day - 1;
    await tester.tap(find.text('$day'));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.text('Add a photo of Mia'), findsOneWidget);
    await next(tester);
    await tester.tap(find.text('Bottle'));
    await tester.pumpAndSettle();
    // Choosing an answer moves straight on to the finish.
    expect(find.text('Mia’s nest is ready'), findsOneWidget);
    await next(tester);
    expect(app.setupDone, isTrue);
    expect(app.babyName, 'Mia');
    expect(app.activeBaby.dateOfBirth, DateTime(today.year, today.month, day));
    expect(app.bottleFirst, isTrue);
    expect(app.tourPending, isTrue);
    expect(find.text('Log your first feed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first-log guide follows real logging, then tips appear', (
    tester,
  ) async {
    final app = await start(tester, 'unused-setup-guide-test.json');
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(app.tourPending, isTrue);
    expect(find.text('Log your first feed'), findsOneWidget);
    // No tips while the guide is showing.
    expect(find.text('Share with your partner'), findsNothing);

    app.addEntry(Entry(type: EntryType.feed, time: DateTime.now()));
    await tester.pumpAndSettle();
    expect(find.text('Nice! Now a nappy'), findsOneWidget);

    app.addEntry(
      Entry(type: EntryType.nappy, time: DateTime.now(), nappy: NappyKind.pee),
    );
    await tester.pumpAndSettle();
    expect(find.text('That’s the basics'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(app.tourPending, isFalse);
    expect(find.text('That’s the basics'), findsNothing);

    // With the guide done and a feed logged, sharing is offered once.
    await tester.dragUntilVisible(
      find.text('Share with your partner'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(app.tipShown('share'), isFalse);
    expect(find.text('Share with your partner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('newborn ages count days, then weeks, then months', () {
    final born = DateTime(2026, 3, 1);
    String at(int days) => babyAge(
      BabyProfile(name: 'Mia', dateOfBirth: born),
      born.add(Duration(days: days)),
    );
    expect(at(0), 'Born today');
    expect(at(1), '1 day old');
    expect(at(9), '9 days old');
    expect(at(14), '2 weeks old');
    expect(at(23), '3 weeks, 2 days old');
    expect(at(120), '3 months old');
  });
}

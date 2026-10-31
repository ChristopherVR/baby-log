import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUp(() async => initializeDateFormatting('en'));

  test(
    'pump settings, saved pumps and found sessions survive a restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('baby-pump-test-');
      final app = await AppState.loadForTesting(File('${dir.path}/app.json'));
      AppState? loaded;
      try {
        expect(app.pumpOnToday, isTrue);
        app.rememberPump('aa:bb', {'name': 'M5 Smart', 'side': 0});
        app.setShowPump(false);
        final found = Entry(
          type: EntryType.pump,
          time: DateTime(2026, 10, 31, 6),
          side: FeedSide.both,
          durationMin: 18,
          leftMl: 60,
          rightMl: 45,
          amountMl: 105,
        );
        app.setPumpFound([found]);
        await app.pendingSave;

        loaded = await AppState.loadForTesting(File(app.dataFilePath));
        expect(loaded.showPump, isFalse);
        expect(loaded.pumpOnToday, isFalse);
        expect(loaded.pumpDevices['aa:bb']?['name'], 'M5 Smart');
        final back = loaded.pumpFound.single;
        expect((back.leftMl, back.rightMl, back.amountMl), (60, 45, 105));
      } finally {
        app.dispose();
        loaded?.dispose();
        await dir.delete(recursive: true);
      }
    },
  );

  test('pumping shows for every baby, like pills', () async {
    final app = await AppState.loadForTesting(
      File('unused-pump-store-test.json'),
      persist: false,
    );
    addTearDown(app.dispose);
    app.completeSetup();
    app.setBabyName('Markus');
    final noah = app.addBaby('Noah', select: false)!;
    app.addEntry(
      Entry(type: EntryType.pump, time: DateTime.now(), amountMl: 80),
    );
    expect(app.entriesOn(DateTime.now(), EntryType.pump), hasLength(1));
    app.selectBaby(noah);
    expect(app.entriesOn(DateTime.now(), EntryType.pump), hasLength(1));
    expect(app.counts['pump'], 1);
  });

  testWidgets('Today has a Pump button unless it is switched off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-pump-tile-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    app.completeSetup();
    app.setBabyName('Markus');
    await tester.pumpWidget(BabyApp(state: app));
    await tester.pumpAndSettle();
    expect(find.text('Pump'), findsOneWidget);
    app.setShowPump(false);
    await tester.pumpAndSettle();
    expect(find.text('Pump'), findsNothing);
    app.setShowPump(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pump'));
    await tester.pumpAndSettle();
    expect(find.text('Pumping'), findsOneWidget);
    expect(find.text('Log by hand'), findsOneWidget);
  });
}

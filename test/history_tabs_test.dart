import 'dart:io';

import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/history_page.dart';
import 'package:baby_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late Directory dir;
  late AppState app;
  setUp(() async {
    await initializeDateFormatting('en');
    dir = await Directory.systemTemp.createTemp('history-tabs-');
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

  testWidgets('history tabs render and keep log filters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    app.addEntry(Entry(type: EntryType.feed, time: DateTime.now()));
    app.addEntry(Entry(type: EntryType.nappy, time: DateTime.now()));
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: MaterialApp(
          theme: babyTheme(),
          home: const Scaffold(body: HistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Everything that was logged, newest first'),
      findsOneWidget,
    );
    expect(find.byType(EntryTile), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Feeds'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryTile), findsOneWidget);

    await tester.tap(find.text('Charts'));
    await tester.pumpAndSettle();
    expect(
      find.text('Patterns over time: feeds, nappies, sleep'),
      findsOneWidget,
    );
    expect(find.byType(EntryTile), findsNothing);

    await tester.tap(find.text('Activity log'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

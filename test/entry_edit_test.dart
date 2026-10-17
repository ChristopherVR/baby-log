import 'dart:io';

import 'package:intl/date_symbol_data_local.dart';

import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppState app;
  late Directory dir;
  setUp(() async {
    await initializeDateFormatting('en');
    dir = await Directory.systemTemp.createTemp('entry-edit-test-');
    app = await AppState.loadForTesting(
      File('${dir.path}/app.json'),
      persist: false,
    );
  });
  tearDown(() async {
    app.dispose();
    await dir.delete(recursive: true);
  });

  Future<Entry> open(WidgetTester tester, Entry entry) async {
    app.addEntry(entry);
    final stored = app.entries.single;
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => editEntry(context, stored),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    return stored;
  }

  FilledButton update(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Update'));

  testWidgets(
    'nappy changes are staged, reverting disables Update, and Update saves',
    (tester) async {
      final time = DateTime.now().subtract(const Duration(hours: 1));
      final original = await open(
        tester,
        Entry(type: EntryType.nappy, time: time, nappy: NappyKind.poo),
      );
      expect(update(tester).onPressed, isNull);
      expect(
        tester.getCenter(find.text('Delete')).dy,
        tester.getCenter(find.text('Update')).dy,
      );
      await tester.tap(find.text('Pee'));
      await tester.pumpAndSettle();
      expect(app.entries.single.nappy, NappyKind.poo);
      expect(update(tester).onPressed, isNotNull);
      await tester.tap(find.text('Poo'));
      await tester.pumpAndSettle();
      expect(update(tester).onPressed, isNull);
      await tester.tap(find.text('Pee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(app.entries.single.id, original.id);
      expect(app.entries.single.nappy, NappyKind.pee);
      expect(app.entries.single.time, time);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit nappy'), findsNothing);
    },
  );

  testWidgets('outside tap offers keep editing or discard; Back also prompts', (
    tester,
  ) async {
    await open(
      tester,
      Entry(type: EntryType.nappy, time: DateTime.now(), nappy: NappyKind.poo),
    );
    await tester.tap(find.text('Pee'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(update(tester).onPressed, isNotNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Edit nappy'), findsNothing);
    expect(app.entries.single.nappy, NappyKind.poo);
  });

  for (final type in EntryType.values) {
    testWidgets(
      '${type.name} date edits enable Update and clean dismissal needs no prompt',
      (tester) async {
        final original = await open(
          tester,
          Entry(
            type: type,
            time: DateTime.now().subtract(const Duration(hours: 1)),
            nappy: NappyKind.pee,
            side: FeedSide.left,
            medName: 'Vitamin',
          ),
        );
        expect(update(tester).onPressed, isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsNothing);
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        final field = tester.widget<WhenField>(find.byType(WhenField));
        final changed = original.time.subtract(const Duration(days: 1));
        field.onChanged(changed);
        await tester.pumpAndSettle();
        expect(update(tester).onPressed, isNotNull);
        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();
        expect(app.entries.single.time, changed);
      },
    );
  }

  testWidgets(
    'dragging the handle prompts, and Delete still deletes a dirty entry',
    (tester) async {
      await open(
        tester,
        Entry(
          type: EntryType.nappy,
          time: DateTime.now(),
          nappy: NappyKind.poo,
        ),
      );
      await tester.tap(find.text('Pee'));
      await tester.pumpAndSettle();
      final handle = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onVerticalDragEnd != null,
      );
      await tester.fling(handle, const Offset(0, 100), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(app.entries, isEmpty);
      expect(find.text('Discard changes?'), findsNothing);
    },
  );
}

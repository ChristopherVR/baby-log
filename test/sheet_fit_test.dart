import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUp(() async => initializeDateFormatting('en'));

  for (final size in const [Size(800, 500), Size(1280, 420), Size(360, 500)]) {
    testWidgets('Appearance sheet fits and scrolls at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => AppState.loadForTesting(
          File('unused-sheet-fit-test.json'),
          persist: false,
        ),
      ))!;
      addTearDown(app.dispose);
      app.completeSetup();
      await tester.pumpWidget(BabyApp(state: app));
      await tester.pumpAndSettle();
      openSettings(tester.element(find.byType(Scaffold).first));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'theme');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      // Wide windows show sheets as centred dialogs.
      final sheetType = size.width >= 840 ? Dialog : BottomSheet;
      expect(find.byType(sheetType), findsOneWidget);
      final window = Offset.zero & size;
      // Whole sheet sits inside the window.
      final sheet = tester.getRect(find.byType(sheetType));
      expect(window.contains(sheet.topLeft), isTrue);
      expect(sheet.right, lessThanOrEqualTo(size.width));
      expect(sheet.bottom, lessThanOrEqualTo(size.height));
      // Last item can be scrolled into view.
      await tester.scrollUntilVisible(
        find.textContaining('It is a softer light theme'),
        50,
        scrollable: find
            .descendant(
              of: find.byType(sheetType),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final last = tester.getRect(
        find.textContaining('It is a softer light theme'),
      );
      expect(last.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }
}

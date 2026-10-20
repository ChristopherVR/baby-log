import 'dart:async';
import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppState app;

  setUp(() async {
    await initializeDateFormatting('en');
    app = await AppState.loadForTesting(
      File('unused-desktop-test.json'),
      persist: false,
    );
    Baby.dark = false;
  });
  tearDown(() => app.dispose());

  Widget host(Widget child) => AppScope(
    state: app,
    child: MaterialApp(theme: babyTheme(), home: child),
  );

  testWidgets('resizing preserves the selected tab and history search', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    await tester.pumpWidget(host(const Shell()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('today-columns')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('shell-content'))).width,
      greaterThan(900),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bottle');
    await tester.pump();

    for (final width in [430.0, 900.0, 1600.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'bottle',
      );
      if (width < 840) {
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        expect(
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          1,
        );
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('all tabs fit narrow, wide and short windows', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    app.addEntry(
      Entry(type: EntryType.feed, time: DateTime.now(), side: FeedSide.left),
    );
    await tester.pumpWidget(host(const Shell()));
    for (final size in [
      const Size(320, 800),
      const Size(360, 800),
      const Size(840, 600),
      const Size(1100, 800),
      const Size(1600, 480),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      for (final label in ['Today', 'History', 'Pills', 'Routines', 'Growth']) {
        final navigation = size.width < 840
            ? find.byType(NavigationBar)
            : find.byType(NavigationRail);
        final destination = find.descendant(
          of: navigation,
          matching: find.text(label),
        );
        await tester.ensureVisible(destination);
        await tester.tap(destination);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Refresh'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$label at $size');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'refresh button disables repeat requests and recovers after failure',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        host(
          Scaffold(
            appBar: AppBar(
              actions: [
                RefreshSyncButton(
                  onRefresh: () {
                    calls++;
                    return pending.future;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();
      expect(calls, 1);
      expect(find.byTooltip('Refreshing'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not sync:'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('toolbar refresh explains when no devices are paired', (
    tester,
  ) async {
    late Future<void> refresh;
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => refresh = refreshAndSync(context),
              child: const Text('Refresh now'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Refresh now'));
      await refresh;
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Up to date. Pair the other phone in Settings to sync.'),
      findsOneWidget,
    );
  });
}

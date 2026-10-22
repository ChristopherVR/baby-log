import 'dart:async';
import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/desktop/desktop_shell.dart';
import 'package:baby_app/src/ui/global_search.dart';
import 'package:baby_app/src/ui/home_page.dart';
import 'package:baby_app/src/ui/settings_page.dart';
import 'package:baby_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('today-columns')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('shell-content'))).width,
      greaterThan(900),
    );
    await tester.tap(find.byKey(const ValueKey('nav-History')));
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
        expect(find.byKey(const ValueKey('desktop-sidebar')), findsNothing);
      } else {
        expect(
          tester
              .widget<SidebarItem>(find.byKey(const ValueKey('nav-History')))
              .selected,
          isTrue,
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
        final destination = size.width < 840
            ? find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(label),
              )
            : find.byKey(ValueKey('nav-$label'));
        await tester.ensureVisible(destination);
        await tester.tap(destination);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Refresh'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$label at $size');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('all tabs fit with the desktop theme and dark mode', (
    tester,
  ) async {
    app.addEntry(
      Entry(type: EntryType.feed, time: DateTime.now(), side: FeedSide.left),
    );
    app.saveMed(Medication(name: 'Iron'));
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    for (final dark in [false, true]) {
      Baby.dark = dark;
      for (final size in const [
        Size(840, 600),
        Size(1100, 800),
        Size(1280, 800),
        Size(1920, 1080),
        Size(1600, 480),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(host(Shell(key: ValueKey('$dark'))));
        await tester.pumpAndSettle();
        for (final label in [
          'Today',
          'History',
          'Pills',
          'Routines',
          'Growth',
        ]) {
          await tester.tap(find.byKey(ValueKey('nav-$label')));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Refresh'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$label at $size');
        }
      }
    }
    Baby.dark = false;
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
    testWidgets('desktop shell, command palette and dialogs at $size', (
      tester,
    ) async {
      // The window size (MediaQuery) decides the desktop theme and dialogs.
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      app.addEntry(
        Entry(
          type: EntryType.nappy,
          time: DateTime.now().subtract(const Duration(minutes: 30)),
          nappy: NappyKind.poo,
        ),
      );
      await tester.pumpWidget(host(const Shell()));
      await tester.pumpAndSettle();
      // Compact desktop theme, sidebar with labels at wide sizes.
      final theme = Theme.of(tester.element(find.byType(HomePage)));
      expect(theme.visualDensity, VisualDensity.compact);
      expect(find.byKey(const ValueKey('desktop-sidebar')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('desktop-sidebar'))).width,
        size.width >= Desktop.wideSidebar
            ? DesktopTokens.sidebarWidth
            : DesktopTokens.railWidth,
      );
      expect(find.byKey(const ValueKey('today-columns')), findsOneWidget);

      // Keyboard shortcuts switch tabs.
      await ctrl(tester, LogicalKeyboardKey.digit3);
      expect(
        tester
            .widget<SidebarItem>(find.byKey(const ValueKey('nav-Pills')))
            .selected,
        isTrue,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Add pill'), findsOneWidget);
      await ctrl(tester, LogicalKeyboardKey.digit1);

      // Ctrl+K opens the palette; arrows and Enter open the result.
      await ctrl(tester, LogicalKeyboardKey.keyK);
      expect(find.byKey(const ValueKey('global-search-field')), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('global-search-field')),
        'poo',
      );
      await tester.pumpAndSettle();
      Finder inPalette(Finder f) =>
          find.descendant(of: find.byType(GlobalSearchView), matching: f);
      expect(inPalette(find.text('Log')), findsOneWidget);
      expect(
        inPalette(find.textContaining('Nappy · Poo', findRichText: true)),
        findsOneWidget,
      );
      // First result is the "Log a nappy" action; the entry is next.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('global-search-field')), findsNothing);
      expect(find.text('Edit nappy'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester
            .widget<SidebarItem>(find.byKey(const ValueKey('nav-History')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      // History on desktop: filters in a panel beside the log.
      expect(find.byKey(const ValueKey('history-filters')), findsOneWidget);

      // Escape closes the palette; the top bar / sidebar trigger opens it.
      await ctrl(tester, LogicalKeyboardKey.keyK);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('global-search-field')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('search-trigger')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('global-search-field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('global-search-field')),
        'zzzz',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No results'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('phone search is full screen and opens settings pre-filled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const Shell()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsNothing);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchPage), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('global-search-field')),
      'night',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Night light', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'Night light',
    );
    expect(find.text('Theme'), findsNothing);
    expect(tester.takeException(), isNull);
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

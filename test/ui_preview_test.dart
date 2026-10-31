// Renders phone-sized screenshots of the main screens for design review.
// Skipped in normal runs (see dart_test.yaml). To render:
//
//   flutter test --run-skipped --tags preview test/ui_preview_test.dart
//
// Output: build/preview/*.png (override with PREVIEW_OUT).
@Tags(['preview'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:baby_app/main.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/pump_ble.dart';
import 'package:baby_app/src/pump_session.dart';
import 'package:baby_app/src/ui/home_page.dart';
import 'package:baby_app/src/ui/setup_page.dart';
import 'package:baby_app/src/ui/sheets.dart';
import 'package:baby_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pump_session_test.dart' show FakePump;

final _root = Directory.current.path;
final _out = Platform.environment['PREVIEW_OUT'] ?? '$_root/build/preview';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Loads every font family declared in pubspec.yaml, plus the icon fonts.
Future<void> _loadFonts() async {
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ?? r'D:\Development\tools\flutter';
  final icons = '$flutter/bin/cache/artifacts/material_fonts';
  final pubspec = File('$_root/pubspec.yaml').readAsStringSync();
  final families = <String, List<String>>{};
  String? family;
  for (final line in const LineSplitter().convert(pubspec)) {
    final f = RegExp(r'^\s+- family:\s*(\S+)').firstMatch(line);
    if (f != null) family = f.group(1);
    final a = RegExp(r'asset:\s*(assets/fonts/\S+)').firstMatch(line);
    if (a != null && family != null) {
      (families[family] ??= []).add('$_root/${a.group(1)}');
    }
  }
  for (final e in families.entries) {
    await _loadFont(e.key, e.value);
  }
  final config = jsonDecode(
    File('$_root/.dart_tool/package_config.json').readAsStringSync(),
  );
  final symbols = (config['packages'] as List).firstWhere(
    (p) => p['name'] == 'material_symbols_icons',
  );
  final symbolsDir = Directory.fromUri(
    Uri.file('$_root/.dart_tool/package_config.json')
        .resolve(symbols['rootUri'] as String),
  ).path;
  await _loadFont('Roboto', ['$icons/roboto-regular.ttf']);
  await _loadFont('MaterialIcons', ['$icons/materialicons-regular.otf']);
  for (final style in ['Outlined', 'Rounded', 'Sharp']) {
    await _loadFont('packages/material_symbols_icons/MaterialSymbols$style', [
      '$symbolsDir/lib/fonts/MaterialSymbols$style.ttf',
    ]);
  }
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('en');
  });

  late Directory dir;
  late AppState app;
  final boundary = GlobalKey();
  final now = DateTime(2026, 10, 31, 10, 20);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ui-preview-');
    app = await AppState.loadForTesting(
      File('${dir.path}/app.json'),
      persist: false,
    );
    Baby.dark = false;
    Baby.dim = false;
  });
  tearDown(() async {
    app.dispose();
    await app.pendingSave;
    await dir.delete(recursive: true);
  });

  Future<void> start(WidgetTester tester) async {
    debugDisableShadows = false;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2340);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: BabyApp(state: app, now: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1.25);
      final data = await image.toByteData(format: ImageByteFormat.png);
      final file = File('$_out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
  }

  testWidgets('setup', (tester) async {
    await start(tester);
    expect(find.byType(SetupPage), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      await snap(tester, 'setup-$i');
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(field.first, 'Mia');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await snap(tester, 'setup-$i-filled');
      }
      if (find.byType(SetupPage).evaluate().isEmpty) break;
      await next(tester);
    }
    await snap(tester, 'after-setup');
    debugDisableShadows = true;
  });

  testWidgets('screens', (tester) async {
    _seed(app, now);
    await start(tester);
    await snap(tester, 'today');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await snap(tester, 'today-scrolled');
    for (final tab in ['History', 'Growth']) {
      final nav = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(tab),
      );
      if (nav.evaluate().isEmpty) continue;
      await tester.tap(nav);
      await snap(tester, tab.toLowerCase());
    }
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Today'),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showSheet(tester.element(find.byType(HomePage)), const FeedSheet()),
    );
    await snap(tester, 'feed-sheet');
    debugDisableShadows = true;
  });
  testWidgets('pump', (tester) async {
    _seed(app, now);
    for (final (h, l, r) in [(7, 70, 55), (11, 60, 50), (15, 80, 65)]) {
      app.addEntry(
        Entry(
          type: EntryType.pump,
          time: now.subtract(Duration(hours: h)),
          side: FeedSide.both,
          durationMin: 18,
          leftMl: l,
          rightMl: r,
          amountMl: l + r,
        ),
      );
    }
    // Two pretend pumps, so the live controls show.
    PumpHub.supportedOverride = true;
    addTearDown(() => PumpHub.supportedOverride = null);
    final hub = PumpHub.instance..attach(app);
    for (final (id, side) in [('l', 0), ('r', 1)]) {
      final pump = FakePump()..status[2] = side;
      final session = PumpSession(pump);
      await tester.runAsync(session.start);
      hub.pumps[id] = ConnectedPump(id, 'M5 Smart')
        ..session = session
        ..state = PumpLinkState.ready;
      app.rememberPump(id, {'name': 'M5 Smart', 'side': side});
    }
    await start(tester);
    await snap(tester, 'pump-today');
    await tester.tap(find.text('Pump'));
    await snap(tester, 'pump-page');
    await tester.tap(find.text('Left'));
    await snap(tester, 'pump-detail');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await snap(tester, 'pump-page-scrolled');
    unawaited(
      showSheet(tester.element(find.byType(Scaffold).last), const PumpSheet()),
    );
    await snap(tester, 'pump-sheet');
    hub.pumps.clear();
    debugDisableShadows = true;
  });

  for (final (name, appearance, hour) in [
    ('dark', 'dark', 10),
    ('night-light', 'light', 22),
  ]) {
    testWidgets(name, (tester) async {
      final at = DateTime(2026, 10, 31, hour, 20);
      _seed(app, at);
      app.setAppearance(appearance);
      if (name == 'night-light') app.setNightLight(true);
      debugDisableShadows = false;
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = const Size(1080, 2340);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BabyApp(state: app, now: () => at),
        ),
      );
      await snap(tester, 'today-$name');
      debugDisableShadows = true;
    });
  }

  testWidgets('desktop', (tester) async {
    _seed(app, now);
    debugDisableShadows = false;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: BabyApp(state: app, now: () => now),
      ),
    );
    await snap(tester, 'desktop-today');
    debugDisableShadows = true;
  });
}

void _seed(AppState app, DateTime now) {
  app.deviceName = "Mum's phone";
  app.saveBabyProfile(
    name: 'Mia',
    dateOfBirth: now.subtract(const Duration(days: 23)),
  );
  app.setNightLight(false);
  final midnight = DateTime(now.year, now.month, now.day);
  for (var d = 3; d >= 0; d--) {
    final day = midnight.subtract(Duration(days: d));
    for (final (i, h) in [1.2, 4.0, 7.1, 9.6, 12.5, 15.4, 18.3, 21.2].indexed) {
      final t = day.add(Duration(minutes: (h * 60).round()));
      if (t.isAfter(now)) continue;
      final bottle = (i + d) % 4 == 3;
      app.addEntry(
        Entry(
          type: EntryType.feed,
          time: t,
          side: bottle
              ? FeedSide.bottle
              : (i.isEven ? FeedSide.left : FeedSide.right),
          durationMin: bottle ? null : 10 + (d + i) % 9,
          amountMl: bottle ? 90 : null,
          by: 'Mum',
        ),
      );
    }
    for (final (i, h) in [2.0, 6.5, 9.9, 14.0, 19.0].indexed) {
      final t = day.add(Duration(minutes: (h * 60).round()));
      if (t.isAfter(now)) continue;
      app.addEntry(
        Entry(
          type: EntryType.nappy,
          time: t,
          nappy: NappyKind.values[(i + d) % NappyKind.values.length],
          by: 'Dad',
        ),
      );
    }
  }
  app.completeSetup();
}

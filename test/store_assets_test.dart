// Generates the app icons and Google Play store graphics. Skipped in normal
// runs (see dart_test.yaml). To regenerate everything:
//
//   flutter test --run-skipped --tags store test/store_assets_test.dart
//   python tool/flatten_store_pngs.py
//
// Output: store/ (icon, feature graphic, screenshots), the Android launcher
// icons in android/app/src/main/res and windows/runner/resources/app_icon.ico.
@Tags(['store'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:baby_app/main.dart';
import 'package:baby_app/src/growth.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/hub_page.dart';
import 'package:baby_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../store/nestling_mark.dart';

final _root = Directory.current.path;
String _p(String rel) => '$_root/$rel';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ?? r'D:\Development\tools\flutter';
  final icons = '$flutter/bin/cache/artifacts/material_fonts';
  final config = jsonDecode(
    File(_p('.dart_tool/package_config.json')).readAsStringSync(),
  );
  final symbols = (config['packages'] as List).firstWhere(
    (p) => p['name'] == 'material_symbols_icons',
  );
  final symbolsDir = Directory.fromUri(
    Uri.parse(
      '${Uri.file('$_root/.dart_tool/package_config.json').resolve(symbols['rootUri'] as String)}',
    ),
  ).path;
  await _loadFont('Nunito', [
    for (final w in [400, 600, 700, 800])
      File(_p('.dart_tool/store_fonts/Nunito-$w.ttf')).existsSync()
          ? _p('.dart_tool/store_fonts/Nunito-$w.ttf')
          : _p('assets/fonts/Nunito-$w.ttf'),
  ]);
  await _loadFont('Roboto', ['$icons/roboto-regular.ttf']);
  await _loadFont('MaterialIcons', ['$icons/materialicons-regular.otf']);
  for (final style in ['Outlined', 'Rounded', 'Sharp']) {
    await _loadFont('packages/material_symbols_icons/MaterialSymbols$style', [
      '$symbolsDir/lib/fonts/MaterialSymbols$style.ttf',
    ]);
  }
}

Future<Uint8List> _png(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<ui.Image> _paint(
  int w,
  int h,
  void Function(Canvas canvas, Size size) draw,
) {
  final recorder = ui.PictureRecorder();
  final size = Size(w.toDouble(), h.toDouble());
  draw(Canvas(recorder), size);
  return recorder.endRecording().toImage(w, h);
}

Future<Uint8List> _mark(int px, MarkLayer layer, {double rounded = 0}) async {
  final image = await _paint(
    px,
    px,
    (c, s) => NestlingMark(layer: layer, rounded: rounded).paint(c, s),
  );
  return _png(image);
}

Future<void> _write(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

Uint8List _ico(Map<int, Uint8List> images) {
  final sizes = images.keys.toList()..sort();
  final out = BytesBuilder();
  final head = ByteData(6 + 16 * sizes.length)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, sizes.length, Endian.little);
  var offset = head.lengthInBytes;
  for (var i = 0; i < sizes.length; i++) {
    final s = sizes[i], data = images[s]!, at = 6 + 16 * i;
    head
      ..setUint8(at, s >= 256 ? 0 : s)
      ..setUint8(at + 1, s >= 256 ? 0 : s)
      ..setUint16(at + 4, 1, Endian.little)
      ..setUint16(at + 6, 32, Endian.little)
      ..setUint32(at + 8, data.length, Endian.little)
      ..setUint32(at + 12, offset, Endian.little);
    offset += data.length;
  }
  out.add(head.buffer.asUint8List());
  for (final s in sizes) {
    out.add(images[s]!);
  }
  return out.toBytes();
}

void _text(
  Canvas canvas,
  String text,
  Offset at, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w800,
  double? maxWidth,
  TextAlign align = TextAlign.left,
  double height = 1.1,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth ?? double.infinity);
  painter.paint(canvas, at);
}

Size _measure(String text, double size, FontWeight weight) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.size;
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('icons', (tester) async {
    await tester.runAsync(() async {
      final res = _p('android/app/src/main/res');
      await _write(
        _p('store/icon-1024.png'),
        await _mark(1024, MarkLayer.full),
      );
      await _write(_p('store/icon-512.png'), await _mark(512, MarkLayer.full));

      const legacy = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final e in legacy.entries) {
        final dir = '$res/mipmap-${e.key}';
        await _write(
          '$dir/ic_launcher.png',
          await _mark(e.value, MarkLayer.full, rounded: 0.22),
        );
        final layer = (e.value * 108 / 48).round();
        await _write(
          '$dir/ic_launcher_foreground.png',
          await _mark(layer, MarkLayer.foreground),
        );
        await _write(
          '$dir/ic_launcher_monochrome.png',
          await _mark(layer, MarkLayer.monochrome),
        );
      }

      await _write(
        _p('windows/runner/resources/app_icon.ico'),
        _ico({
          for (final s in [16, 24, 32, 48, 64, 128, 256])
            s: await _mark(s, MarkLayer.full, rounded: 0.2),
        }),
      );
    });
  });

  testWidgets('feature graphic', (tester) async {
    await tester.runAsync(() async {
      final mark = await decodeImageFromList(
        await _mark(600, MarkLayer.full, rounded: 0.22),
      );
      final image = await _paint(1024, 500, (c, s) {
        c.drawRect(
          Offset.zero & s,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF8F2), Color(0xFFEFEAFF)],
            ).createShader(Offset.zero & s),
        );
        // Soft pastel blobs, one per kind of entry.
        void blob(Offset o, double r, Color color) =>
            c.drawCircle(o, r, Paint()..color = color);
        blob(const Offset(990, 40), 150, const Color(0xFFFFE7DD));
        blob(const Offset(40, 480), 130, const Color(0xFFDDF4EA));
        blob(const Offset(930, 470), 80, const Color(0xFFFFF1CF));
        blob(const Offset(30, 30), 70, const Color(0xFFEDE9FC));

        const iconSize = 280.0;
        final word = _measure('Nestling', 118, FontWeight.w800);
        final tag = _measure('A gentle shared baby log', 36, FontWeight.w600);
        final textW = word.width > tag.width ? word.width : tag.width;
        const gap = 56.0;
        final left = (1024 - (iconSize + gap + textW)) / 2;
        final iconRect = Rect.fromLTWH(
          left,
          (500 - iconSize) / 2,
          iconSize,
          iconSize,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            iconRect.shift(const Offset(0, 10)),
            Radius.circular(iconSize * 0.22),
          ),
          Paint()
            ..color = const Color(0x337C6FDC)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
        c.drawImageRect(
          mark,
          Rect.fromLTWH(0, 0, 600, 600),
          iconRect,
          Paint()..filterQuality = FilterQuality.high,
        );
        final x = left + iconSize + gap;
        _text(
          c,
          'Nestling',
          Offset(x, 150),
          size: 118,
          color: MarkColors.ink,
          letterSpacing: -1.5,
        );
        _text(
          c,
          'A gentle shared baby log',
          Offset(x + 4, 290),
          size: 36,
          color: const Color(0xFF8A849A),
          weight: FontWeight.w600,
        );
        // Entry-colour dots under the tagline.
        var dx = x + 8;
        for (final color in const [
          Color(0xFFE9795A),
          Color(0xFF34A27F),
          Color(0xFFE0A21F),
          Color(0xFF7C6FDC),
        ]) {
          c.drawCircle(Offset(dx + 9, 358), 9, Paint()..color = color);
          dx += 30;
        }
      });
      await _write(_p('store/feature-graphic.png'), await _png(image));
    });
  });

  group('screenshots', () {
    late Directory dir;
    late AppState app;
    final boundary = GlobalKey();
    late DateTime now;

    setUp(() async {
      await initializeDateFormatting('en');
      dir = await Directory.systemTemp.createTemp('store-shots-');
      app = await AppState.loadForTesting(
        File('${dir.path}/app.json'),
        persist: false,
      );
      Baby.dark = false;
      Baby.dim = false;
      now = DateTime.now();
      _seed(app, now);
    });
    tearDown(() async {
      app.dispose();
      await app.pendingSave;
      await dir.delete(recursive: true);
    });

    Future<void> shot(
      WidgetTester tester,
      String file,
      String caption,
      Future<void> Function() navigate,
    ) async {
      // flutter_test draws elevation shadows as hard black outlines.
      debugDisableShadows = false;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1080, 1920);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BabyApp(state: app, now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      await navigate();
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final capture = await render.toImage(pixelRatio: 3);
        final composed = await _paint(1080, 1920, (c, s) {
          c.drawRect(
            Offset.zero & s,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8B7FE8), Color(0xFF7C6FDC)],
              ).createShader(Offset.zero & s),
          );
          final label = TextPainter(
            text: TextSpan(
              text: caption,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 60,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 960);
          label.paint(
            c,
            Offset((1080 - label.width) / 2, (250 - label.height) / 2 + 10),
          );
          // The real app, scaled to sit under the caption like a card.
          const scale = 0.84;
          final w = 1080 * scale, h = 1920 * scale;
          final rect = Rect.fromLTWH((1080 - w) / 2, 1920 - h - 44, w, h);
          final rrect = RRect.fromRectAndRadius(
            rect,
            const Radius.circular(44),
          );
          c.drawRRect(
            rrect.shift(const Offset(0, 8)),
            Paint()
              ..color = const Color(0x55231A6B)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
          );
          c.save();
          c.clipRRect(rrect, doAntiAlias: true);
          c.drawImageRect(
            capture,
            const Rect.fromLTWH(0, 0, 1080, 1920),
            rect,
            Paint()..filterQuality = FilterQuality.high,
          );
          c.restore();
        });
        await _write(_p('store/screenshots/$file.png'), await _png(composed));
      });
      await tester.pumpWidget(const SizedBox());
      debugDisableShadows = true;
    }

    Future<void> tapNav(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
    }

    testWidgets('today', (tester) async {
      await shot(
        tester,
        '01-today',
        'See the whole day at a glance',
        () async {},
      );
    });
    testWidgets('history', (tester) async {
      await shot(tester, '02-history', 'Every feed, nappy and nap', () async {
        await tapNav(tester, 'History');
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(180, 450), const Offset(0, -410));
      });
    });
    testWidgets('charts', (tester) async {
      await shot(tester, '03-charts', 'Patterns over time', () async {
        await tapNav(tester, 'History');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Charts'));
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(180, 450), const Offset(0, -475));
      });
    });
    testWidgets('growth', (tester) async {
      await shot(tester, '04-growth', 'Watch them grow', () async {
        await tapNav(tester, 'Growth');
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(180, 450), const Offset(0, -620));
      });
    });
    testWidgets('pills', (tester) async {
      await shot(tester, '05-pills', 'Never miss a dose', () async {
        await tapNav(tester, 'Pills');
      });
    });
    testWidgets('family', (tester) async {
      await shot(tester, '06-family', 'Share with the whole family', () async {
        openHub(tester.element(find.byType(Shell)));
      });
    });
  });
}

/// A believable two weeks for Mia, ending at [now].
void _seed(AppState app, DateTime now) {
  AppState.appVersion = '1.5.18';
  app.deviceName = "Mum's phone";
  app.saveBabyProfile(
    name: 'Mia',
    dateOfBirth: DateTime(now.year, now.month - 4, now.day),
  );
  app.setNightLight(false);
  const people = ['Mum', 'Dad'];
  void add(Entry e) {
    if (e.time.isAfter(now)) return;
    final end = e.endTime;
    app.addEntry(
      Entry(
        type: e.type,
        time: e.time,
        endTime: end != null && end.isAfter(now) ? null : end,
        side: e.side,
        durationMin: e.durationMin,
        amountMl: e.amountMl,
        nappy: e.nappy,
        medId: e.medId,
        medName: e.medName,
        by: e.by,
        byId: e.by,
        updatedAt: e.time,
      ),
    );
  }

  final midnight = DateTime(now.year, now.month, now.day);
  const feedTimes = [3.5, 6.3, 9.2, 12.1, 15.0, 17.9, 20.7, 23.5];
  const nappyTimes = [4.0, 7.5, 11.0, 14.5, 18.0, 21.5];
  const kinds = [
    NappyKind.pee,
    NappyKind.both,
    NappyKind.pee,
    NappyKind.poo,
    NappyKind.pee,
    NappyKind.pee,
  ];
  const sleeps = [
    (20.0, 23.2),
    (23.9, 27.3),
    (28.0, 30.5),
    (9.6, 10.9),
    (13.0, 14.6),
    (16.6, 17.4),
  ];
  for (var d = 13; d >= 0; d--) {
    final day = midnight.subtract(Duration(days: d));
    DateTime at(double h, int jitter) =>
        day.add(Duration(minutes: (h * 60).round() + jitter));
    for (var i = 0; i < feedTimes.length; i++) {
      if ((d * 3 + i * 5) % 11 == 0 && d > 0) continue;
      final j = (d * 7 + i * 13) % 21 - 10;
      final bottle = (i + d) % 4 == 3;
      add(
        Entry(
          type: EntryType.feed,
          time: at(feedTimes[i], j),
          side: bottle
              ? FeedSide.bottle
              : (i.isEven ? FeedSide.left : FeedSide.right),
          durationMin: bottle ? null : 10 + (d + i) % 9,
          amountMl: bottle ? 90 + (d * 5 + i * 10) % 50 : null,
          by: people[(i + d) % 5 == 0 ? 1 : 0],
        ),
      );
    }
    for (var i = 0; i < nappyTimes.length; i++) {
      if ((d * 5 + i * 7) % 9 == 0 && d > 0) continue;
      final j = (d * 11 + i * 17) % 21 - 10;
      add(
        Entry(
          type: EntryType.nappy,
          time: at(nappyTimes[i], j),
          nappy: kinds[(i + d) % kinds.length],
          by: people[(i + d) % 3 == 0 ? 1 : 0],
        ),
      );
    }
    for (var i = 0; i < sleeps.length; i++) {
      final j = (d * 5 + i * 9) % 15 - 7;
      add(
        Entry(
          type: EntryType.sleep,
          time: at(sleeps[i].$1, j),
          endTime: at(sleeps[i].$2, j + (d + i) % 7),
          by: people[i == 1 ? 1 : 0],
        ),
      );
    }
  }

  final vitD = Medication(
    name: 'Vitamin D',
    dose: '1 drop',
    count: 1,
    startMinutes: 9 * 60,
  );
  final iron = Medication(
    name: 'Iron drops',
    dose: '0.5 ml',
    count: 2,
    startMinutes: 8 * 60,
  );
  app.saveMed(vitD);
  app.saveMed(iron);
  for (var d = 6; d >= 0; d--) {
    final day = midnight.subtract(Duration(days: d));
    app.takePill(vitD, time: day.add(const Duration(hours: 9, minutes: 5)));
    app.takePill(iron, time: day.add(const Duration(hours: 8, minutes: 10)));
    if (d > 0) {
      app.takePill(iron, time: day.add(const Duration(hours: 20, minutes: 15)));
    }
  }

  const weights = [3.3, 4.3, 5.1, 5.9, 6.5];
  const heights = [50.0, 54.5, 58.0, 61.5, 64.0];
  for (var m = 0; m < weights.length; m++) {
    final date = DateTime(now.year, now.month - 4 + m, now.day);
    app.saveGrowth(
      GrowthEntry(
        babyId: app.activeBaby.id,
        date: date.isAfter(now) ? now : date,
        weightKg: weights[m],
        heightCm: heights[m],
        note: switch (m) {
          0 => 'Welcome to the world!',
          1 => 'First smile',
          2 => 'Laughing out loud',
          3 => 'Rolling over',
          _ => 'Loves bath time',
        },
      ),
    );
  }

  app.peers
    ..add(
      Peer(
        deviceId: 'dad-phone',
        host: '192.168.1.24',
        port: 8766,
        key: '482913',
        name: "Dad's phone",
        lastSync: now.subtract(const Duration(minutes: 2)),
      )..appVersion = AppState.appVersion,
    )
    ..add(
      Peer(
        deviceId: 'gran-tablet',
        host: '192.168.1.31',
        port: 8766,
        key: '482913',
        name: "Gran's tablet",
        lastSync: now.subtract(const Duration(hours: 1)),
      )..appVersion = AppState.appVersion,
    );
  for (final (i, peer) in app.peers.indexed) {
    peer.record(
      SyncRecord(
        at: now.subtract(Duration(minutes: i == 0 ? 2 : 60)),
        outgoing: i == 0,
        sent: 12,
        received: 9,
        newThere: i == 0 ? 3 : 0,
        newHere: {'entries': i == 0 ? 2 : 4},
        bytes: 4200,
      ),
    );
  }
  app.completeSetup();
}

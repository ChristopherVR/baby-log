// The Nestling mark, drawn in code so every icon and store graphic can be
// regenerated: `flutter test --run-skipped --tags store test/store_assets_test.dart`.
//
// A sleeping baby tucked into a cream nest under a little moon, on lavender.
import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class MarkColors {
  static const lavender = Color(0xFF7C6FDC);
  static const lavenderDeep = Color(0xFF6A5DCB);
  static const cream = Color(0xFFFFF8F2);
  static const twig = Color(0xFFE3CDB5);
  static const twigDark = Color(0xFFCDB095);
  static const skin = Color(0xFFFFC7AE);
  static const cheek = Color(0xFFF08A6E);
  static const ink = Color(0xFF34304A);
  static const moon = Color(0xFFFFD36B);
  static const coral = Color(0xFFE9795A);
}

enum MarkLayer {
  /// Background and mark: the full icon.
  full,

  /// Mark only, scaled into the adaptive-icon safe zone, transparent.
  foreground,

  /// Single-colour silhouette for themed (monochrome) icons.
  monochrome,

  /// Mark only, at full size, transparent (wordmark lockups).
  bare,
}

/// Paints the mark into a square of side [size].
class NestlingMark extends CustomPainter {
  const NestlingMark({this.layer = MarkLayer.full, this.rounded = 0});
  final MarkLayer layer;

  /// Corner radius as a fraction of the side, for legacy / Windows icons.
  final double rounded;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 1024;
    canvas.save();
    canvas.scale(u);
    if (layer == MarkLayer.full) {
      final rect = const Rect.fromLTWH(0, 0, 1024, 1024);
      final bg = Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.95,
          colors: [
            Color(0xFF9387EE),
            MarkColors.lavender,
            MarkColors.lavenderDeep,
          ],
          stops: [0, 0.55, 1],
        ).createShader(rect);
      if (rounded > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(1024 * rounded)),
          bg,
        );
        canvas.clipRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(1024 * rounded)),
        );
      } else {
        canvas.drawRect(rect, bg);
      }
    }
    if (layer == MarkLayer.foreground || layer == MarkLayer.monochrome) {
      // Keep the mark inside the 66dp safe zone of the 108dp adaptive canvas.
      canvas.translate(512, 512);
      canvas.scale(0.78);
      canvas.translate(-512, -512);
    } else if (layer == MarkLayer.full) {
      // Play and Windows mask or frame the icon: keep to the central ~80%.
      canvas.translate(512, 512);
      canvas.scale(1.02);
      canvas.translate(-512, -512);
    }
    _mark(canvas, mono: layer == MarkLayer.monochrome);
    canvas.restore();
  }

  void _mark(Canvas canvas, {required bool mono}) {
    Paint fill(Color c) => Paint()..color = mono ? Colors.black : c;
    Paint stroke(Color c, double w) => Paint()
      ..color = mono ? Colors.black : c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    const dy = -34.0; // content spans about y 215..830: centre it
    canvas.save();
    canvas.translate(0, dy);
    if (mono) {
      canvas.saveLayer(const Rect.fromLTWH(0, -200, 1024, 1424), Paint());
    }

    // Moon, upper right.
    final moon = Path.combine(
      PathOperation.difference,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(742, 262), radius: 78)),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(782, 238), radius: 66)),
    );
    canvas.drawPath(moon, fill(MarkColors.moon));
    // Stars.
    _spark(canvas, const Offset(284, 292), 30, fill(MarkColors.cream));
    _spark(canvas, const Offset(850, 440), 20, fill(MarkColors.cream));
    _spark(canvas, const Offset(205, 480), 15, fill(MarkColors.cream));

    // Back rim of the nest.
    final rimRect = Rect.fromCenter(
      center: const Offset(512, 575),
      width: 700,
      height: 150,
    );
    canvas.drawOval(rimRect, fill(MarkColors.twigDark));

    // Baby's head.
    const head = Offset(512, 470);
    canvas.drawCircle(head, 200, fill(MarkColors.skin));
    // A single curl of hair.
    canvas.drawPath(
      Path()
        ..moveTo(512, 278)
        ..cubicTo(480, 236, 540, 214, 556, 246),
      stroke(MarkColors.coral, 17),
    );
    // Closed, sleepy eyes.
    for (final x in [440.0, 584.0]) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, 470), width: 68, height: 44),
        0.15,
        math.pi - 0.3,
        false,
        stroke(MarkColors.ink, 16),
      );
    }
    // Cheeks and a tiny smile.
    canvas.drawCircle(
      const Offset(398, 538),
      30,
      fill(MarkColors.cheek.withValues(alpha: 0.55)),
    );
    canvas.drawCircle(
      const Offset(626, 538),
      30,
      fill(MarkColors.cheek.withValues(alpha: 0.55)),
    );
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(512, 548), width: 44, height: 28),
      0.2,
      math.pi - 0.4,
      false,
      stroke(MarkColors.ink, 12),
    );

    // Front of the nest: a bowl whose lip is the front of the rim.
    final bowl = Path()
      ..moveTo(162, 575)
      ..arcTo(rimRect, math.pi, -math.pi, false)
      ..arcTo(
        Rect.fromCenter(
          center: const Offset(512, 575),
          width: 700,
          height: 600,
        ),
        0,
        math.pi,
        false,
      )
      ..close();
    if (mono) {
      // Gap between the baby and the nest so the silhouette still reads.
      canvas.drawPath(
        bowl,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = 46,
      );
    }
    canvas.drawPath(bowl, fill(MarkColors.cream));

    if (!mono) {
      canvas.save();
      canvas.clipPath(bowl);
      // Woven twigs following the bowl.
      for (var i = 0; i < 4; i++) {
        final t = 0.40 + i * 0.17;
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(512, 575 - 30 + i * 18),
            width: 700 * t + 150,
            height: 600 * t + 40,
          ),
          0.35,
          math.pi - 0.7,
          false,
          stroke(i.isEven ? MarkColors.twig : MarkColors.twigDark, 14),
        );
      }
      for (final d in [
        (-210.0, 690.0, 0.9),
        (-95.0, 735.0, 0.4),
        (60.0, 745.0, -0.3),
        (190.0, 700.0, -0.85),
        (-20.0, 665.0, 0.1),
      ]) {
        canvas.save();
        canvas.translate(512 + d.$1, d.$2);
        canvas.rotate(d.$3);
        canvas.drawLine(
          const Offset(0, -34),
          const Offset(0, 34),
          stroke(MarkColors.twig, 13),
        );
        canvas.restore();
      }
      canvas.restore();
      // Lip highlight.
      canvas.drawArc(
        rimRect.deflate(6),
        0.05,
        math.pi - 0.1,
        false,
        stroke(MarkColors.twig, 12),
      );
    }
    if (mono) canvas.restore();
    canvas.restore();
  }

  void _spark(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(NestlingMark old) =>
      old.layer != layer || old.rounded != rounded;
}

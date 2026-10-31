import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../momcozy.dart';
import 'common.dart';
import 'theme.dart';

String pumpModelName(PumpModel m) => switch (m) {
  PumpModel.m5Pro => 'M5 Pro (BP380)',
  PumpModel.m9 => 'M9',
  PumpModel.m9Pro => 'M9 Pro',
  PumpModel.m10 => 'M10',
  PumpModel.air1 => 'Air 1',
};

/// Roughly what one cup holds, to draw how full it is.
int pumpCupMl(PumpModel m) => switch (m) {
  PumpModel.air1 => 150,
  _ => 180,
};

/// A wearable pump cup, drawn in the app's colours: the shape follows the
/// model, the window fills with the milk reading, and a light shows when it
/// pumps. Our own drawing, not Momcozy's artwork.
class PumpPicture extends StatelessWidget {
  const PumpPicture({
    super.key,
    this.model = PumpModel.m5Pro,
    this.side,
    this.milkMl,
    this.running = false,
    this.dimmed = false,
    this.size = 48,
  });

  final PumpModel model;
  final FeedSide? side;
  final int? milkMl;
  final bool running;

  /// Not connected: drawn faded.
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = milkMl == null || milkMl! <= 0
        ? 0.0
        : (milkMl! / pumpCupMl(model)).clamp(0.0, 1.0);
    final letter = switch (side) {
      FeedSide.left => tr('L'),
      FeedSide.right => tr('R'),
      _ => null,
    };
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CupPainter(
                  model: model,
                  fill: fill,
                  running: running,
                  shell: Baby.card,
                  line: Baby.pump,
                  milk: Baby.pumpSoft,
                  milkLine: Baby.pump.withValues(alpha: 0.55),
                  idle: Baby.muted.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (letter != null && size >= 40)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: size * 0.36,
                  height: size * 0.36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Baby.pump,
                    shape: BoxShape.circle,
                    border: Border.all(color: Baby.card, width: 2),
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: Baby.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.17,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter({
    required this.model,
    required this.fill,
    required this.running,
    required this.shell,
    required this.line,
    required this.milk,
    required this.milkLine,
    required this.idle,
  });

  final PumpModel model;
  final double fill;
  final bool running;
  final Color shell, line, milk, milkLine, idle;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // Slimmer for the Air 1, rounder for the M9 family.
    final (wf, hf) = switch (model) {
      PumpModel.air1 => (0.70, 0.86),
      PumpModel.m9 || PumpModel.m9Pro || PumpModel.m10 => (0.84, 0.86),
      PumpModel.m5Pro => (0.80, 0.84),
    };
    final w = s * wf, h = s * hf;
    final body = Rect.fromLTWH((s - w) / 2, (s - h) / 2, w, h);
    // A dome: round on top, flatter at the bottom where the milk collects.
    final cup = RRect.fromRectAndCorners(
      body,
      topLeft: Radius.elliptical(w / 2, h * 0.55),
      topRight: Radius.elliptical(w / 2, h * 0.55),
      bottomLeft: Radius.elliptical(w * 0.32, h * 0.30),
      bottomRight: Radius.elliptical(w * 0.32, h * 0.30),
    );
    final stroke = max(1.5, s * 0.045);
    canvas.drawRRect(cup, Paint()..color = shell);

    // Milk window across the lower half.
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        body.left + w * 0.16,
        body.top + h * 0.48,
        w * 0.68,
        h * 0.38,
      ),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(window, Paint()..color = milk.withValues(alpha: 0.5));
    if (fill > 0) {
      canvas.save();
      canvas.clipRRect(window);
      final top = window.bottom - window.height * fill;
      canvas.drawRect(
        Rect.fromLTRB(window.left, top, window.right, window.bottom),
        Paint()..color = milkLine,
      );
      canvas.restore();
    }
    canvas.drawRRect(
      window,
      Paint()
        ..color = line.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.6,
    );

    // Buttons on top, and the status light.
    final r = w * 0.065;
    final y = body.top + h * 0.28;
    for (final dx in [-0.17, 0.0, 0.17]) {
      final c = Offset(body.center.dx + w * dx, y);
      if (dx == 0) {
        canvas.drawCircle(c, r * 1.15, Paint()..color = running ? line : idle);
      } else {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = line.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 0.55,
        );
      }
    }

    canvas.drawRRect(
      cup,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_CupPainter old) =>
      old.model != model ||
      old.fill != fill ||
      old.running != running ||
      old.line != line ||
      old.shell != shell;
}

/// Battery icon and percentage; red when low.
class BatteryChip extends StatelessWidget {
  const BatteryChip(this.percent, {super.key, this.lastKnown = false});
  final int? percent;

  /// From before the pump disconnected.
  final bool lastKnown;

  @override
  Widget build(BuildContext context) {
    final p = percent;
    final low = p != null && p < 15;
    final color = low ? Baby.error : Baby.muted;
    final icon = switch (p) {
      null => Icons.battery_unknown_rounded,
      >= 90 => Icons.battery_full_rounded,
      >= 60 => Icons.battery_5_bar_rounded,
      >= 35 => Icons.battery_3_bar_rounded,
      >= 15 => Icons.battery_2_bar_rounded,
      _ => Icons.battery_alert_rounded,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 2),
        Text(
          p == null ? '–' : '$p%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontStyle: lastKnown ? FontStyle.italic : null,
          ),
        ),
      ],
    );
  }
}

/// Lets the user say which pump this is, for one that does not say itself.
Future<PumpModel?> pickPumpModel(BuildContext context, {PumpModel? current}) =>
    showModalBottomSheet<PumpModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LText(
                'Which pump is it?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              LText(
                'Momcozy pumps that work with Nestling.',
                style: TextStyle(color: Baby.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final m in const [
                    PumpModel.m5Pro,
                    PumpModel.m9,
                    PumpModel.m9Pro,
                    PumpModel.m10,
                    PumpModel.air1,
                  ])
                    SizedBox(
                      width: 100,
                      child: ChoiceChip(
                        showCheckmark: false,
                        selected: m == current,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        selectedColor: Baby.pumpSoft,
                        label: SizedBox(
                          width: 80,
                          child: Column(
                            children: [
                              PumpPicture(model: m, size: 44),
                              const SizedBox(height: 4),
                              Text(
                                pumpModelName(m),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        onSelected: (_) => Navigator.pop(context, m),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

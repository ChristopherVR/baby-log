import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

Widget _stage(Widget child, {double height = 160}) => Center(
  child: SizedBox(
    height: height,
    width: 240,
    child: Center(child: child),
  ),
);

/// Finish: a circle pops in, the tick draws itself, confetti bursts.
class SuccessArt extends StatelessWidget {
  const SuccessArt({super.key});

  @override
  Widget build(BuildContext context) => _stage(
    Loop(
      period: const Duration(milliseconds: 600),
      builder: (context, t) => SizedBox.square(
        dimension: 150,
        child: CustomPaint(
          painter: _SuccessPainter(t, Baby.primary, Baby.onPrimary, [
            Baby.feed,
            Baby.pee,
            Baby.primary,
            Baby.nappy,
          ]),
        ),
      ),
    ),
  );
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter(this.t, this.fill, this.tick, this.confetti);
  final double t;
  final Color fill, tick;
  final List<Color> confetti;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final pop = Curves.easeOutBack.transform((t / 0.55).clamp(0.0, 1.0));
    canvas.drawCircle(c, 46 * pop, Paint()..color = fill);
    final burst = Curves.easeOut.transform(((t - 0.3) / 0.7).clamp(0.0, 1.0));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + 0.3;
      final d = 52 + 18 * burst;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * d,
        4 * (1 - burst * 0.4),
        Paint()
          ..color = confetti[i % confetti.length].withValues(
            alpha: burst == 0 ? 0 : 1 - burst * 0.35,
          ),
      );
    }
    final path = Path()
      ..moveTo(c.dx - 18, c.dy + 1)
      ..lineTo(c.dx - 5, c.dy + 14)
      ..lineTo(c.dx + 20, c.dy - 13);
    final draw = Curves.easeInOut.transform(
      ((t - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    for (final m in path.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = tick,
      );
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter o) =>
      o.t != t || o.fill != fill || o.tick != tick;
}

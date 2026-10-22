import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common.dart';
import '../theme.dart';
import 'motion.dart';

/// Reads a Baby colour for both the day and the night-light palette.
(Color, Color) _dayNight(Color Function() read) {
  final was = Baby.dim;
  Baby.dim = false;
  final day = read();
  Baby.dim = true;
  final night = read();
  Baby.dim = was;
  return (day, night);
}

Widget _stage(Widget child, {double height = 160}) => Center(
  child: SizedBox(
    height: height,
    width: 240,
    child: Center(child: child),
  ),
);

/// Welcome: baby floating under a moon with twinkling stars.
class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key});

  @override
  Widget build(BuildContext context) => _stage(
    Loop(
      period: const Duration(milliseconds: 2400),
      cycles: 4,
      reverse: true,
      rest: 0.5,
      builder: (context, t) => SizedBox(
        width: 220,
        height: 160,
        child: CustomPaint(
          painter: _SkyPainter(
            t: t,
            halo: Baby.pillSoft,
            moon: Baby.pee,
            star: Baby.pee,
          ),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, (t - 0.5) * 12),
              child: IconBubble(
                glyph: Glyphs.baby,
                color: Baby.card,
                iconColor: Baby.primary,
                size: 92,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.t,
    required this.halo,
    required this.moon,
    required this.star,
  });
  final double t;
  final Color halo, moon, star;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 74, Paint()..color = halo);
    final mc = Offset(size.width - 38, 30);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: mc, radius: 20)),
      Path()..addOval(
        Rect.fromCircle(center: mc + const Offset(9, -6), radius: 17),
      ),
    );
    canvas.drawPath(crescent, Paint()..color = moon);
    const stars = [Offset(26, 34), Offset(40, 128), Offset(188, 118)];
    for (var i = 0; i < stars.length; i++) {
      final s = 0.6 + 0.4 * math.sin((t + i / 3) * math.pi);
      final r = (4 + i) * s * 1.6;
      final o = stars[i];
      final p = Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r);
      canvas.drawPath(
        p,
        Paint()..color = star.withValues(alpha: 0.5 + 0.5 * s),
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter o) =>
      o.t != t || o.halo != halo || o.moon != moon || o.star != star;
}

/// A mini screen that eases from the day colours to the night-light colours.
class NightLightDemo extends StatelessWidget {
  const NightLightDemo({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = _dayNight(() => Baby.bg);
    final card = _dayNight(() => Baby.card);
    final line = _dayNight(() => Baby.line);
    final muted = _dayNight(() => Baby.muted);
    final primary = _dayNight(() => Baby.primary);
    final sun = _dayNight(() => Baby.pee);
    final edge = Baby.line;
    return _stage(
      Loop(
        period: const Duration(milliseconds: 2600),
        cycles: 3,
        reverse: true,
        rest: 0,
        active: active,
        builder: (context, t) {
          final p = smooth(t, 0.2, 0.8);
          Color mix((Color, Color) c) => Color.lerp(c.$1, c.$2, p)!;
          return Container(
            width: 220,
            height: 132,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: mix(bg),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: edge, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mix(card),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(mix(primary), 44),
                        const SizedBox(height: 8),
                        _bar(mix(line), 80),
                        const SizedBox(height: 6),
                        _bar(mix(muted).withValues(alpha: 0.5), 60),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - p,
                        child: Transform.rotate(
                          angle: p * 1.2,
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            size: 40,
                            color: sun.$1,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: p,
                        child: Transform.rotate(
                          angle: (p - 1) * 1.2,
                          child: Icon(
                            Icons.nightlight_round,
                            size: 38,
                            color: primary.$2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bar(Color c, double w) => Container(
    width: w,
    height: 8,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
  );
}

/// A bottle inside a ring that fills up, then rings a bell: "feed in 3 h".
class ReminderDemo extends StatelessWidget {
  const ReminderDemo({super.key});

  @override
  Widget build(BuildContext context) => _stage(
    Loop(
      period: const Duration(milliseconds: 2800),
      cycles: 2,
      builder: (context, t) {
        final ring = smooth(t, 0, 0.8);
        final bell = Curves.elasticOut.transform(
          ((t - 0.8) / 0.2).clamp(0.0, 1.0),
        );
        final shake = t > 0.82 && t < 0.98
            ? math.sin((t - 0.82) * 90) * 0.3
            : 0.0;
        return SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(140),
                painter: _RingPainter(ring, Baby.line, Baby.feed),
              ),
              IconBubble(
                glyph: Glyphs.bottle,
                color: Baby.feedSoft,
                iconColor: Baby.feed,
                size: 76,
              ),
              Positioned(
                top: 2,
                right: 6,
                child: Transform.scale(
                  scale: bell,
                  child: Transform.rotate(
                    angle: shake,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Baby.feed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Baby.bg, width: 3),
                      ),
                      child: Icon(
                        Icons.alarm_rounded,
                        size: 22,
                        color: Baby.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.track, this.fill);
  final double t;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(6);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (t > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * t, false, p..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.t != t || o.track != track || o.fill != fill;
}

/// Two phones with dots travelling between them, then a pulse on arrival.
class PairDemo extends StatelessWidget {
  const PairDemo({super.key});

  @override
  Widget build(BuildContext context) => _stage(
    Loop(
      period: const Duration(milliseconds: 2000),
      cycles: 3,
      builder: (context, t) {
        final pulse = math.sin(math.pi * ((t - 0.75) / 0.25).clamp(0.0, 1.0));
        Widget phone(double scale) => Transform.scale(
          scale: 1 + 0.12 * scale,
          child: Container(
            width: 52,
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Baby.pillSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Baby.primary, width: 3),
            ),
            child: Icon(Icons.favorite_rounded, size: 22, color: Baby.primary),
          ),
        );
        return SizedBox(
          width: 240,
          height: 110,
          child: Row(
            children: [
              phone(0),
              Expanded(
                child: CustomPaint(
                  painter: _DotsPainter(t, Baby.primary),
                  child: Align(
                    alignment: const Alignment(0, -0.6),
                    child: Icon(Icons.wifi_rounded, color: Baby.muted),
                  ),
                ),
              ),
              phone(pulse),
            ],
          ),
        );
      },
    ),
  );
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final p = ((t * 1.3) - i * 0.15).clamp(0.0, 1.0);
      final fade = math.sin(math.pi * p);
      canvas.drawCircle(
        Offset(10 + (size.width - 20) * p, size.height / 2 + 6),
        5,
        Paint()..color = color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter o) => o.t != t || o.color != color;
}

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
          painter: _SuccessPainter(t, Baby.nappy, Baby.onPrimary, [
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

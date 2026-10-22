import 'dart:math' as math;

import 'package:flutter/material.dart';

/// True when the system asks for less motion; animations then jump to rest.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Runs a short, bounded animation (never an endless loop, so tests and
/// battery are safe) and hands the progress 0..1 to [builder]. With reduced
/// motion, or when [active] is false, it shows the [rest] value instead.
class Loop extends StatefulWidget {
  const Loop({
    super.key,
    required this.period,
    required this.builder,
    this.cycles = 1,
    this.reverse = false,
    this.rest = 1,
    this.active = true,
  });
  final Duration period;
  final int cycles;
  final bool reverse;
  final double rest;
  final bool active;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<Loop> createState() => _LoopState();
}

class _LoopState extends State<Loop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Loop old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      _started = false;
      _sync();
    }
  }

  void _sync() {
    if (reducedMotion(context) || !widget.active) {
      _c.stop();
      _c.value = widget.rest;
    } else if (!_started) {
      _started = true;
      _c.value = 0;
      _c.repeat(reverse: widget.reverse, count: widget.cycles);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => widget.builder(context, _c.value),
  );
}

/// Fades and slides its child up once when first shown; [index] staggers
/// siblings. Total time stays under about 550 ms.
class Entrance extends StatefulWidget {
  const Entrance({super.key, this.index = 0, required this.child});
  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final int _delay = math.min(widget.index, 5) * 50;
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 300 + _delay),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Interval(_delay / (300 + _delay), 1, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.value = 1;
    } else if (_c.status == AnimationStatus.dismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _a.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _a.value) * 18),
        child: child,
      ),
    ),
  );
}

/// Slide and fade for a page of a [PageView], driven by the scroll position.
class PageFx extends StatelessWidget {
  const PageFx({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });
  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final d = (index - page).clamp(-1.0, 1.0);
        return Opacity(
          opacity: 1 - d.abs() * 0.7,
          child: Transform.translate(
            offset: Offset(d * 36, 0),
            child: Transform.scale(scale: 1 - d.abs() * 0.04, child: child),
          ),
        );
      },
    );
  }
}

double smooth(double t, [double from = 0, double to = 1]) =>
    Curves.easeInOut.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

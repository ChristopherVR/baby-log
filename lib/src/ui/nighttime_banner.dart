import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../localization.dart';

bool isNighttime(DateTime time) => time.hour >= 18 || time.hour < 6;

/// Current local time is independent of the appearance and log date filters.
class NighttimeBanner extends StatefulWidget {
  const NighttimeBanner({super.key});

  @override
  State<NighttimeBanner> createState() => _NighttimeBannerState();
}

class _NighttimeBannerState extends State<NighttimeBanner> {
  Timer? _tick;
  late final AppLifecycleListener _lifecycle;

  void _start() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _start();
    }
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _start();
        setState(() {});
      },
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) _tick?.cancel();
      },
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NighttimeIndicator(time: DateTime.now());
}

class NighttimeIndicator extends StatelessWidget {
  const NighttimeIndicator({super.key, required this.time});
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    if (!isNighttime(time)) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF242C4C), Color(0xFF3D4264)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.nightlight_round, color: Color(0xFFFFDDA1)),
          const SizedBox(width: 10),
          const Expanded(
            child: LText(
              'Nighttime',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            DateFormat.Hm(Localizations.localeOf(context).languageCode)
                .format(time),
            style: const TextStyle(
              color: Color(0xFFE1E5F5),
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

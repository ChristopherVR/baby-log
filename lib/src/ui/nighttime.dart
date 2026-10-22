import 'package:flutter/material.dart';

import 'common.dart';
import 'theme.dart';

/// Nighttime follows the device's local clock, independently of log filters.
bool isNighttime(DateTime time) => time.hour >= 18 || time.hour < 6;

/// A quiet note that the night light is dimming the colours, visible across
/// app routes, with a shortcut to turn it off.
class NighttimeNotice extends StatelessWidget {
  const NighttimeNotice({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: Baby.bg,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime_rounded, size: 16, color: Baby.primary),
            const SizedBox(width: 8),
            Flexible(
              child: LText(
                'Night light · softer colours until 6 am',
                style: TextStyle(fontSize: 12, color: Baby.muted),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () => AppScope.of(context).setNightLight(false),
              child: const LText('Turn off'),
            ),
          ],
        ),
      ),
    ),
  );
}

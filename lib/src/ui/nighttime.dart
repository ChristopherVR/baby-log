import 'package:flutter/material.dart';

import '../localization.dart';
import 'theme.dart';

/// Nighttime follows the device's local clock, independently of log filters.
bool isNighttime(DateTime time) => time.hour >= 18 || time.hour < 6;

/// A quiet explanation of the automatic palette, visible across app routes.
class NighttimeNotice extends StatelessWidget {
  const NighttimeNotice({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: Baby.bg,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.nightlight_round, size: 16, color: Baby.primary),
            const SizedBox(width: 8),
            Flexible(
              child: LText(
                'Dark mode for nighttime · until 6 am',
                style: TextStyle(fontSize: 12, color: Baby.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

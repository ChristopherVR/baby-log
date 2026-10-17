import 'dart:io';

import 'package:flutter/material.dart';

import '../localization.dart';
import '../updates.dart';

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, this.settings = false});
  final bool settings;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final updates = AppUpdates.instance;
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        if (!settings && updates.available == null) {
          return const SizedBox.shrink();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LText(
                  updates.available == null
                      ? 'App updates'
                      : 'New update available: ${updates.available!.version}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (updates.message != null) ...[
                  const SizedBox(height: 8),
                  LText(updates.message!),
                ],
                if (updates.downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: updates.progress),
                  LText('Downloading: ${(updates.progress * 100).round()}%'),
                ] else if (updates.available != null) ...[
                  const SizedBox(height: 8),
                  const LText(
                    'Download from GitHub, then confirm installation in Android. Your logs stay on this device.',
                  ),
                  FilledButton.icon(
                    onPressed: updates.install,
                    icon: const Icon(Icons.system_update_rounded),
                    label: const LText('Update'),
                  ),
                ],
                if (settings)
                  TextButton(
                    onPressed: updates.checking || updates.downloading
                        ? null
                        : () => updates.check(manual: true),
                    child: LText(
                      updates.checking
                          ? 'Checking for updates…'
                          : 'Check for updates',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../localization.dart';
import '../store.dart';

class InstalledChangelog {
  const InstalledChangelog(this.version, this.notes);
  final String version;
  final String notes;

  static Future<InstalledChangelog?> load() async {
    final installed = await PackageInfo.fromPlatform();
    final source = await rootBundle.loadString('assets/release_notes.json');
    return parse(source, installed.version);
  }

  static InstalledChangelog? parse(String source, String installedVersion) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final version = json['version'];
    final notes = json['notes'];
    if (version != installedVersion ||
        version is! String ||
        version.isEmpty ||
        notes is! String ||
        notes.trim().isEmpty) {
      return null;
    }
    return InstalledChangelog(version, notes.trim());
  }

  bool shouldShow(String seenVersion) => version != seenVersion;
}

Future<void> showInstalledChangelog(
  BuildContext context,
  AppState app,
  InstalledChangelog notes,
) async {
  if (!notes.shouldShow(app.changelogSeenVersion)) return;
  await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const LText('What’s new'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                'Version ${notes.version}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              // Generated commit text is already prose, not a translation key.
              Text(notes.notes),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const LText('Got it'),
        ),
      ],
    ),
  );
  // A dismissed dialog was also seen. Persist only after it was displayed.
  if (context.mounted) {
    await app.acknowledgeChangelog(notes.version);
  }
}

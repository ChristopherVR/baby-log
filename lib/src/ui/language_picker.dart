import 'package:flutter/material.dart';

import 'common.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.showLabel = true});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          const LText(
            'Language',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'af', label: Text('Afrikaans')),
          ],
          selected: {app.language},
          onSelectionChanged: (selection) => app.setLanguage(selection.single),
        ),
      ],
    );
  }
}

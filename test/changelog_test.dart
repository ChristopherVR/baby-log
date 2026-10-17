import 'dart:convert';
import 'dart:io';

import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/changelog_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only notes for the installed version are shown', () {
    final source = jsonEncode({
      'version': '1.4.9',
      'notes': 'Changes\n- Improve editing',
    });
    expect(InstalledChangelog.parse(source, '1.4.8'), isNull);
    final notes = InstalledChangelog.parse(source, '1.4.9')!;
    expect(notes.shouldShow('1.4.8'), isTrue);
    expect(notes.shouldShow('1.4.9'), isFalse);
    expect(InstalledChangelog.parse('{"version":"", "notes":""}', ''), isNull);
    expect(
      InstalledChangelog.parse('{"version":"1.4.9", "notes":" "}', '1.4.9'),
      isNull,
    );
  });

  test(
    'acknowledgement persists across restarts and remains device-local',
    () async {
      final dir = await Directory.systemTemp.createTemp('changelog-test-');
      final file = File('${dir.path}/app.json');
      final app = await AppState.loadForTesting(file);
      AppState? reloaded;
      try {
        await app.acknowledgeChangelog('1.4.9');
        reloaded = await AppState.loadForTesting(file);
        expect(reloaded.changelogSeenVersion, '1.4.9');
        expect(
          const InstalledChangelog(
            '1.4.9',
            'Notes',
          ).shouldShow(reloaded.changelogSeenVersion),
          isFalse,
        );
        expect(
          jsonDecode(app.exportBackup()),
          isNot(contains('changelogSeenVersion')),
        );
      } finally {
        app.dispose();
        reloaded?.dispose();
        await app.pendingSave;
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets('changelog is scrollable and appears once per version', (
    tester,
  ) async {
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-changelog-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    final notes = InstalledChangelog(
      '1.4.9',
      List.filled(60, '- Improved editing').join('\n'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showInstalledChangelog(context, app, notes),
              child: const Text('Open notes'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open notes'));
    await tester.pumpAndSettle();
    expect(find.text('What’s new'), findsOneWidget);
    expect(find.text('Version 1.4.9'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(app.changelogSeenVersion, isEmpty);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(app.changelogSeenVersion, '1.4.9');
    await tester.tap(find.text('Open notes'));
    await tester.pumpAndSettle();
    expect(find.text('What’s new'), findsNothing);
    expect(notes.shouldShow(app.changelogSeenVersion), isFalse);
    expect(
      const InstalledChangelog(
        '1.4.10',
        'New notes',
      ).shouldShow(app.changelogSeenVersion),
      isTrue,
    );
    expect(
      jsonDecode(app.exportBackup()),
      isNot(contains('changelogSeenVersion')),
    );
  });
}

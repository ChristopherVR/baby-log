import 'dart:convert';
import 'dart:io';

import 'package:baby_app/main.dart';
import 'package:baby_app/src/localization.dart';
import 'package:baby_app/src/notifications.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/language_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppLanguage.use('en'));

  test('Afrikaans labels and templates preserve user-supplied values', () {
    expect(tr('Save routine', language: 'af'), 'Stoor roetine');
    expect(
      tr('Next feed reminder at 18:00', language: 'af'),
      'Volgende voedingsherinnering om 18:00',
    );
    expect(
      tr('Mark Robin’s bath as done', language: 'af'),
      'Merk Robin’s bath as gedoen',
    );
    expect(
      tr('Last done: 18:30 · Chris', language: 'af'),
      'Laas gedoen: 18:30 · Chris',
    );
    expect(tr('Mon, Wed, Fri', language: 'af'), 'Ma, Wo, Vr');
    expect(tr('My custom routine', language: 'af'), 'My custom routine');
    expect(tr('Save routine', language: 'en'), 'Save routine');
    AppLanguage.use('af');
    final info = ReminderInfo(
      id: 1,
      kind: 'feed',
      title: 'Robin: time for a feed',
      body: 'Reminder you set after the last feed',
    );
    final back = ReminderInfo.parse(info.toPayload())!;
    expect(back.language, 'af');
    expect(back.withId(920).language, 'af');
    expect(back.title, 'Robin: tyd vir ’n voeding');
    expect(back.body, 'Herinnering wat jy ná die laaste voeding ingestel het');
  });

  test(
    'language persists locally and is excluded from shared backup data',
    () async {
      final dir = await Directory.systemTemp.createTemp('baby-language-test-');
      final app = await AppState.loadForTesting(File('${dir.path}/app.json'));
      AppState? loaded;
      try {
        app.setLanguage('af');
        await app.pendingSave;
        loaded = await AppState.loadForTesting(File(app.dataFilePath));
        expect(loaded.language, 'af');
        expect(AppLanguage.code, 'af');
        app.setLanguage('unknown');
        expect(app.language, 'af');
        expect(
          (jsonDecode(app.exportBackup()) as Map).containsKey('language'),
          isFalse,
        );
      } finally {
        app.dispose();
        loaded?.dispose();
        await app.pendingSave;
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets('language can change in setup and settings without restarting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-language-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    await tester.pumpWidget(BabyApp(state: app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Afrikaans'));
    await tester.pumpAndSettle();
    expect(app.language, 'af');
    expect(find.text('Welkom by Nestling'), findsOneWidget);
    expect(find.text('Slaan oor'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('af'),
    );
    await tester.tap(find.text('Slaan oor'));
    await tester.pumpAndSettle();
    expect(find.text('Vandag'), findsWidgets);
    expect(find.text('Roetines'), findsOneWidget);
    await tester.tap(find.text('Roetines'));
    await tester.pumpAndSettle();
    expect(find.text('’n Klein ritme vir jou baba'), findsOneWidget);
    await tester.tap(find.byTooltip('Instellings'));
    await tester.pumpAndSettle();
    expect(find.text('Taal'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(LanguagePicker),
        matching: find.text('English'),
      ),
    );
    await tester.pumpAndSettle();
    expect(app.language, 'en');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.byType(LanguagePicker).hitTestable(), findsOneWidget);

    final search = find.byType(TextField);
    await tester.enterText(search, '  FEED reminder  ');
    await tester.pumpAndSettle();
    expect(find.text('Feed reminder'), findsOneWidget);
    expect(find.text("Baby's name"), findsNothing);
    expect(find.byType(LanguagePicker), findsNothing);
    await tester.tap(find.text('Feed reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Remind me to feed'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.enterText(search, 'no-such-setting');
    await tester.pumpAndSettle();
    expect(
      find.text('No settings found. Try a different search.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(find.byType(LanguagePicker).hitTestable(), findsOneWidget);

    // Both language names and translated setting labels are searchable.
    await tester.enterText(search, 'taal');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Afrikaans'));
    await tester.pumpAndSettle();
    expect(app.language, 'af');
    expect(find.text('Taal'), findsOneWidget);
    expect(find.text('Soek instellings'), findsOneWidget);
    await tester.enterText(search, 'voedingsherinnering');
    await tester.pumpAndSettle();
    expect(find.text(tr('Feed reminder')), findsOneWidget);
    expect(find.byType(LanguagePicker), findsNothing);
    await tester.enterText(search, 'English');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(LanguagePicker),
        matching: find.text('English'),
      ),
    );
    await tester.pumpAndSettle();
    expect(app.language, 'en');
    expect(find.text('Language'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

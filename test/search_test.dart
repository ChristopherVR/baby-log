import 'dart:io';

import 'package:baby_app/src/growth.dart';
import 'package:baby_app/src/localization.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/routines.dart';
import 'package:baby_app/src/search.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/global_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  group('engine', () {
    SearchItem item(
      String title, {
      SearchKind kind = SearchKind.entry,
      String? subtitle,
      List<String> terms = const [],
      DateTime? date,
    }) => SearchItem(
      kind: kind,
      id: title,
      title: title,
      subtitle: subtitle,
      terms: terms,
      date: date,
    );

    test('folds case and accents without changing length', () {
      expect(foldText('Voeding · Bêre’s'), "voeding · bere's");
      expect(foldText('Ë').length, 1);
      expect(queryWords('  Feed   LEFT '), ['feed', 'left']);
    });

    test('every word must match title, subtitle or terms', () {
      final items = [
        item('Feed · Left', terms: ['Breast']),
        item('Feed · Right'),
        item('Nappy · Pee', subtitle: 'by Mom'),
      ];
      final groups = search(items, 'feed left');
      expect(groups.single.hits.map((h) => h.item.title), ['Feed · Left']);
      expect(
        search(items, 'breast').single.hits.single.item.title,
        'Feed · Left',
      );
      expect(search(items, 'mom').single.hits.single.item.title, 'Nappy · Pee');
      expect(search(items, 'bottle'), isEmpty);
    });

    test('title and word-start matches rank first, then recent ones', () {
      final now = DateTime(2026, 10, 22, 12);
      final items = [
        item('Iron drops', kind: SearchKind.pill, terms: ['bath']),
        item('Bath time', kind: SearchKind.pill),
        item('Footbath', kind: SearchKind.pill),
        item('Feed', date: now.subtract(const Duration(days: 30))),
        item('Feed', date: now.subtract(const Duration(hours: 1))),
      ];
      final pills = search(items, 'bath', now: now).first.hits;
      expect(pills.map((h) => h.item.title), [
        'Bath time',
        'Footbath',
        'Iron drops',
      ]);
      final feeds = search(
        items,
        'feed',
        now: now,
      ).firstWhere((g) => g.kind == SearchKind.entry).hits;
      expect(feeds.first.item.date, now.subtract(const Duration(hours: 1)));
    });

    test('groups follow kind order and respect limits', () {
      final items = [
        item('Feed reminder', kind: SearchKind.setting),
        for (var i = 0; i < 12; i++) item('Feed $i'),
        item('Log a feed', kind: SearchKind.action),
      ];
      final groups = search(items, 'feed');
      expect(groups.map((g) => g.kind), [
        SearchKind.action,
        SearchKind.entry,
        SearchKind.setting,
      ]);
      final log = groups[1];
      expect(log.hits, hasLength(defaultSearchLimits[SearchKind.entry]));
      expect(log.total, 12);
    });

    test('highlight ranges are merged and found in the original text', () {
      expect(matchRanges('Feed · Left', ['fe', 'eed']), [(start: 0, end: 4)]);
      expect(matchRanges('Bêre', ['be']), [(start: 0, end: 2)]);
      final hit = search([item('Bottle feed')], 'feed').single.hits.single;
      expect(hit.titleRanges, [(start: 7, end: 11)]);
    });

    test('empty query suggests actions, pages and recent entries', () {
      final items = [
        item('Log a feed', kind: SearchKind.action),
        item('History', kind: SearchKind.page),
        item('Iron', kind: SearchKind.pill),
        for (var i = 0; i < 9; i++)
          item('Feed $i', date: DateTime(2026, 1, i + 1)),
      ];
      final groups = search(items, '  ');
      expect(groups.map((g) => g.kind), [
        SearchKind.action,
        SearchKind.page,
        SearchKind.entry,
      ]);
      expect(groups.last.hits, hasLength(5));
      expect(groups.last.hits.first.item.title, 'Feed 8');
    });
  });

  group('index', () {
    late AppState app;
    setUp(() async {
      await initializeDateFormatting('en');
      AppLanguage.use('en');
      app = await AppState.loadForTesting(
        File('unused-search-test.json'),
        persist: false,
      );
    });
    tearDown(() {
      AppLanguage.use('en');
      app.dispose();
    });

    List<SearchGroup> find(String query) =>
        search(buildSearchIndex(app), query);
    SearchGroup? group(String query, SearchKind kind) =>
        find(query).where((g) => g.kind == kind).firstOrNull;

    test('finds entries, pills, routines, growth, babies and settings', () {
      final now = DateTime.now();
      app.addEntry(
        Entry(
          type: EntryType.feed,
          time: now.subtract(const Duration(hours: 2)),
          side: FeedSide.bottle,
          amountMl: 120,
        ),
      );
      app.addEntry(
        Entry(
          type: EntryType.nappy,
          time: now.subtract(const Duration(hours: 1)),
          nappy: NappyKind.poo,
        ),
      );
      app.saveMed(Medication(name: 'Iron drops', dose: '1 ml'));
      app.saveRoutine(
        Routine(babyId: app.activeBabyId, name: 'Bath time', notes: 'lavender'),
      );
      app.saveGrowth(
        GrowthEntry(
          babyId: app.activeBabyId,
          date: DateTime(now.year, now.month, now.day),
          weightKg: 4.25,
          note: 'First clinic visit',
        ),
      );
      app.addBaby('Noah', select: false);

      expect(
        group('bottle 120', SearchKind.entry)!.hits.single.item.title,
        'Bottle feed',
      );
      expect(
        group('dirty', SearchKind.entry)!.hits.single.item.title,
        'Nappy · Poo',
      );
      expect(
        group('iron', SearchKind.pill)!.hits.single.item.subtitle,
        contains('1 ml'),
      );
      expect(group('lavender', SearchKind.routine)!.hits, hasLength(1));
      expect(
        group('clinic', SearchKind.growth)!.hits.single.item.title,
        '4.25 kg',
      );
      expect(group('noah', SearchKind.baby)!.hits, hasLength(1));
      expect(
        group('night light', SearchKind.setting)!.hits.single.item.title,
        'Night light',
      );
      expect(
        group('log a feed', SearchKind.action)!.hits.first.item.id,
        'log-feed',
      );
      expect(group('today', SearchKind.entry)!.total, 2);
    });

    test('matches Afrikaans and English whatever the app language', () {
      app.addEntry(
        Entry(type: EntryType.feed, time: DateTime.now(), side: FeedSide.left),
      );
      expect(group('voeding links', SearchKind.entry)!.hits, hasLength(1));
      expect(
        group('instellings', SearchKind.page)!.hits.single.item.id,
        'settings',
      );
      AppLanguage.use('af');
      final hit = group('feed left', SearchKind.entry)!.hits.single;
      expect(hit.item.title, 'Voeding · Links');
      expect(group('pille', SearchKind.page)!.hits.single.item.title, 'Pille');
    });
  });
}

import 'dart:math' as math;

import 'localization.dart';

/// Global search: a small, dependency-free engine that matches a query
/// against [SearchItem]s and returns ranked [SearchGroup]s with the ranges to
/// highlight. The index is built by the UI (lib/src/ui/global_search.dart),
/// which knows how entries, pills, routines and so on are labelled.

/// Kinds of results, in the order their groups are shown.
enum SearchKind { action, page, baby, pill, routine, growth, entry, setting }

/// Group heading for a kind of result (English; translate with [tr]).
String searchKindLabel(SearchKind kind) => switch (kind) {
  SearchKind.action => 'Quick actions',
  SearchKind.page => 'Go to',
  SearchKind.baby => 'Babies',
  SearchKind.pill => 'Pills',
  SearchKind.routine => 'Routines',
  SearchKind.growth => 'Growth journal',
  SearchKind.entry => 'Log',
  SearchKind.setting => 'Settings',
};

/// One thing that can be found.
class SearchItem {
  const SearchItem({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.terms = const [],
    this.date,
    this.data,
  });

  final SearchKind kind;

  /// Stable id within its kind (an entry id, an action name...).
  final String id;

  /// Shown, highlighted and matched first. Already in the display language.
  final String title;

  /// Shown under the title, highlighted and matched second.
  final String? subtitle;

  /// Extra text it can be found by but which is not shown: the English and
  /// Afrikaans words for it, dates in other formats, notes...
  final List<String> terms;

  /// When it happened, for showing and to prefer recent records.
  final DateTime? date;

  /// What to open: the record itself, for the UI.
  final Object? data;

  @override
  String toString() => 'SearchItem($kind, $id, $title)';
}

/// A half-open range [start, end) of matched characters.
typedef MatchRange = ({int start, int end});

class SearchHit {
  const SearchHit(this.item, this.score, this.titleRanges, this.subtitleRanges);
  final SearchItem item;
  final double score;
  final List<MatchRange> titleRanges;
  final List<MatchRange> subtitleRanges;
}

class SearchGroup {
  const SearchGroup(this.kind, this.hits, this.total);
  final SearchKind kind;

  /// The best hits, at most the group's limit.
  final List<SearchHit> hits;

  /// How many items matched in total.
  final int total;

  String get label => searchKindLabel(kind);
}

/// Results shown per group unless [search] is given other limits.
const defaultSearchLimits = {
  SearchKind.action: 5,
  SearchKind.page: 4,
  SearchKind.baby: 4,
  SearchKind.pill: 5,
  SearchKind.routine: 5,
  SearchKind.growth: 5,
  SearchKind.entry: 8,
  SearchKind.setting: 5,
};

const _fold = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ý': 'y', 'ÿ': 'y', 'ç': 'c', 'ñ': 'n', //
  '’': "'", '‘': "'", 'ʼ': "'", '–': '-', '—': '-', '‑': '-', //
};

/// Lower case without accents, so "ê" finds "e" and the other way round.
/// Keeps the length (one character for one), so ranges found in the folded
/// text apply to the original.
String foldText(String text) {
  final lower = text.toLowerCase();
  if (lower.length != text.length) return text; // Never misalign highlights.
  final out = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final c = lower[i];
    out.write(_fold[c] ?? c);
  }
  return out.toString();
}

/// The words of a query, folded. Empty if there is nothing to search for.
List<String> queryWords(String query) =>
    foldText(query.trim())
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

final _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _isWordStart(String text, int i) =>
    i == 0 || !_letter.hasMatch(text[i - 1]);

/// Folded title, subtitle and terms per item, worked out once.
final _folded = Expando<(String, String, String)>();

/// Where [words] occur in [text], merged and sorted, for highlighting.
List<MatchRange> matchRanges(String text, List<String> words) {
  if (text.isEmpty || words.isEmpty) return const [];
  final folded = foldText(text);
  final ranges = <MatchRange>[];
  for (final w in words) {
    var from = 0;
    while (true) {
      final i = folded.indexOf(w, from);
      if (i < 0) break;
      ranges.add((start: i, end: i + w.length));
      from = i + 1;
    }
  }
  if (ranges.isEmpty) return const [];
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <MatchRange>[ranges.first];
  for (final r in ranges.skip(1)) {
    final last = merged.last;
    if (r.start <= last.end) {
      merged[merged.length - 1] = (
        start: last.start,
        end: math.max(last.end, r.end),
      );
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// How well [word] matches [folded]: 2 at the start of a word, 1 inside a
/// word, 0 not at all.
int _matchQuality(String folded, String word) {
  var i = folded.indexOf(word);
  if (i < 0) return 0;
  while (i >= 0) {
    if (_isWordStart(folded, i)) return 2;
    i = folded.indexOf(word, i + 1);
  }
  return 1;
}

/// Scores [item] for [words]; null if any word is missing. Every word has to
/// be found in the title, subtitle or terms.
SearchHit? scoreItem(SearchItem item, List<String> words, {DateTime? now}) {
  final (title, subtitle, terms) = _folded[item] ??= (
    foldText(item.title),
    foldText(item.subtitle ?? ''),
    foldText(item.terms.join(' · ')),
  );
  var score = 0.0;
  for (final w in words) {
    final t = _matchQuality(title, w);
    if (t > 0) {
      score += t == 2 ? 30 : 14;
      continue;
    }
    final s = _matchQuality(subtitle, w);
    if (s > 0) {
      score += s == 2 ? 12 : 6;
      continue;
    }
    final k = _matchQuality(terms, w);
    if (k == 0) return null;
    score += k == 2 ? 9 : 4;
  }
  final whole = words.join(' ');
  if (title == whole) {
    score += 60;
  } else if (title.startsWith(whole)) {
    score += 40;
  }
  // Recent records first among equally good matches.
  final date = item.date;
  if (date != null) {
    final days = (now ?? DateTime.now()).difference(date).inHours.abs() / 24;
    score += 8 * math.exp(-days / 14);
  }
  return SearchHit(
    item,
    score,
    matchRanges(item.title, words),
    matchRanges(item.subtitle ?? '', words),
  );
}

/// Searches [items] and groups the hits by kind, in [SearchKind] order. With
/// an empty query it suggests: every action and page, plus the most recent
/// log entries.
List<SearchGroup> search(
  List<SearchItem> items,
  String query, {
  Map<SearchKind, int> limits = defaultSearchLimits,
  DateTime? now,
}) {
  final words = queryWords(query);
  final byKind = <SearchKind, List<SearchHit>>{};
  if (words.isEmpty) {
    for (final item in items) {
      if (item.kind == SearchKind.action ||
          item.kind == SearchKind.page ||
          item.kind == SearchKind.entry) {
        (byKind[item.kind] ??= []).add(SearchHit(item, 0, const [], const []));
      }
    }
    byKind[SearchKind.entry]?.sort(
      (a, b) =>
          (b.item.date ?? DateTime(0)).compareTo(a.item.date ?? DateTime(0)),
    );
    final recent = byKind[SearchKind.entry];
    if (recent != null && recent.length > 5) {
      byKind[SearchKind.entry] = recent.sublist(0, 5);
    }
    return [
      for (final kind in SearchKind.values)
        if (byKind[kind] case final hits?) SearchGroup(kind, hits, hits.length),
    ];
  }
  for (final item in items) {
    final hit = scoreItem(item, words, now: now);
    if (hit != null) (byKind[item.kind] ??= []).add(hit);
  }
  return [
    for (final kind in SearchKind.values)
      if (byKind[kind] case final hits?)
        SearchGroup(
          kind,
          (hits..sort((a, b) {
                final c = b.score.compareTo(a.score);
                if (c != 0) return c;
                return (b.item.date ?? DateTime(0)).compareTo(
                  a.item.date ?? DateTime(0),
                );
              }))
              .take(limits[kind] ?? 5)
              .toList(),
          hits.length,
        ),
  ];
}

/// [en] and its Afrikaans translation, so either language finds a record
/// whatever language the app is shown in.
List<String> bothLanguages(String en) {
  final af = tr(en, language: 'af');
  return af == en ? [en] : [en, af];
}

/// A setting that can be searched from anywhere. Selecting it opens Settings
/// with [title] in its search box, which shows that setting.
class SettingTopic {
  const SettingTopic(this.title, this.section, this.terms);
  final String title;
  final String section;
  final List<String> terms;
}

/// Mirrors the searchable rows of the Settings screen.
const settingTopics = [
  SettingTopic('Language', 'Language', ['English', 'Afrikaans']),
  SettingTopic('Add a baby', 'Babies', ['Another baby', 'Twins']),
  SettingTopic('Feed reminder', 'Reminders', [
    'Remind me to feed',
    'How long after a feed?',
    'How it rings',
    'Notification',
    'Alarm',
  ]),
  SettingTopic('Pill reminders', 'Reminders', [
    'How it rings',
    'Notification',
    'Alarm',
  ]),
  SettingTopic('Theme', 'Appearance', ['Light', 'Dark', 'Match phone']),
  SettingTopic('Night light', 'Appearance', ['Nighttime', 'Dim']),
  SettingTopic('Family hub', 'Family hub', [
    'Devices sharing this log',
    'Add a device',
    'Pair',
    'Share',
    'Scan code',
    'Wi-Fi',
    'Sync by QR code',
  ]),
  SettingTopic('Sync now', 'Family hub', [
    'Sync automatically',
    'Keep syncing when closed',
    'Allow background use',
  ]),
  SettingTopic('Export backup', 'Your data', ['History', 'spreadsheet']),
  SettingTopic('Import backup', 'Your data', []),
  SettingTopic('Device name', 'This device', []),
  SettingTopic('App version', 'This device', [
    'Check for updates',
    'Update',
    'GitHub',
  ]),
  SettingTopic('Run first-time setup again', 'This device', ['Welcome']),
];

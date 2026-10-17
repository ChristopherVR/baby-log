import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import 'common.dart';
import 'data_transfer.dart';
import 'sheets.dart';
import 'theme.dart';

enum Grouping { day, week, month, type }

DateFormat get _fullDate => DateFormat('EEEE d MMMM yyyy');
final _shortDate = DateFormat('d/M/yyyy');

/// Search text per entry, built once (entries never change; an edit is a new object).
final _searchCache = Expando<String>();

/// Text an entry can be found by: what it is, its details, who logged it, and when.
String _searchText(Entry e) => _searchCache[e] ??= [
  ?e.by,
  entryTitle(e),
  entryDetail(e) ?? '',
  if (e.type == EntryType.feed && e.side != FeedSide.bottle)
    'breast bors voeding',
  if (e.side == FeedSide.left) 'left links',
  if (e.side == FeedSide.right) 'right regs',
  if (e.side == FeedSide.bottle) 'bottle bottel voeding',
  if (e.type == EntryType.nappy) 'doek',
  if (e.type == EntryType.nappy && e.nappy != NappyKind.poo) 'wet nat piepie',
  if (e.type == EntryType.nappy && e.nappy != NappyKind.pee) 'dirty vuil poef',
  if (e.type == EntryType.pill) 'pill medicine pil medisyne',
  _fullDate.format(e.time),
  _shortDate.format(e.time),
  hm(e.time),
].join(' ').toLowerCase();

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _search = TextEditingController();
  EntryType? filter;
  Grouping grouping = Grouping.day;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Entry> _shown(List<Entry> all) {
    final terms = _search.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return [
      for (final e in all)
        if ((filter == null || e.type == filter) &&
            (terms.isEmpty ||
                terms.every(
                  '${_searchText(e)} ${dayLabel(e.time).toLowerCase()}'
                      .contains,
                )))
          e,
    ];
  }

  /// Groups [list] (newest first) into titled sections.
  List<(String, List<Entry>)> _group(List<Entry> list) {
    if (grouping == Grouping.type) {
      return [
        for (final (type, title) in [
          (EntryType.feed, 'Feeds'),
          (EntryType.nappy, 'Nappies'),
          (EntryType.pill, 'Pills'),
        ])
          if (list.any((e) => e.type == type))
            (title, list.where((e) => e.type == type).toList()),
      ];
    }
    final groups = <(String, List<Entry>)>[];
    String? lastKey;
    for (final e in list) {
      final key = _groupTitle(e.time);
      if (key != lastKey) {
        groups.add((key, []));
        lastKey = key;
      }
      groups.last.$2.add(e);
    }
    return groups;
  }

  String _groupTitle(DateTime t) {
    switch (grouping) {
      case Grouping.day:
      case Grouping.type:
        return dayLabel(t);
      case Grouping.week:
        final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1));
        final now = DateTime.now();
        final thisMonday = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1),
        );
        if (sameDay(monday, thisMonday)) return 'This week';
        if (sameDay(
          monday,
          DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7),
        )) {
          return 'Last week';
        }
        return 'Week of ${DateFormat('d MMMM').format(monday)}';
      case Grouping.month:
        return DateFormat('MMMM yyyy').format(t);
    }
  }

  Object? _cacheKey;
  List<Entry> _cachedShown = [];
  List<Object> _cachedRows = [];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final multiDay = grouping != Grouping.day;

    // Flattened rows so the list is built lazily: a header, then entries.
    // Rebuilt only when the entries, filter, grouping, search or day change.
    final key = (
      app.entries,
      filter,
      grouping,
      _search.text,
      dayLabel(DateTime.now()),
    );
    if (key != _cacheKey) {
      _cacheKey = key;
      _cachedShown = _shown(app.entries);
      _cachedRows = [];
      for (final (title, entries) in _group(_cachedShown)) {
        _cachedRows.add((title, entries));
        for (var i = 0; i < entries.length; i++) {
          _cachedRows.add((entries[i], i == 0, i == entries.length - 1));
        }
      }
    }
    final shown = _cachedShown;
    final rows = _cachedRows;

    return PullToSync(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        itemCount: rows.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _controls(context, shown);
          final row = rows[i - 1];
          if (row is (String, List<Entry>)) {
            return SectionTitle(row.$1, trailing: _summary(row.$2));
          }
          final (e, first, last) = row as (Entry, bool, bool);
          final radius = BorderRadius.vertical(
            top: first ? const Radius.circular(20) : Radius.zero,
            bottom: last ? const Radius.circular(20) : Radius.zero,
          );
          return Material(
            color: Baby.card,
            shape: RoundedRectangleBorder(borderRadius: radius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (!first) const Divider(indent: 70),
                Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline_rounded),
                  ),
                  onDismissed: (_) {
                    app.deleteEntry(e);
                    showUndo(context, 'Deleted', () => app.restoreEntry(e));
                  },
                  child: EntryTile(
                    entry: e,
                    showDay: multiDay,
                    onTap: () => editEntry(context, e),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summary(List<Entry> items) {
    if (grouping == Grouping.type) {
      return LText(
        '${items.length}',
        style: TextStyle(fontWeight: FontWeight.w800, color: Baby.muted),
      );
    }
    final feedMin = items.fold<int>(
      0,
      (sum, e) => sum + (e.type == EntryType.feed ? e.durationMin ?? 0 : 0),
    );
    return Counts(
      feeds: items.where((e) => e.type == EntryType.feed).length,
      pee: items
          .where((e) => e.type == EntryType.nappy && e.nappy != NappyKind.poo)
          .length,
      poo: items
          .where((e) => e.type == EntryType.nappy && e.nappy != NappyKind.pee)
          .length,
      extra: feedMin > 0 ? duration(Duration(minutes: feedMin)) : null,
    );
  }

  Widget _controls(BuildContext context, List<Entry> shown) {
    final searching = _search.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: LInputDecoration(
                  hintText: 'Search, e.g. poo, left, iron, monday',
                  prefixIcon: Icon(Icons.search_rounded, color: Baby.muted),
                  suffixIcon: searching
                      ? LIconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_search.clear),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: Baby.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: Baby.line),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Export and import',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => switch (v) {
                'csv' => exportCsvFile(context, shown),
                'backup' => exportBackupFile(context),
                _ => importBackupFile(context),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    leading: const Icon(Icons.table_view_rounded),
                    title: const LText('Export as spreadsheet'),
                    subtitle: LText('${shown.length} entries shown (CSV)'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'backup',
                  child: ListTile(
                    leading: Icon(Icons.save_alt_rounded),
                    title: LText('Export backup'),
                    subtitle: LText('Everything, to import later'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.upload_file_rounded),
                    title: LText('Import backup'),
                    subtitle: LText('Adds to what is here'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (type, label, glyph, color) in [
                (null, 'All', null, null),
                (EntryType.feed, 'Feeds', Glyphs.feed, Baby.feed),
                (EntryType.nappy, 'Nappies', Glyphs.nappy, Baby.nappy),
                (EntryType.pill, 'Pills', Glyphs.pill, Baby.pill),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: glyph?.call(18, color!),
                    label: LText(label),
                    selected: filter == type,
                    onSelected: (_) => setState(() => filter = type),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            LText(
              'Group by',
              style: TextStyle(fontWeight: FontWeight.w800, color: Baby.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final g in Grouping.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: LText(switch (g) {
                            Grouping.day => 'Day',
                            Grouping.week => 'Week',
                            Grouping.month => 'Month',
                            Grouping.type => 'Type',
                          }),
                          selected: grouping == g,
                          onSelected: (_) => setState(() => grouping = g),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 64),
            child: LText(
              searching
                  ? 'Nothing matches "${_search.text}"'
                  : 'Nothing logged yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            ),
          )
        else if (searching)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: LText(
              '${shown.length} found',
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../history_period.dart';
import 'common.dart';
import 'history_charts.dart';
import 'history_period_controls.dart';
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
  if (e.type == EntryType.sleep) 'sleep nap sleeping slaap slapie',
  _fullDate.format(e.time),
  _shortDate.format(e.time),
  hm(e.time),
].join(' ').toLowerCase();

/// History screen: two tabs with separate meanings, the activity log and the
/// charts. Both stay alive so filters survive switching.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  /// Switches back to the activity log (used when arriving from Today).
  void showLog() {
    if (_tabs.index != 0) _tabs.animateTo(0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Desktop.of(context);
    return Column(
      children: [
        Padding(
          padding: desktop
              ? const EdgeInsets.fromLTRB(24, 8, 24, 0)
              : const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TabBar(
            controller: _tabs,
            isScrollable: desktop,
            tabAlignment: desktop ? TabAlignment.start : null,
            labelColor: Baby.primary,
            unselectedLabelColor: Baby.muted,
            indicatorColor: Baby.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            dividerColor: desktop ? Baby.border : Baby.line,
            tabs: desktop
                ? const [
                    Tab(
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.list_alt_rounded, size: 18),
                          SizedBox(width: 8),
                          LText('Activity log', maxLines: 1),
                        ],
                      ),
                    ),
                    Tab(
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 18),
                          SizedBox(width: 8),
                          LText('Charts', maxLines: 1),
                        ],
                      ),
                    ),
                  ]
                : const [
                    Tab(
                      icon: Icon(Icons.list_alt_rounded),
                      child: LText('Activity log', maxLines: 1),
                    ),
                    Tab(
                      icon: Icon(Icons.bar_chart_rounded),
                      child: LText('Charts', maxLines: 1),
                    ),
                  ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [_ActivityLog(), _ChartsTab()],
          ),
        ),
      ],
    );
  }
}

class _ChartsTab extends StatefulWidget {
  const _ChartsTab();

  @override
  State<_ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<_ChartsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PullToSync(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Desktop.of(context)
            ? const EdgeInsets.fromLTRB(24, 16, 24, 32)
            : const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: const [HistoryCharts()],
      ),
    );
  }
}

class _ActivityLog extends StatefulWidget {
  const _ActivityLog();

  @override
  State<_ActivityLog> createState() => _ActivityLogState();
}

class _ActivityLogState extends State<_ActivityLog>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _search = TextEditingController();
  EntryType? filter;
  Grouping grouping = Grouping.day;
  HistoryPeriod period = HistoryPeriod.recent(DateTime.now(), 7);
  bool moreOptions = false;

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
        if (period.contains(e.time) &&
            (filter == null || e.type == filter) &&
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
          (EntryType.sleep, 'Sleep'),
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
    super.build(context);
    final app = AppScope.of(context);
    final multiDay = grouping != Grouping.day;

    // Flattened rows so the list is built lazily: a header, then entries.
    // Rebuilt only when the entries, filter, grouping, search or day change.
    final key = (
      app.entries,
      filter,
      grouping,
      period,
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

    final desktop = Desktop.of(context);
    final cardRadius = Radius.circular(desktop ? 12 : 20);
    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: desktop
          ? const EdgeInsets.fromLTRB(24, 8, 24, 32)
          : const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return desktop ? _found(context, shown) : _controls(context, shown);
        }
        final row = rows[i - 1];
        if (row is (String, List<Entry>)) {
          return SectionTitle(row.$1, trailing: _summary(row.$2));
        }
        final (e, first, last) = row as (Entry, bool, bool);
        final radius = BorderRadius.vertical(
          top: first ? cardRadius : Radius.zero,
          bottom: last ? cardRadius : Radius.zero,
        );
        return Material(
          color: Baby.card,
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (!first) Divider(indent: desktop ? 0 : 70),
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
    );
    if (!desktop) return PullToSync(child: list);
    // Desktop: filters in a panel beside the log.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('history-filters'),
          width: 340,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Baby.border)),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 20, 24),
            children: [_controls(context, shown, results: false)],
          ),
        ),
        Expanded(child: PullToSync(child: list)),
      ],
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

  bool get _hasFilters =>
      filter != null ||
      _search.text.isNotEmpty ||
      period.start != null ||
      period.hour != null;

  void _reset() => setState(() {
    filter = null;
    _search.clear();
    period = const HistoryPeriod();
  });

  /// The count of entries shown, or why there are none.
  Widget _found(BuildContext context, List<Entry> shown) {
    final searching = _search.text.isNotEmpty;
    final nothingLogged = AppScope.of(context).entries.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                IconBubble(
                  glyph: (size, color) => Icon(
                    nothingLogged
                        ? Icons.history_rounded
                        : Icons.search_off_rounded,
                    size: size,
                    color: color,
                  ),
                  color: Baby.pillSoft,
                  iconColor: Baby.primary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                LText(
                  nothingLogged
                      ? 'Nothing logged yet'
                      : searching
                      ? 'Nothing matches "${_search.text}"'
                      : 'No entries match these filters',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                LText(
                  nothingLogged
                      ? 'Feeds, nappies, sleep and pills you log on the Today screen will show up here.'
                      : 'Try another day, or show everything.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Baby.muted),
                ),
                if (!nothingLogged && _hasFilters) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _reset,
                    child: const LText('Show everything'),
                  ),
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LText(
              '${shown.length} found',
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _controls(
    BuildContext context,
    List<Entry> shown, {
    bool results = true,
  }) {
    final desktop = Desktop.of(context);
    final searching = _search.text.isNotEmpty;
    final extras =
        (period.hour != null ? 1 : 0) + (grouping != Grouping.day ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: LText('Everything that was logged, newest first'),
            ),
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
        const SizedBox(height: 8),
        _chipRow(desktop, [
          for (final (type, label, glyph, color) in [
            (null, 'All', null, null),
            (EntryType.feed, 'Feeds', Glyphs.feed, Baby.feed),
            (EntryType.nappy, 'Nappies', Glyphs.nappy, Baby.nappy),
            (EntryType.pill, 'Pills', Glyphs.pill, Baby.pill),
            (EntryType.sleep, 'Sleep', Glyphs.sleep, Baby.pill),
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
        ]),
        const SizedBox(height: 8),
        HistoryPeriodControls(
          period: period,
          allowAll: true,
          showHour: false,
          onChanged: (value) => setState(() => period = value),
        ),
        TextField(
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
            border: desktop
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: Baby.line),
                  ),
            enabledBorder: desktop
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: Baby.line),
                  ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => setState(() => moreOptions = !moreOptions),
            icon: Icon(
              moreOptions
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
            ),
            label: LText.raw(
              extras > 0
                  ? '${tr('More options')} ($extras)'
                  : tr('More options'),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !moreOptions
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HistoryHourPicker(
                      period: period,
                      onChanged: (value) => setState(() => period = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        LText(
                          'Group by',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Baby.muted,
                          ),
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
                                      onSelected: (_) =>
                                          setState(() => grouping = g),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        if (results) _found(context, shown),
      ],
    );
  }

  /// Chips side by side: scrolling sideways on the phone, wrapping on desktop.
  Widget _chipRow(bool desktop, List<Widget> chips) => desktop
      ? Wrap(runSpacing: 8, children: chips)
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: chips),
        );
}

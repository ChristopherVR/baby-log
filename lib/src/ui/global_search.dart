import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../growth.dart';
import '../models.dart';
import '../routines.dart';
import '../search.dart';
import '../store.dart';
import 'common.dart';
import 'growth_page.dart';
import 'hub_page.dart';
import 'pills_page.dart';
import 'routine_history.dart';
import 'routines_page.dart';
import 'settings_page.dart';
import 'sheets.dart';
import 'theme.dart';

/// Tabs of the main screen, in order.
abstract final class ShellTabs {
  static const today = 0;
  static const history = 1;
  static const pills = 2;
  static const routines = 3;
  static const growth = 4;
  static const labels = ['Today', 'History', 'Pills', 'Routines', 'Growth'];
}

// ------------------------------------------------------------------ index

String _number(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _englishSide(FeedSide s) => switch (s) {
  FeedSide.left => 'Left',
  FeedSide.right => 'Right',
  FeedSide.both => 'Both',
  FeedSide.bottle => 'Bottle',
};

String _englishNappy(NappyKind k) => switch (k) {
  NappyKind.pee => 'Pee',
  NappyKind.poo => 'Poo',
  NappyKind.both => 'Pee + Poo',
};

/// Everything the global search can find, labelled in the app's language and
/// findable in English and Afrikaans.
List<SearchItem> buildSearchIndex(AppState app, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final longDate = DateFormat('EEEE d MMMM yyyy');
  final shortDate = DateFormat('d/M/yyyy');
  List<String> words(List<String> english) => [
    for (final w in english) ...bothLanguages(w),
  ];
  List<String> dates(DateTime t) => [
    longDate.format(t),
    shortDate.format(t),
    if (sameDay(t, today)) ...bothLanguages('Today'),
    if (sameDay(t, yesterday)) ...bothLanguages('Yesterday'),
  ];
  SearchItem action(String id, String title, List<String> terms) => SearchItem(
    kind: SearchKind.action,
    id: id,
    title: tr(title),
    terms: [title, ...words(terms)],
  );

  final nap = app.activeSleep;
  return [
    // Quick actions.
    action('log-feed', 'Log a feed', ['Feed', 'Breast', 'Bottle', 'Save']),
    if (app.timerStart == null)
      action('feed-timer', 'Start feed timer', ['Feed', 'Timer']),
    action('log-nappy', 'Log a nappy', ['Nappy', 'Pee', 'Poo', 'diaper']),
    if (nap == null)
      action('nap', 'Start a nap', ['Sleep', 'Nap', 'Put down for a nap'])
    else
      action('nap', 'End nap', ['Sleep', 'Nap', 'Sleeping']),
    if (app.meds.isNotEmpty)
      action('take-pill', 'Take a pill', ['Pill', 'Taken now', 'medicine']),
    action('add-pill', 'Add a pill', ['Pill', 'Add pill', 'medicine']),
    action('add-routine', 'Add routine', ['Routine', 'Bath time', 'Bedtime']),
    action('add-growth', 'Add a growth entry', [
      'Growth',
      'Weight',
      'Height',
      'Photo',
      'Journal',
    ]),
    action('feed-reminder', 'Feed reminder', ['Reminder', 'Alarm']),
    action('edit-profile', 'Edit profile', ['Baby', 'Birthday', 'Photo']),
    action('share', 'Family hub', ['Share', 'Sync', 'Add a device', 'Pair']),
    action('routine-history', 'Routine history', ['Routine', 'History']),

    // Pages.
    for (var i = 0; i < ShellTabs.labels.length; i++)
      SearchItem(
        kind: SearchKind.page,
        id: 'tab:$i',
        title: tr(ShellTabs.labels[i]),
        terms: words([ShellTabs.labels[i]]),
      ),
    SearchItem(
      kind: SearchKind.page,
      id: 'settings',
      title: tr('Settings'),
      terms: words(['Settings']),
    ),

    // Babies.
    for (final b in app.babies)
      SearchItem(
        kind: SearchKind.baby,
        id: b.id,
        title: b.name.isEmpty ? tr('Baby') : b.name,
        subtitle: [
          if (b.id == app.activeBabyId) tr('Selected'),
          if (b.dateOfBirth != null)
            DateFormat('d MMMM yyyy').format(b.dateOfBirth!),
        ].join(' · '),
        terms: words(['Baby', 'Babies', 'Birthday']),
        data: b,
      ),

    // Pills.
    for (final m in app.meds)
      SearchItem(
        kind: SearchKind.pill,
        id: m.id,
        title: m.name,
        subtitle: tr(
          [if (m.dose.isNotEmpty) m.dose, m.scheduleLabel].join(' · '),
        ),
        terms: [
          m.scheduleLabel,
          ...m.slots.map(minutesOfDay),
          ...words(['Pill', 'Pills', 'medicine']),
        ],
        data: m,
      ),

    // Routines.
    for (final r in app.routines)
      SearchItem(
        kind: SearchKind.routine,
        id: r.id,
        title: r.name,
        subtitle: '${minutesOfDay(r.minutes)} · ${repeatLabel(r)}',
        terms: [
          r.notes,
          if (!r.enabled) ...words(['Routine paused']),
          ...words(['Routine', 'Routines']),
        ],
        data: r,
      ),

    // Growth journal.
    for (final g in app.growthEntries) _growthItem(g, dates, words),

    // Log: entries and routine completions.
    for (final e in app.entries) _entryItem(app, e, dates, words),
    for (final c in app.routineHistory())
      SearchItem(
        kind: SearchKind.entry,
        id: 'routine:${c.id}',
        title: c.routineName,
        subtitle: completionLabel(c),
        terms: [
          ...words(['Routine', 'Done']),
          ...dates(c.time),
        ],
        date: c.time,
        data: c,
      ),

    // Devices in the family hub.
    for (final p in app.peers)
      SearchItem(
        kind: SearchKind.setting,
        id: 'peer:${p.deviceId}',
        title: p.name.isEmpty ? p.host : p.name,
        subtitle: '${tr('Family hub')} · ${tr('Sync details')}',
        terms: [
          p.host,
          ...words(['Device', 'Sync', 'Family hub']),
        ],
        date: p.lastSync,
        data: p,
      ),

    // Settings.
    for (final s in settingTopics)
      SearchItem(
        kind: SearchKind.setting,
        id: s.title,
        title: tr(s.title),
        subtitle: tr(s.section),
        terms: words([s.title, s.section, ...s.terms]),
        data: s,
      ),
  ];
}

SearchItem _growthItem(
  GrowthEntry g,
  List<String> Function(DateTime) dates,
  List<String> Function(List<String>) words,
) {
  final measured = [
    if (g.weightKg != null) '${_number(g.weightKg!)} kg',
    if (g.heightCm != null) '${_number(g.heightCm!)} cm',
  ].join(' · ');
  final note = g.note.trim().split('\n').first;
  return SearchItem(
    kind: SearchKind.growth,
    id: g.id,
    title: measured.isNotEmpty
        ? measured
        : note.isNotEmpty
        ? note
        : tr(g.photo != null ? 'Photo' : 'Growth'),
    subtitle: measured.isNotEmpty && note.isNotEmpty ? note : null,
    terms: [
      g.note,
      ...dates(g.date),
      ...words([
        'Growth',
        'Journal',
        if (g.weightKg != null) 'Weight',
        if (g.heightCm != null) 'Height',
        if (g.photo != null) 'Photo',
      ]),
    ],
    date: g.date,
    data: g,
  );
}

SearchItem _entryItem(
  AppState app,
  Entry e,
  List<String> Function(DateTime) dates,
  List<String> Function(List<String>) words,
) {
  final elsewhere = app.loggedElsewhere(e);
  final english = <String>[
    switch (e.type) {
      EntryType.feed => 'Feed',
      EntryType.nappy => 'Nappy',
      EntryType.pill => 'Pill',
      EntryType.sleep => 'Sleep',
    },
    if (e.side != null) ...[
      _englishSide(e.side!),
      if (e.side == FeedSide.bottle) 'Bottle feed',
    ],
    if (e.type == EntryType.feed && e.side != FeedSide.bottle) 'Breast',
    if (e.nappy != null) _englishNappy(e.nappy!),
    if (e.type == EntryType.sleep) ...['Nap', 'Sleeping'],
  ];
  return SearchItem(
    kind: SearchKind.entry,
    id: e.id,
    title: tr(entryTitle(e)),
    subtitle: [
      if (entryDetail(e) case final detail?) tr(detail),
      if (elsewhere != null) tr('by $elsewhere'),
    ].join(' · '),
    terms: [
      ...words(english),
      // Everyday words that are not labels in the app.
      ...switch (e.type) {
        EntryType.feed => ['bors', 'voeding', 'bottel'],
        EntryType.nappy => [
          'doek',
          'diaper',
          if (e.nappy != NappyKind.poo) ...['wet', 'nat', 'piepie'],
          if (e.nappy != NappyKind.pee) ...['dirty', 'vuil', 'poef'],
        ],
        EntryType.pill => ['medicine', 'medisyne', 'pil'],
        EntryType.sleep => ['slaap', 'slapie'],
      },
      ?e.medName,
      ?e.by,
      hm(e.time),
      ...dates(e.time),
    ],
    date: e.time,
    data: e,
  );
}

// ------------------------------------------------------------------ opening

/// Opens Settings with [query] already typed into its search box.
void openSettingsSearch(BuildContext context, String query) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => SettingsPage(initialQuery: query)),
);

/// Does what a search result stands for: switches tab with [goToTab] and
/// opens the record's editor, or runs the action.
void openSearchItem(
  BuildContext context,
  SearchItem item,
  void Function(int tab) goToTab,
) {
  final app = AppScope.of(context);
  final data = item.data;
  switch (item.kind) {
    case SearchKind.action:
      switch (item.id) {
        case 'log-feed':
          goToTab(ShellTabs.today);
          showSheet(context, const FeedSheet());
        case 'feed-timer':
          goToTab(ShellTabs.today);
          app.startFeedTimer(app.suggestedSide ?? FeedSide.left);
        case 'log-nappy':
          goToTab(ShellTabs.today);
          showSheet(context, const NappySheet());
        case 'nap':
          goToTab(ShellTabs.today);
          final nap = app.activeSleep;
          if (nap == null) {
            showSheet(context, const SleepSheet());
          } else {
            app.endSleep(nap);
          }
        case 'take-pill':
          showSheet(
            context,
            app.meds.isEmpty ? const MedEditor() : const TakePillSheet(),
          );
        case 'add-pill':
          goToTab(ShellTabs.pills);
          showSheet(context, const MedEditor());
        case 'add-routine':
          goToTab(ShellTabs.routines);
          editRoutine(context);
        case 'add-growth':
          goToTab(ShellTabs.growth);
          showSheet(context, GrowthEditor(baby: app.activeBaby));
        case 'feed-reminder':
          showFeedReminderSheet(context);
        case 'edit-profile':
          editBabyProfile(context);
        case 'share':
          openHub(context);
        case 'routine-history':
          openRoutineHistory(context);
      }
    case SearchKind.page:
      if (item.id == 'settings') {
        openSettings(context);
      } else {
        goToTab(int.parse(item.id.substring(4)));
      }
    case SearchKind.baby:
      if (data is BabyProfile && !app.selectBaby(data.id)) {
        showMessage(
          context,
          'Save or stop the feed timer before switching babies.',
        );
        return;
      }
      goToTab(ShellTabs.today);
    case SearchKind.pill:
      goToTab(ShellTabs.pills);
      if (data is Medication) showSheet(context, MedEditor(initial: data));
    case SearchKind.routine:
      goToTab(ShellTabs.routines);
      if (data is Routine) editRoutine(context, initial: data);
    case SearchKind.growth:
      goToTab(ShellTabs.growth);
      if (data is GrowthEntry) {
        showSheet(context, GrowthEditor(baby: app.activeBaby, initial: data));
      }
    case SearchKind.entry:
      if (data is Entry) {
        goToTab(ShellTabs.history);
        editEntry(context, data);
      } else if (data is RoutineCompletion) {
        openRoutineHistory(
          context,
          routineId: data.routineId,
          routineName: data.routineName,
        );
      }
    case SearchKind.setting:
      if (data is Peer) {
        openHub(context);
      } else {
        openSettingsSearch(context, item.title);
      }
  }
}

/// Opens the global search: a command palette on desktop, a full screen
/// search on the phone. Returns the chosen item, already closed.
Future<SearchItem?> showGlobalSearch(BuildContext context) {
  if (Desktop.of(context)) {
    return showDialog<SearchItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: Baby.dark ? 0.55 : 0.3),
      builder: (_) => const _Palette(),
    );
  }
  return Navigator.push<SearchItem>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const GlobalSearchPage(),
    ),
  );
}

class _Palette extends StatelessWidget {
  const _Palette();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: math.min(96, size.height * 0.1)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: math.max(260, math.min(600, size.height * 0.8 - 40)),
          ),
          child: Material(
            color: Baby.card,
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesktopTokens.radiusLg),
              side: BorderSide(color: Baby.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: const GlobalSearchView(palette: true),
          ),
        ),
      ),
    );
  }
}

/// Full screen search on the phone.
class GlobalSearchPage extends StatelessWidget {
  const GlobalSearchPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SafeArea(child: GlobalSearchView(palette: false)));
}

/// Search field and grouped results; pops the chosen [SearchItem].
class GlobalSearchView extends StatefulWidget {
  const GlobalSearchView({super.key, required this.palette, this.now});

  /// Desktop command palette (true) or phone page (false).
  final bool palette;
  final DateTime? now;

  @override
  State<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends State<GlobalSearchView> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _selectedKey = GlobalKey();
  List<SearchItem> _items = const [];
  List<SearchGroup> _groups = const [];
  List<SearchHit> _flat = const [];
  int _selected = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _items = buildSearchIndex(AppScope.of(context), now: widget.now);
    _run();
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _run() {
    _groups = search(_items, _query.text, now: widget.now);
    _flat = [for (final g in _groups) ...g.hits];
    _selected = _flat.isEmpty ? -1 : 0;
  }

  void _move(int by) {
    if (_flat.isEmpty) return;
    setState(() => _selected = (_selected + by) % _flat.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _selectedKey.currentContext;
      if (row != null && row.mounted) {
        Scrollable.ensureVisible(
          row,
          duration: const Duration(milliseconds: 80),
          alignmentPolicy: by > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  void _choose([SearchHit? hit]) {
    final chosen =
        hit ??
        (_selected >= 0 && _selected < _flat.length ? _flat[_selected] : null);
    if (chosen != null) Navigator.pop(context, chosen.item);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: const ValueKey('global-search-field'),
      controller: _query,
      focusNode: _focus,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: tr('Search feeds, pills, routines, settings…'),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onChanged: (_) => setState(_run),
      onSubmitted: (_) => _choose(),
    );
    final header = Padding(
      padding: EdgeInsets.fromLTRB(widget.palette ? 16 : 4, 0, 8, 0),
      child: Row(
        children: [
          if (widget.palette)
            Icon(Icons.search_rounded, color: Baby.muted, size: 20)
          else
            LIconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(width: 10),
          Expanded(child: field),
          if (_query.text.isNotEmpty)
            LIconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() {
                _query.clear();
                _run();
                _focus.requestFocus();
              }),
            )
          else if (widget.palette)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Kbd('Esc'),
            ),
        ],
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.tab): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
            _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): _choose,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _choose,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Column(
        mainAxisSize: widget.palette ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Divider(height: 1, color: Baby.border),
          Flexible(
            fit: widget.palette ? FlexFit.loose : FlexFit.tight,
            child: _results(),
          ),
          if (widget.palette) ...[
            Divider(height: 1, color: Baby.border),
            _footer(),
          ],
        ],
      ),
    );
  }

  Widget _results() {
    if (_flat.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 32, color: Baby.muted),
            const SizedBox(height: 8),
            LText(
              'No results for “${_query.text.trim()}”',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            LText(
              'Try another word, a date or a name.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Baby.muted),
            ),
          ],
        ),
      );
    }
    var index = 0;
    final children = <Widget>[];
    for (final g in _groups) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: LText(
                  _query.text.trim().isEmpty && g.kind == SearchKind.entry
                      ? 'Recent'
                      : g.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Baby.muted,
                  ),
                ),
              ),
              if (g.total > g.hits.length)
                LText(
                  '${g.hits.length} of ${g.total}',
                  style: TextStyle(fontSize: 12, color: Baby.muted),
                ),
            ],
          ),
        ),
      );
      for (final hit in g.hits) {
        final i = index++;
        children.add(
          _ResultRow(
            key: i == _selected ? _selectedKey : null,
            hit: hit,
            selected: i == _selected,
            onHover: () {
              if (_selected != i) setState(() => _selected = i);
            },
            onTap: () => _choose(hit),
          ),
        );
      }
    }
    return Scrollbar(
      controller: _scroll,
      child: ListView(
        controller: _scroll,
        shrinkWrap: widget.palette,
        padding: const EdgeInsets.only(bottom: 8),
        children: children,
      ),
    );
  }

  Widget _footer() {
    Widget hint(String key, String label) => Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Kbd(key),
          const SizedBox(width: 6),
          LText(label, style: TextStyle(fontSize: 12, color: Baby.muted)),
        ],
      ),
    );
    return Container(
      color: Baby.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        runSpacing: 4,
        children: [
          hint('↑ ↓', 'Navigate'),
          hint('Enter', 'Open'),
          hint('Esc', 'Close'),
        ],
      ),
    );
  }
}

/// [text] with the matched [ranges] highlighted.
Widget highlightedText(
  String text,
  List<MatchRange> ranges,
  TextStyle style, {
  int maxLines = 1,
}) {
  final spans = <TextSpan>[];
  var at = 0;
  for (final r in ranges) {
    if (r.start < at || r.end > text.length) continue;
    if (r.start > at) spans.add(TextSpan(text: text.substring(at, r.start)));
    spans.add(
      TextSpan(
        text: text.substring(r.start, r.end),
        style: TextStyle(
          backgroundColor: Baby.highlight,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    at = r.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return Text.rich(
    TextSpan(style: style, children: spans),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.hit,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });
  final SearchHit hit;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  static const _actionIcons = {
    'log-feed': Icons.add_rounded,
    'feed-timer': Icons.timer_outlined,
    'log-nappy': Icons.add_rounded,
    'nap': Icons.bedtime_outlined,
    'take-pill': Icons.check_rounded,
    'add-pill': Icons.add_rounded,
    'add-routine': Icons.add_rounded,
    'add-growth': Icons.add_rounded,
    'feed-reminder': Icons.alarm_rounded,
    'edit-profile': Icons.edit_outlined,
    'share': Icons.people_alt_rounded,
    'routine-history': Icons.history_rounded,
  };

  static List<IconData> get _pageIcons => [
    Icons.home_outlined,
    Icons.history_rounded,
    Glyphs.pillOutlinedIcon,
    Icons.event_repeat_rounded,
    Icons.photo_album_outlined,
  ];

  Widget _leading() {
    Widget icon(IconData data, Color soft, Color strong) => IconBubble(
      glyph: (size, color) => Icon(data, size: size, color: color),
      color: soft,
      iconColor: strong,
      size: 32,
    );
    final item = hit.item;
    final data = item.data;
    return switch (item.kind) {
      SearchKind.entry when data is Entry => Builder(
        builder: (context) {
          final look = lookOf(data);
          return IconBubble(
            glyph: look.glyph,
            color: look.soft,
            iconColor: look.strong,
            size: 32,
          );
        },
      ),
      SearchKind.entry => icon(
        Icons.check_circle_outline_rounded,
        Baby.nappySoft,
        Baby.ok,
      ),
      SearchKind.action => icon(
        _actionIcons[item.id] ?? Icons.bolt_rounded,
        Baby.hover,
        Baby.ink,
      ),
      SearchKind.page => icon(
        item.id == 'settings'
            ? Icons.settings_outlined
            : _pageIcons[int.parse(item.id.substring(4))],
        Baby.hover,
        Baby.ink,
      ),
      SearchKind.baby => IconBubble(
        glyph: Glyphs.baby,
        color: Baby.feedSoft,
        iconColor: Baby.feed,
        size: 32,
      ),
      SearchKind.pill => IconBubble(
        glyph: Glyphs.pill,
        color: Baby.pillSoft,
        iconColor: Baby.pill,
        size: 32,
      ),
      SearchKind.routine => icon(
        Icons.event_repeat_rounded,
        Baby.primarySoft,
        Baby.primary,
      ),
      SearchKind.growth => icon(
        Icons.straighten_rounded,
        Baby.nappySoft,
        Baby.nappy,
      ),
      SearchKind.setting => icon(Icons.tune_rounded, Baby.hover, Baby.muted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = hit.item;
    final date = item.date;
    final trailing = date == null
        ? null
        : item.kind == SearchKind.growth
        ? DateFormat('d MMM yyyy').format(date)
        : sameDay(date, DateTime.now())
        ? hm(date)
        : DateFormat(
            date.year == DateTime.now().year ? 'd MMM, HH:mm' : 'd MMM yyyy',
          ).format(date);
    return MouseRegion(
      onHover: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Baby.hover : null,
            borderRadius: BorderRadius.circular(DesktopTokens.radius),
          ),
          child: Row(
            children: [
              _leading(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    highlightedText(
                      item.title,
                      hit.titleRanges,
                      TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Baby.ink,
                      ),
                    ),
                    if (item.subtitle?.isNotEmpty ?? false)
                      highlightedText(
                        item.subtitle!,
                        hit.subtitleRanges,
                        TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Baby.muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                LText.raw(
                  trailing,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Baby.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_return_rounded,
                  size: 16,
                  color: Baby.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

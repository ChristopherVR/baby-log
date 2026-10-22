import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'pills_page.dart';
import 'routines_page.dart';
import 'settings_page.dart';
import 'sheets.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onSeeHistory,
    required this.onSeeRoutines,
  });
  final VoidCallback onSeeHistory;
  final VoidCallback onSeeRoutines;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _tick;
  Duration? _every;
  late bool _visible = !AppScope.of(context).startedHeadless;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onShow: () => setState(() => _visible = true),
      onHide: () {
        _visible = false;
        _setTick(null);
      },
    );
  }

  /// Keeps "x min ago" current: every 30 seconds while the app is on screen
  /// (the feed timer card ticks every second by itself).
  void _setTick(Duration? every) {
    if (every == _every) return;
    _tick?.cancel();
    _every = every;
    _tick = every == null
        ? null
        : Timer.periodic(every, (_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    _setTick(_visible ? const Duration(seconds: 30) : null);
    final today = app.entriesOn(DateTime.now());

    final overview = <Widget>[
      if (app.timerStart != null) ...[
        _TimerCard(app: app),
        const SizedBox(height: 16),
      ],
      _LastFeedCard(app: app),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ActionTile(
              glyph: Glyphs.feed,
              label: 'Feed',
              hint: app.suggestedSide != null
                  ? 'Next: ${sideLabel(app.suggestedSide!)}'
                  : 'Log a feed',
              soft: Baby.feedSoft,
              strong: Baby.feed,
              onTap: () => showSheet(context, const FeedSheet()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ActionTile(
              glyph: Glyphs.nappy,
              label: 'Nappy',
              hint: app.lastNappy == null
                  ? 'Pee or poo'
                  : ago(app.lastNappy!.time),
              soft: Baby.nappySoft,
              strong: Baby.nappy,
              onTap: () => showSheet(context, const NappySheet()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ActionTile(
              glyph: Glyphs.pill,
              label: 'Pill',
              hint: _pillHint(app),
              soft: Baby.pillSoft,
              strong: Baby.pill,
              onTap: () => _pillTap(context, app),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _LastNappyCard(app: app),
      const SizedBox(height: 16),
      Card(
        color: Baby.pillSoft,
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth <
                360 * MediaQuery.textScalerOf(context).scale(1);
            final action = FilledButton(
              onPressed: () {
                final nap = app.activeSleep;
                if (nap == null) {
                  showSheet(context, const SleepSheet());
                } else {
                  app.endSleep(nap);
                }
              },
              child: LText(app.activeSleep == null ? 'Start nap' : 'End nap'),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Glyphs.sleep(28, Baby.pill),
                  title: LText(app.activeSleep == null ? 'Sleep' : 'Sleeping'),
                  subtitle: LText(
                    app.activeSleep == null
                        ? 'Put down for a nap'
                        : '${hm(app.activeSleep!.time)} · ${duration(DateTime.now().difference(app.activeSleep!.time))}',
                  ),
                  trailing: stacked ? null : action,
                ),
                if (stacked)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: action,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      RoutinePreview(onOpen: widget.onSeeRoutines),
      const SizedBox(height: 16),
      _ReminderRow(app: app),
    ];
    final activity = <Widget>[
      SectionTitle(
        'Today',
        trailing: Counts(
          feeds: today.where((e) => e.type == EntryType.feed).length,
          pee: today
              .where(
                (e) => e.type == EntryType.nappy && e.nappy != NappyKind.poo,
              )
              .length,
          poo: today
              .where(
                (e) => e.type == EntryType.nappy && e.nappy != NappyKind.pee,
              )
              .length,
        ),
      ),
      if (today.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: LText(
              'Nothing logged yet today.\nTap Feed, Nappy or Pill above to start.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            ),
          ),
        )
      else
        ListCard(
          children: [
            for (final e in today.take(8))
              EntryTile(entry: e, onTap: () => editEntry(context, e)),
          ],
        ),
      Align(
        child: TextButton.icon(
          onPressed: widget.onSeeHistory,
          icon: const Icon(Icons.history_rounded),
          label: const LText('See all history'),
        ),
      ),
    ];
    if (Desktop.of(context)) {
      return _desktop(context, app, today, activity);
    }
    return LayoutBuilder(
      builder: (context, constraints) => PullToSync(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
              child: LText(
                '${greeting()} · ${DateFormat('EEEE d MMMM').format(DateTime.now())}',
                style: TextStyle(
                  color: Baby.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (constraints.maxWidth >= 900)
              Row(
                key: const ValueKey('today-columns'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: overview,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: activity,
                    ),
                  ),
                ],
              )
            else ...[
              ...overview,
              ...activity,
            ],
          ],
        ),
      ),
    );
  }

  void _napTap(BuildContext context, AppState app) {
    final nap = app.activeSleep;
    if (nap == null) {
      showSheet(context, const SleepSheet());
    } else {
      app.endSleep(nap);
    }
  }

  /// Desktop: status cards and quick actions in grids, then today's log
  /// beside the routines and reminder.
  Widget _desktop(
    BuildContext context,
    AppState app,
    List<Entry> today,
    List<Widget> activity,
  ) {
    final nap = app.activeSleep;
    final next = app.meds.isEmpty
        ? null
        : app.meds
              .map((m) => (m, app.nextDose(m)))
              .reduce((a, b) => a.$2.isBefore(b.$2) ? a : b);
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final columns = constraints.maxWidth >= 980 ? 4 : 2;
        Widget grid(List<Widget> cells) => Column(
          children: [
            for (var i = 0; i < cells.length; i += columns) ...[
              if (i > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(
                        child: j < cells.length
                            ? cells[j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
        final stats = [
          _LastFeedCard(app: app),
          _LastNappyCard(app: app),
          _StatCard(
            title: nap == null ? 'SLEEP' : 'SLEEPING',
            value: nap == null ? 'Awake' : _agoShort(nap.time),
            detail: nap == null
                ? 'Put down for a nap'
                : 'Since ${hm(nap.time)}',
            color: Baby.pill,
            soft: Baby.pillSoft,
            glyph: Glyphs.sleep,
            onTap: () => _napTap(context, app),
          ),
          _StatCard(
            title: 'NEXT PILL',
            value: next == null
                ? 'None'
                : next.$2.isBefore(now)
                ? 'Due now'
                : hm(next.$2),
            detail: next == null ? 'Add pills' : next.$1.name,
            color: Baby.pill,
            soft: Baby.pillSoft,
            glyph: Glyphs.pill,
            onTap: () => _pillTap(context, app),
          ),
        ];
        final actions = [
          ActionTile(
            glyph: Glyphs.feed,
            label: 'Feed',
            hint: app.suggestedSide != null
                ? 'Next: ${sideLabel(app.suggestedSide!)}'
                : 'Log a feed',
            soft: Baby.feedSoft,
            strong: Baby.feed,
            onTap: () => showSheet(context, const FeedSheet()),
          ),
          ActionTile(
            glyph: Glyphs.nappy,
            label: 'Nappy',
            hint: 'Pee or poo',
            soft: Baby.nappySoft,
            strong: Baby.nappy,
            onTap: () => showSheet(context, const NappySheet()),
          ),
          ActionTile(
            glyph: Glyphs.pill,
            label: 'Pill',
            hint: _pillHint(app),
            soft: Baby.pillSoft,
            strong: Baby.pill,
            onTap: () => _pillTap(context, app),
          ),
          ActionTile(
            glyph: Glyphs.sleep,
            label: nap == null ? 'Start nap' : 'End nap',
            hint: nap == null
                ? 'Put down for a nap'
                : 'Sleeping · ${duration(now.difference(nap.time))}',
            soft: Baby.pillSoft,
            strong: Baby.pill,
            onTap: () => _napTap(context, app),
          ),
        ];
        final side = <Widget>[
          RoutinePreview(onOpen: widget.onSeeRoutines),
          const SizedBox(height: 12),
          _ReminderRow(app: app),
        ];
        return PullToSync(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              if (app.timerStart != null) ...[
                _TimerCard(app: app),
                const SizedBox(height: 16),
              ],
              grid(stats),
              const SizedBox(height: 12),
              grid(actions),
              if (wide)
                Row(
                  key: const ValueKey('today-columns'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: activity,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SectionTitle('Plan'), ...side],
                      ),
                    ),
                  ],
                )
              else ...[
                ...activity,
                const SizedBox(height: 8),
                ...side,
              ],
            ],
          ),
        );
      },
    );
  }

  String _pillHint(AppState app) {
    if (app.meds.isEmpty) return 'Add pills';
    final next = app.meds
        .map(app.nextDose)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return next.isBefore(DateTime.now()) ? 'Due now' : 'Next ${hm(next)}';
  }

  void _pillTap(BuildContext context, AppState app) => showSheet(
    context,
    app.meds.isEmpty ? const MedEditor() : const TakePillSheet(),
  );
}

class _TimerCard extends StatefulWidget {
  const _TimerCard({required this.app});
  final AppState app;

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final elapsed = app.feedElapsed();
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Card(
      color: Baby.feedSoft,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LText(
              app.timerPaused
                  ? 'A little burping break'
                  : 'Feeding since ${hm(app.timerStart!)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: Baby.feed),
            ),
            LText(
              '$mm:$ss',
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            LText(
              app.timerPaused
                  ? 'Timer paused · take your time'
                  : 'Active feeding time',
              style: TextStyle(color: Baby.feed),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final s in const [
                  FeedSide.left,
                  FeedSide.right,
                  FeedSide.both,
                ]) ...[
                  Expanded(
                    child: OptionTile(
                      label: sideLabel(s),
                      selected: app.timerSide == s,
                      color: Baby.card,
                      onTap: () => app.switchTimerSide(s),
                    ),
                  ),
                  if (s != FeedSide.both) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => app.timerPaused
                  ? app.resumeFeedTimer()
                  : app.pauseFeedTimer(),
              icon: Icon(
                app.timerPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              label: LText(
                app.timerPaused ? 'Resume feeding' : 'Pause to burp',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const LText('Every 5 minutes'),
              subtitle: const LText('Remind me during active feeding'),
              value: app.timerReminders,
              onChanged: app.setTimerReminders,
            ),
            ValueListenableBuilder<String?>(
              valueListenable: app.reminders.timerProblem,
              builder: (_, problem, _) => problem == null
                  ? const SizedBox.shrink()
                  : LText(problem, style: TextStyle(color: Baby.error)),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final discard = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const LText('Discard this feed?'),
                        content: const LText(
                          'The timer will stop without saving a feed.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const LText('Keep feeding'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const LText('Discard'),
                          ),
                        ],
                      ),
                    );
                    if (discard == true) app.stopFeedTimer(save: false);
                  },
                  child: const LText('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Baby.feed,
                    foregroundColor: Baby.onPrimary,
                  ),
                  icon: const Icon(Icons.stop_rounded),
                  label: const LText('Stop & save'),
                  onPressed: () => app.stopFeedTimer(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
    required this.soft,
    this.glyph,
    this.hero = false,
    this.onTap,
  });
  final String title;
  final String value;
  final String detail;
  final Color color;
  final Color soft;
  final Glyph? glyph;
  final bool hero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      Desktop.of(context) ? _desktop(context) : _phone(context);

  /// Neutral bordered card; the kind's colour is the accent.
  Widget _desktop(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Baby.muted,
                      letterSpacing: 0.4,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                if (glyph != null)
                  IconBubble(
                    glyph: glyph!,
                    color: soft,
                    iconColor: color,
                    size: 30,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: hero ? 30 : 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: hero ? color : Baby.ink,
              ),
            ),
            const SizedBox(height: 4),
            LText(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: Baby.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _phone(BuildContext context) => Card(
    color: soft,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, hero ? 20 : 16, 20, hero ? 20 : 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.4,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    child: Align(
                      key: ValueKey(value),
                      alignment: Alignment.centerLeft,
                      child: LText(
                        value,
                        style: TextStyle(
                          fontSize: hero ? 44 : 26,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  LText(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Baby.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (glyph != null) ...[
              const SizedBox(width: 12),
              IconBubble(
                glyph: glyph!,
                color: Baby.card,
                iconColor: color,
                size: hero ? 56 : 48,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _agoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  return d.inMinutes < 1 ? 'Just now' : duration(d);
}

class _LastFeedCard extends StatelessWidget {
  const _LastFeedCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final last = app.lastFeed;
    return _StatCard(
      title: 'SINCE LAST FEED',
      color: Baby.feed,
      soft: Baby.feedSoft,
      hero: true,
      glyph: last?.side == FeedSide.bottle ? Glyphs.bottle : Glyphs.feed,
      value: last == null ? 'Not yet' : _agoShort(last.time),
      detail: last == null
          ? 'No feeds logged'
          : [
              last.side == null ? 'Breast' : sideLabel(last.side!),
              hm(last.time),
              ?entryDetail(last),
            ].join(' · '),
      onTap: last == null ? null : () => editEntry(context, last),
    );
  }
}

class _LastNappyCard extends StatelessWidget {
  const _LastNappyCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final last = app.lastNappy;
    return _StatCard(
      title: 'SINCE LAST NAPPY',
      color: Baby.nappy,
      soft: Baby.nappySoft,
      glyph: Glyphs.nappy,
      value: last == null ? 'Not yet' : _agoShort(last.time),
      detail: last == null
          ? 'No nappies logged'
          : '${nappyLabel(last.nappy ?? NappyKind.pee)} · ${hm(last.time)}',
      onTap: last == null ? null : () => editEntry(context, last),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final at = app.feedReminderAt;
    final String text;
    if (!app.feedReminderOn) {
      text = 'Feed reminder is off. Tap to set one';
    } else if (at == null) {
      text =
          'Feed reminder: ${feedIntervalLabel(app.feedReminderMinutes)} after each feed';
    } else if (at.isAfter(DateTime.now())) {
      text = 'Next feed reminder at ${hm(at)}';
    } else {
      text = 'Feed was due at ${hm(at)}';
    }
    final desktop = Desktop.of(context);
    final radius = BorderRadius.circular(desktop ? DesktopTokens.radiusLg : 24);
    return Material(
      color: Baby.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: desktop ? BorderSide(color: Baby.border) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: () => showFeedReminderSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(
                app.feedReminderOn
                    ? Icons.alarm_on_rounded
                    : Icons.alarm_off_rounded,
                color: app.feedReminderOn ? Baby.feed : Baby.muted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LText(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Baby.muted),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'baby_photo.dart';
import 'common.dart';
import 'growth_page.dart';
import 'hub_page.dart';
import 'pills_page.dart';
import 'pump_page.dart';
import 'routines_page.dart';
import 'settings_page.dart';
import 'setup/motion.dart';
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

    final nap = app.activeSleep;
    final overview = <Widget>[
      _BabyHero(app: app),
      const SizedBox(height: 14),
      if (app.timerStart != null) ...[
        _TimerCard(app: app),
        const SizedBox(height: 14),
      ],
      const PumpLiveCard(),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Guided(
                  on: app.tourPending && _guideStep(app) == _Guide.feed,
                  child: ActionTile(
                    glyph: app.bottleFirst ? Glyphs.bottle : Glyphs.feed,
                    label: 'Feed',
                    hint: app.suggestedSide != null
                        ? 'Next: ${sideLabel(app.suggestedSide!)}'
                        : 'Log a feed',
                    soft: Baby.feedSoft,
                    strong: Baby.feed,
                    onTap: () => showSheet(context, const FeedSheet()),
                  ),
                ),
              ),
              Expanded(
                child: _Guided(
                  on: app.tourPending && _guideStep(app) == _Guide.nappy,
                  child: ActionTile(
                    glyph: Glyphs.nappy,
                    label: 'Nappy',
                    hint: 'Pee or poo',
                    soft: Baby.nappySoft,
                    strong: Baby.nappy,
                    onTap: () => showSheet(context, const NappySheet()),
                  ),
                ),
              ),
              Expanded(
                child: ActionTile(
                  glyph: Glyphs.sleep,
                  label: nap == null ? 'Sleep' : 'End nap',
                  hint: nap == null
                      ? 'Start a nap'
                      : duration(DateTime.now().difference(nap.time)),
                  soft: Baby.sleepSoft,
                  strong: Baby.sleep,
                  onTap: () => _napTap(context, app),
                ),
              ),
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
              if (app.pumpOnToday)
                Expanded(child: _pumpTile(context, app)),
            ],
          ),
        ),
      ),
      if (app.tourPending) ...[
        const SizedBox(height: 14),
        _FirstLogGuide(app: app),
      ],
      ..._tips(context, app),
      const SizedBox(height: 14),
      RoutinePreview(onOpen: widget.onSeeRoutines),
      const SizedBox(height: 14),
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
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
            color: Baby.sleep,
            soft: Baby.sleepSoft,
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
          if (app.pumpOnToday) _pumpTile(context, app),
          ActionTile(
            glyph: Glyphs.sleep,
            label: nap == null ? 'Start nap' : 'End nap',
            hint: nap == null
                ? 'Put down for a nap'
                : 'Sleeping · ${duration(now.difference(nap.time))}',
            soft: Baby.sleepSoft,
            strong: Baby.sleep,
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

  Widget _pumpTile(BuildContext context, AppState app) {
    final last = app.entriesOn(DateTime.now(), EntryType.pump).firstOrNull;
    return ActionTile(
      glyph: Glyphs.pump,
      label: 'Pump',
      hint: last == null
          ? 'Pump or log'
          : duration(DateTime.now().difference(last.time)),
      soft: Baby.pumpSoft,
      strong: Baby.pump,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PumpPage()),
      ),
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
    final radius = BorderRadius.circular(desktop ? DesktopTokens.radiusLg : 22);
    return Material(
      color: Baby.card,
      elevation: desktop || Baby.dark ? 0 : 1,
      shadowColor: Theme.of(context).cardTheme.shadowColor,
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

/// The top of Today: the baby's photo, name and age, then the time since
/// the last feed (the number that matters at 3 am), the last nappy and sleep.
class _BabyHero extends StatelessWidget {
  const _BabyHero({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Baby.hero,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) => _content(
          context,
          wide:
              constraints.maxWidth >=
              320 * MediaQuery.textScalerOf(context).scale(1),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, {required bool wide}) {
    final baby = app.activeBaby;
    final name = baby.name.trim();
    final last = app.lastFeed;
    final nappy = app.lastNappy;
    final nap = app.activeSleep;
    final soft = Baby.ink.withValues(alpha: 0.62);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              label: tr('Edit profile'),
              child: GestureDetector(
                onTap: () => editBabyProfile(context),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Baby.card.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: BabyPhoto(photo: baby.photo, size: 50),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText.raw(
                    name.isEmpty ? tr('Your baby') : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (baby.dateOfBirth != null)
                    LText(
                      babyAge(baby),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: soft,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => editBabyProfile(context),
                      child: LText(
                        'Add a birthday',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Baby.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // The greeting is a nicety: it gives way on narrow screens.
            if (wide) ...[
              const SizedBox(width: 8),
              LText(
                greeting(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: soft,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          button: last != null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: last == null ? null : () => editEntry(context, last),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  'Since last feed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: soft,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...previous, ?current],
                  ),
                  child: LText(
                    last == null ? 'No feeds yet' : _agoShort(last.time),
                    key: ValueKey(last?.time),
                    style: TextStyle(
                      fontSize: last == null ? 30 : 42,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: Baby.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                LText(
                  last == null
                      ? 'Tap Feed below when the next one starts'
                      : [
                          last.side == null ? 'Breast' : sideLabel(last.side!),
                          hm(last.time),
                          ?entryDetail(last),
                        ].join(' · '),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: soft,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _HeroStat(
                glyph: Glyphs.nappy,
                color: Baby.nappy,
                label: 'Last nappy',
                value: nappy == null ? 'None yet' : ago(nappy.time),
                onTap: nappy == null
                    ? () => showSheet(context, const NappySheet())
                    : () => editEntry(context, nappy),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeroStat(
                glyph: Glyphs.sleep,
                color: Baby.sleep,
                label: nap == null ? 'Sleep' : 'Sleeping',
                value: nap == null
                    ? 'Awake'
                    : duration(DateTime.now().difference(nap.time)),
                onTap: () => _napTap(context, app),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

void _napTap(BuildContext context, AppState app) {
  final nap = app.activeSleep;
  if (nap == null) {
    showSheet(context, const SleepSheet());
  } else {
    app.endSleep(nap);
  }
}

/// A small frosted tile inside the hero.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.glyph,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final Glyph glyph;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Baby.card.withValues(alpha: Baby.dark ? 0.35 : 0.7),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            glyph(22, color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Baby.muted,
                    ),
                  ),
                  LText(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The steps of the first-log guide, worked out from what has been logged.
enum _Guide { feed, nappy, done }

_Guide _guideStep(AppState app) => app.lastFeed == null
    ? _Guide.feed
    : app.lastNappy == null
    ? _Guide.nappy
    : _Guide.done;

/// Rings a quick-log button while the guide points at it. The ring breathes
/// a few times, then stays still.
class _Guided extends StatelessWidget {
  const _Guided({required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return Loop(
      period: const Duration(milliseconds: 900),
      cycles: 6,
      reverse: true,
      rest: 1,
      builder: (context, t) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Baby.primary.withValues(alpha: 0.35 + 0.5 * t),
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// After setup: a short guide that follows real logging, first a feed, then
/// a nappy, then a word on where everything ends up.
class _FirstLogGuide extends StatelessWidget {
  const _FirstLogGuide({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final step = _guideStep(app);
    final (title, text) = switch (step) {
      _Guide.feed => (
        'Log your first feed',
        'Tap Feed when the next feed starts. Use the timer, or just pick a '
            'side and save.',
      ),
      _Guide.nappy => (
        'Nice! Now a nappy',
        'Tap Nappy at the next change: pee, poo or both, in one tap.',
      ),
      _Guide.done => (
        'That’s the basics',
        'Everything you log shows on Today and in History. Reminders and '
            'sharing are in Settings.',
      ),
    };
    final index = _Guide.values.indexOf(step);
    return Card(
      color: Baby.primarySoft,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < _Guide.values.length; i++)
                  Container(
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    width: i == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= index
                          ? Baby.primary
                          : Baby.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LText(text, style: const TextStyle(height: 1.35)),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: app.finishTour,
                child: LText(step == _Guide.done ? 'Got it' : 'Skip tour'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Things setup no longer asks up front, offered on Today once they matter.
/// (The night light announces itself with its own banner.)
List<Widget> _tips(BuildContext context, AppState app) {
  if (app.tourPending) return const [];
  return [
    if (app.peers.isEmpty && app.lastFeed != null && app.tipShown('share'))
      _TipCard(
        glyph: Glyphs.heart,
        color: Baby.primary,
        soft: Baby.primarySoft,
        title: 'Share with your partner',
        text: 'Both phones keep the same log over your home Wi‑Fi.',
        dismiss: 'Not now',
        action: 'Connect',
        onDismiss: () => app.dismissTip('share'),
        onAction: () {
          app.dismissTip('share');
          openAddDevice(context);
        },
      ),
  ].expand((tip) => [const SizedBox(height: 14), tip]).toList();
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.glyph,
    required this.color,
    required this.soft,
    required this.title,
    required this.text,
    required this.dismiss,
    required this.action,
    required this.onDismiss,
    required this.onAction,
  });
  final Glyph glyph;
  final Color color;
  final Color soft;
  final String title;
  final String text;
  final String dismiss;
  final String action;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBubble(glyph: glyph, color: soft, iconColor: color, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      LText(text, style: TextStyle(color: Baby.muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(foregroundColor: Baby.muted),
                child: LText(dismiss),
              ),
              TextButton(onPressed: onAction, child: LText(action)),
            ],
          ),
        ],
      ),
    ),
  );
}

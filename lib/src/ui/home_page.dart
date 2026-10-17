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

    return PullToSync(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: LText(
              '${greeting()} · ${DateFormat('EEEE d MMMM').format(DateTime.now())}',
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w700),
            ),
          ),
          Card(
            color: Baby.pillSoft,
            child: ListTile(
              leading: Glyphs.sleep(28, Baby.pill),
              title: LText(app.activeSleep == null ? 'Sleep' : 'Sleeping'),
              subtitle: LText(
                app.activeSleep == null
                    ? 'Put down for a nap'
                    : '${hm(app.activeSleep!.time)} · ${duration(DateTime.now().difference(app.activeSleep!.time))}',
              ),
              trailing: FilledButton(
                onPressed: () {
                  final nap = app.activeSleep;
                  if (nap == null) {
                    showSheet(context, const SleepSheet());
                  } else {
                    app.endSleep(nap);
                  }
                },
                child: LText(app.activeSleep == null ? 'Start nap' : 'End nap'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          RoutinePreview(onOpen: widget.onSeeRoutines),
          const SizedBox(height: 14),
          if (app.timerStart != null) ...[
            _TimerCard(app: app),
            const SizedBox(height: 14),
          ],
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
              const SizedBox(width: 10),
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
              const SizedBox(width: 10),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _LastFeedCard(app: app)),
              const SizedBox(width: 10),
              Expanded(child: _LastNappyCard(app: app)),
            ],
          ),
          const SizedBox(height: 10),
          _ReminderRow(app: app),
          SectionTitle(
            'Today',
            trailing: Counts(
              feeds: today.where((e) => e.type == EntryType.feed).length,
              pee: today
                  .where(
                    (e) =>
                        e.type == EntryType.nappy && e.nappy != NappyKind.poo,
                  )
                  .length,
              poo: today
                  .where(
                    (e) =>
                        e.type == EntryType.nappy && e.nappy != NappyKind.pee,
                  )
                  .length,
            ),
          ),
          if (today.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LText(
                  'Nothing logged yet today.\nTap Feed, Nappy or Pill above to start.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Baby.muted,
                    fontWeight: FontWeight.w600,
                  ),
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
        ],
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
    final elapsed = DateTime.now().difference(app.timerStart!);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Card(
      color: Baby.feedSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            LText(
              'Feeding since ${hm(app.timerStart!)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: Baby.feed),
            ),
            LText(
              '$mm:$ss',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
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
            Row(
              children: [
                TextButton(
                  onPressed: () => app.stopFeedTimer(save: false),
                  child: const LText('Cancel'),
                ),
                const Spacer(),
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
    this.onTap,
  });
  final String title;
  final String value;
  final String detail;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            LText(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            LText(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            ),
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
    return Material(
      color: Baby.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Baby.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showFeedReminderSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

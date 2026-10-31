import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../momcozy.dart';
import '../pump_ble.dart';
import '../pump_session.dart';
import '../pump_tracking.dart';
import '../store.dart';
import 'common.dart';
import 'pump_art.dart';
import 'pump_lab_page.dart';
import 'sheets.dart';
import 'theme.dart';

/// Pumping: control the Momcozy pumps, save sessions and see how much was
/// pumped. Logging by hand works without pumps too.
class PumpPage extends StatefulWidget {
  const PumpPage({super.key});

  @override
  State<PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<PumpPage> {
  final hub = PumpHub.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !PumpHub.supported) return;
      hub.attach(AppScope.of(context));
      hub.connectSaved();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    hub.attach(app);
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final recent = app.pumpEntries.toList()
          ..sort((a, b) => b.time.compareTo(a.time));
        return Scaffold(
          appBar: AppBar(title: const LText('Pumping')),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Baby.pump,
            foregroundColor: Baby.onPrimary,
            icon: const Icon(Icons.edit_note_rounded),
            label: const LText('Log by hand'),
            onPressed: () => showSheet(context, const PumpSheet()),
          ),
          body: PageWidth(
            maxWidth: 720,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                96 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (hub.finished != null) _FinishedCard(hub: hub),
                if (PumpHub.supported) ...[
                  _PumpsCard(app: app, hub: hub),
                  if (hub.ready.isNotEmpty) _LiveCard(hub: hub),
                ],
                if (app.pumpFound.isNotEmpty) _FoundCard(app: app),
                _StatsCard(entries: recent),
                if (recent.isNotEmpty) ...[
                  const SectionTitle('Recent sessions'),
                  ListCard(
                    children: [
                      for (final e in recent.take(15))
                        EntryTile(
                          entry: e,
                          showDay: true,
                          onTap: () => editEntry(context, e),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Opens the save sheet for a session from the pumps.
Future<void> savePumpDraft(BuildContext context, Entry draft) =>
    showSheet(context, PumpSheet(draft: draft));

class _FinishedCard extends StatelessWidget {
  const _FinishedCard({required this.hub});
  final PumpHub hub;

  @override
  Widget build(BuildContext context) {
    final f = hub.finished!;
    return Card(
      color: Baby.pumpSoft,
      child: ListTile(
        leading: Glyphs.pump(28, Baby.pump),
        title: const LText(
          'Session finished',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: LText(
          '${hm(f.time)} · ${f.durationMin ?? 0} min'
          '${f.amountMl != null ? ' · ${f.amountMl} ml' : ''}',
        ),
        trailing: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Baby.pump),
          onPressed: () {
            final d = hub.takeFinished();
            if (d != null) savePumpDraft(context, d);
          },
          child: const LText('Save'),
        ),
      ),
    );
  }
}

class _PumpsCard extends StatelessWidget {
  const _PumpsCard({required this.app, required this.hub});
  final AppState app;
  final PumpHub hub;

  @override
  Widget build(BuildContext context) {
    final saved = app.pumpDevices;
    if (saved.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Glyphs.pump(28, Baby.pump),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: LText(
                      'Connect your Momcozy pumps',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LText(
                'Control them from here and save each session with how long '
                'it took and how much you pumped. Switch the pumps on and '
                'close the Momcozy app first.',
                style: TextStyle(color: Baby.muted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Baby.pump),
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: const LText('Find pumps'),
                onPressed: () => _showFinder(context),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Your pumps',
          trailing: TextButton(
            onPressed: () => _showFinder(context),
            child: const LText('Add'),
          ),
        ),
        ListCard(
          children: [
            for (final MapEntry(key: id, value: info) in saved.entries)
              _PumpRow(id: id, info: info, hub: hub),
          ],
        ),
      ],
    );
  }
}

class _PumpRow extends StatelessWidget {
  const _PumpRow({required this.id, required this.info, required this.hub});
  final String id;
  final Map<String, dynamic> info;
  final PumpHub hub;

  @override
  Widget build(BuildContext context) {
    final p = hub.pumps[id];
    final s = p?.session?.status;
    final side =
        p?.side ??
        switch (info['side']) {
          0 => FeedSide.left,
          1 => FeedSide.right,
          _ => null,
        };
    final name = side == null
        ? info['name'] as String? ?? 'Pump'
        : sideLabel(side);
    final (text, color) = switch (p?.state) {
      PumpLinkState.connecting => ('Connecting…', Baby.muted),
      PumpLinkState.ready when s?.runState == PumpRunState.running => (
        'Pumping',
        Baby.pump,
      ),
      PumpLinkState.ready => ('Connected', Baby.ok),
      PumpLinkState.failed => (p!.error ?? 'Not connected', Baby.muted),
      null => ('Not connected', Baby.muted),
    };
    final ready = p?.state == PumpLinkState.ready;
    return ListTile(
      leading: PumpPicture(
        model: _modelOf(p, info),
        side: side,
        milkMl: s?.milkMl,
        running: s?.runState == PumpRunState.running,
        dimmed: !ready,
        size: 46,
      ),
      title: LText(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: LText(
        [
          text,
          if (ready && (s?.milkMl ?? 0) > 0) '${s!.milkMl} ml',
        ].join(' · '),
        style: TextStyle(color: color),
      ),
      trailing: ready
          ? BatteryChip(s?.battery)
          : p?.state == PumpLinkState.connecting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (info['battery'] != null)
                  BatteryChip(info['battery'] as int?, lastKnown: true),
                TextButton(
                  onPressed: () =>
                      hub.connect(id, info['name'] as String? ?? 'Pump'),
                  child: const LText('Connect'),
                ),
              ],
            ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PumpDetailPage(id: id)),
      ),
    );
  }
}

/// What the user picked, else what the pump says or said before.
PumpModel _modelOf(ConnectedPump? p, Map<String, dynamic> info) {
  if (p?.session?.modelOverride case final m?) return m;
  final code =
      info['modelOverride'] as int? ??
      p?.session?.info?.productCode ??
      info['model'] as int?;
  return code == null ? PumpModel.m5Pro : PumpModel.fromCode(code);
}

String _modeName(PumpMode m) => switch (m) {
  PumpMode.massage => 'Massage',
  PumpMode.expression => 'Expression',
  PumpMode.mixed => 'Mixed',
  PumpMode.custom => 'Custom',
  PumpMode.auto => 'Auto',
};

String _clock(Duration d) {
  final m = d.inMinutes, s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Live control: one set of controls for both pumps, or one per pump.
class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.hub});
  final PumpHub hub;

  @override
  Widget build(BuildContext context) {
    final ready = hub.ready.toList()
      ..sort((a, b) => (a.side?.index ?? 9).compareTo(b.side?.index ?? 9));
    final together = hub.both || ready.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Pump now',
          trailing: ready.length > 1
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LText('Both together'),
                    Switch(value: hub.both, onChanged: hub.setBoth),
                  ],
                )
              : null,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _LiveClock(
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: Baby.pump,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (together)
                  _Controls(hub: hub, pumps: ready, target: null)
                else
                  for (final p in ready) ...[
                    const Divider(height: 28),
                    LText(
                      p.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    _Controls(hub: hub, pumps: [p], target: p),
                  ],
                if (hub.run.active) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const LText('Finish and save'),
                    onPressed: () async {
                      await hub.control(null, (s) => s.pause());
                      final d = hub.finishNow();
                      if (d != null && context.mounted) {
                        await savePumpDraft(context, d);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.hub,
    required this.pumps,
    required this.target,
  });
  final PumpHub hub;
  final List<ConnectedPump> pumps;

  /// Null sends to every pump.
  final ConnectedPump? target;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      for (final p in pumps)
        if (p.session?.status case final s?) (p, s),
    ];
    if (statuses.isEmpty) return const SizedBox.shrink();
    final sessions = [for (final (p, _) in statuses) p.session!];
    final running = sessions.any((s) => s.shownState == PumpRunState.running);
    final model = statuses.first.$1.session!.model;
    final modes = model == PumpModel.m5Pro
        ? const [PumpMode.massage, PumpMode.expression, PumpMode.mixed]
        : PumpMode.values;

    // Together, each pump steps from its own level.
    Future<void> send(Future<void> Function(PumpSession s) f) =>
        hub.control(target, f);

    final levels = {for (final s in sessions) s.shownLevel};
    final levelText = levels.length == 1
        ? '${levels.first}'
        : [
            for (final (p, _) in statuses)
              '${tr(p.side == FeedSide.right ? 'R' : 'L')} '
                  '${p.session!.shownLevel}',
          ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        SegmentedButton<PumpMode>(
          showSelectedIcon: false,
          segments: [
            for (final m in modes)
              ButtonSegment(value: m, label: LText(_modeName(m))),
          ],
          selected: {?sessions.first.shownMode},
          emptySelectionAllowed: true,
          onSelectionChanged: (v) {
            if (v.isNotEmpty) send((s) => s.setMode(v.first));
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.filledTonal(
              iconSize: 28,
              tooltip: tr('Lower'),
              icon: const Icon(Icons.remove_rounded),
              onPressed: () => send((s) => s.changeLevel(-1)),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    levelText,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  LText(
                    'Suction level, 1–${model.maxLevel}',
                    style: TextStyle(color: Baby.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              iconSize: 28,
              tooltip: tr('Higher'),
              icon: const Icon(Icons.add_rounded),
              onPressed: () => send((s) => s.changeLevel(1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Baby.pump,
            foregroundColor: Baby.onPrimary,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: LText(running ? 'Pause' : 'Start'),
          onPressed: () => send((s) => running ? s.pause() : s.resume()),
        ),
        for (final (p, s) in statuses)
          if (s.errorCode != 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LText(
                '${p.label}: error ${s.errorCode}',
                style: TextStyle(color: Baby.error),
              ),
            ),
      ],
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    Future<void> add(Entry e) async {
      await savePumpDraft(context, e);
      if (alreadyLogged(e, app.pumpEntries)) app.removePumpFound(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Found on your pumps',
          trailing: app.pumpFound.length > 1
              ? TextButton(
                  onPressed: () {
                    for (final e in [...app.pumpFound]) {
                      app.addEntry(
                        Entry(
                          type: EntryType.pump,
                          time: e.time,
                          endTime: e.endTime,
                          side: e.side,
                          durationMin: e.durationMin,
                          amountMl: e.amountMl,
                          leftMl: e.leftMl,
                          rightMl: e.rightMl,
                        ),
                      );
                      app.removePumpFound(e);
                    }
                  },
                  child: const LText('Add all'),
                )
              : null,
        ),
        ListCard(
          children: [
            for (final e in app.pumpFound)
              ListTile(
                leading: Glyphs.pump(24, Baby.pump),
                title: LText(
                  '${dayLabel(e.time)} ${hm(e.time)} · ${e.durationMin} min',
                ),
                subtitle: LText(
                  e.amountMl == null
                      ? 'Add how much you pumped'
                      : '${e.amountMl} ml',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LIconButton(
                      tooltip: 'Dismiss',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => app.removePumpFound(e),
                    ),
                    FilledButton.tonal(
                      onPressed: () => add(e),
                      child: const LText('Add'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Today and the last 7 days at a glance.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final ml = {for (final d in days) d: 0};
    final count = {for (final d in days) d: 0};
    for (final e in entries) {
      final d = DateTime(e.time.year, e.time.month, e.time.day);
      if (!ml.containsKey(d)) continue;
      ml[d] = ml[d]! + (e.amountMl ?? 0);
      count[d] = count[d]! + 1;
    }
    final top = ml.values.fold(0, (a, b) => a > b ? a : b);
    final week = ml.values.fold(0, (a, b) => a + b);
    final daysWith = count.values.where((c) => c > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('This week'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _Stat('Today', '${ml[today]} ml', _sessions(count[today]!)),
                    _Stat(
                      'Per day',
                      daysWith == 0 ? '–' : '${(week / daysWith).round()} ml',
                      'on days you pumped',
                    ),
                    _Stat(
                      '7 days',
                      '$week ml',
                      _sessions(count.values.fold(0, (a, b) => a + b)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in days)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: FractionallySizedBox(
                                    heightFactor: top == 0
                                        ? 0.02
                                        : (ml[d]! / top).clamp(0.02, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: d == today
                                            ? Baby.pump
                                            : Baby.pump.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.E().format(d),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Baby.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _sessions(int n) => n == 1 ? '1 session' : '$n sessions';

class _Stat extends StatelessWidget {
  const _Stat(this.title, this.value, this.detail);
  final String title, value, detail;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        LText(title, style: TextStyle(color: Baby.muted, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Baby.pump,
          ),
        ),
        LText(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(color: Baby.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

/// Finds pumps nearby and connects the one tapped; it is remembered.
Future<void> _showFinder(BuildContext context) {
  final hub = PumpHub.instance;
  // Set once the user says which pump they have, for one we cannot spot.
  PumpModel? manual;
  hub.startScan();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => ListenableBuilder(
        listenable: hub,
        builder: (context, _) {
          final pumps = hub.found.values
              .where((f) => manual != null || f.model != null)
              .toList();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: LText(
                          'Pumps nearby',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (hub.scanning)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton(
                          onPressed: hub.startScan,
                          child: const LText('Look again'),
                        ),
                    ],
                  ),
                  if (hub.problem != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LText(
                        hub.problem!,
                        style: TextStyle(color: Baby.warn),
                      ),
                    ),
                  if (pumps.isEmpty && !hub.scanning)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: LText(
                        'No pumps found. Switch them on, close the Momcozy app '
                        'and look again.',
                        style: TextStyle(color: Baby.muted),
                      ),
                    ),
                  for (final f in pumps)
                    ListTile(
                      leading: PumpPicture(
                        model: f.model ?? manual ?? PumpModel.m5Pro,
                        size: 40,
                      ),
                      title: Text(f.name),
                      subtitle: LText(
                        hub.pumps[f.id]?.state == PumpLinkState.ready
                            ? 'Connected'
                            : 'Tap to connect',
                      ),
                      onTap: () => hub.connect(f.id, f.name, model: manual),
                    ),
                  const SizedBox(height: 8),
                  if (manual == null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const LText('My pump isn’t listed'),
                      onPressed: () async {
                        final m = await pickPumpModel(context);
                        if (m == null) return;
                        setSheet(() => manual = m);
                        hub.setShowAll(true);
                        await hub.startScan();
                      },
                    )
                  else
                    LText(
                      'Showing every Bluetooth device. Tap your '
                      '${pumpModelName(manual!)}; it is usually named “M5 Smart” '
                      'or after the model.',
                      style: TextStyle(color: Baby.muted),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PumpLabPage()),
                      );
                    },
                    child: const LText('Trouble connecting? Open the pump lab'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ).whenComplete(() => hub.setShowAll(false));
}

/// Shown on Today while the pumps run, or when a session waits to be saved.
class PumpLiveCard extends StatefulWidget {
  const PumpLiveCard({super.key});

  @override
  State<PumpLiveCard> createState() => _PumpLiveCardState();
}

class _PumpLiveCardState extends State<PumpLiveCard> {
  final hub = PumpHub.instance;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: hub,
    builder: (context, _) {
      final started = hub.run.started;
      if (started == null && hub.finished == null) {
        return const SizedBox.shrink();
      }
      if (started == null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _FinishedCard(hub: hub),
        );
      }
      final ready = hub.ready.toList()
        ..sort((a, b) => (a.side?.index ?? 9).compareTo(b.side?.index ?? 9));
      final running = ready.any(
        (p) => p.session?.shownState == PumpRunState.running,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          color: Baby.pumpSoft,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PumpPage()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Glyphs.pump(32, Baby.pump),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText(
                          running ? 'Pumping' : 'Paused',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Row(
                          children: [
                            _LiveClock(style: TextStyle(color: Baby.muted)),
                            Flexible(
                              child: Text(
                                [
                                  '',
                                  for (final p in ready)
                                    '${tr(p.side == FeedSide.right ? 'R' : 'L')} '
                                        '${p.session!.shownLevel}',
                                ].join(' · '),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Baby.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Baby.pump),
                    tooltip: tr(running ? 'Pause' : 'Start'),
                    icon: Icon(
                      running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    onPressed: () => hub.control(
                      null,
                      (s) => running ? s.pause() : s.resume(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// One pump: live state while connected, what it last showed when not, and
/// what it is.
class PumpDetailPage extends StatelessWidget {
  const PumpDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final hub = PumpHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final info = app.pumpDevices[id] ?? const <String, dynamic>{};
        final p = hub.pumps[id];
        final ready = p?.state == PumpLinkState.ready;
        final s = ready ? p!.session?.status : null;
        final side =
            p?.side ??
            switch (info['side']) {
              0 => FeedSide.left,
              1 => FeedSide.right,
              _ => null,
            };
        final title = switch (side) {
          FeedSide.left => 'Left pump',
          FeedSide.right => 'Right pump',
          _ => info['name'] as String? ?? 'Pump',
        };
        final battery = s?.battery ?? info['battery'] as int?;
        final milk = s?.milkMl ?? info['milkMl'] as int?;
        final seen = info['lastSeen'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(info['lastSeen'] as int);
        final state = switch (p?.state) {
          PumpLinkState.connecting => 'Connecting…',
          PumpLinkState.ready => switch (s?.runState) {
            PumpRunState.running => 'Pumping',
            PumpRunState.off => 'Switched off',
            _ => 'Paused',
          },
          _ => 'Not connected',
        };
        final session = p?.session;
        final serial = session?.info?.serial ?? info['serial'] as String?;
        final firmware =
            session?.info?.firmwareVersion ?? info['firmware'] as int?;
        final hardware =
            session?.info?.hardwareVersion ?? info['hardware'] as int?;

        Widget row(String label, String value) => ListTile(
          dense: true,
          title: LText(label, style: TextStyle(color: Baby.muted)),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );

        return Scaffold(
          appBar: AppBar(title: LText(title)),
          body: PageWidth(
            maxWidth: 720,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        PumpPicture(
                          model: _modelOf(p, info),
                          side: side,
                          milkMl: milk,
                          running: s?.runState == PumpRunState.running,
                          dimmed: !ready,
                          size: 120,
                        ),
                        const SizedBox(height: 10),
                        LText(
                          state,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ready ? Baby.ink : Baby.muted,
                          ),
                        ),
                        if (!ready && seen != null)
                          LText(
                            'Last connected ${dayLabel(seen)} ${hm(seen)}',
                            style: TextStyle(color: Baby.muted),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _Stat(
                              'Milk',
                              milk == null ? '–' : '$milk ml',
                              ready ? 'this session' : 'last reading',
                            ),
                            _Stat(
                              'Battery',
                              battery == null ? '–' : '$battery%',
                              ready ? 'now' : 'last known',
                            ),
                            _Stat(
                              'Pumped',
                              s == null
                                  ? '–'
                                  : _clock(Duration(seconds: s.totalSeconds)),
                              'this session',
                            ),
                          ],
                        ),
                        if (battery != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              BatteryChip(battery, lastKnown: !ready),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    minHeight: 8,
                                    value: battery / 100,
                                    color: battery < 15
                                        ? Baby.error
                                        : Baby.pump,
                                    backgroundColor: Baby.pumpSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (s != null) ...[
                  const SectionTitle('Right now'),
                  ListCard(
                    children: [
                      row('Mode', tr(_modeName(s.mode ?? PumpMode.massage))),
                      row('Level', '${s.level} / ${session!.model.maxLevel}'),
                      if (s.errorCode != 0) row('Error', '${s.errorCode}'),
                    ],
                  ),
                ],
                const SectionTitle('About this pump'),
                ListCard(
                  children: [
                    ListTile(
                      dense: true,
                      title: LText(
                        'Model',
                        style: TextStyle(color: Baby.muted),
                      ),
                      subtitle: info['modelOverride'] == null
                          ? null
                          : const LText('Chosen by you'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pumpModelName(_modelOf(p, info)),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Baby.muted),
                        ],
                      ),
                      onTap: () async {
                        final m = await pickPumpModel(
                          context,
                          current: _modelOf(p, info),
                        );
                        if (m == null) return;
                        p?.session?.modelOverride = m;
                        app.rememberPump(id, {'modelOverride': m.code});
                      },
                    ),
                    if (side != null) row('Side', sideLabel(side)),
                    if (serial != null && serial.isNotEmpty)
                      row('Serial number', serial),
                    if (firmware != null) row('Firmware', '$firmware'),
                    if (hardware != null) row('Hardware', '$hardware'),
                    row('Bluetooth', id.toUpperCase()),
                  ],
                ),
                const SectionTitle('Actions'),
                ListCard(
                  children: [
                    if (ready)
                      ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: const LText('Check for sessions on the pump'),
                        onTap: () async {
                          try {
                            final r = await hub.importHistory(p!);
                            if (context.mounted) {
                              showMessage(
                                context,
                                r.isEmpty
                                    ? 'Nothing new on the pump'
                                    : 'Read ${r.length} records from the pump',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) showMessage(context, '$e');
                          }
                        },
                      ),
                    if (ready)
                      ListTile(
                        leading: const Icon(Icons.power_settings_new_rounded),
                        title: const LText('Switch off'),
                        onTap: () => hub.control(p, (s) => s.switchOff()),
                      ),
                    if (ready)
                      ListTile(
                        leading: const Icon(Icons.link_off_rounded),
                        title: const LText('Disconnect'),
                        onTap: () => hub.disconnect(id),
                      )
                    else if (p?.state != PumpLinkState.connecting)
                      ListTile(
                        leading: const Icon(Icons.bluetooth_rounded),
                        title: const LText('Connect'),
                        subtitle: p?.error == null ? null : LText(p!.error!),
                        onTap: () =>
                            hub.connect(id, info['name'] as String? ?? 'Pump'),
                      ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: Baby.error,
                      ),
                      title: LText(
                        'Forget this pump',
                        style: TextStyle(color: Baby.error),
                      ),
                      onTap: () async {
                        await hub.forget(id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pumping time, redrawn every second on its own so nothing around it
/// rebuilds.
class _LiveClock extends StatefulWidget {
  const _LiveClock({this.style});
  final TextStyle? style;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (PumpHub.instance.run.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    _clock(PumpHub.instance.run.pumped(DateTime.now())),
    style: widget.style,
  );
}

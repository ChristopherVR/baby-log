import 'package:flutter/material.dart';

import '../distribution.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'sheets.dart';
import 'theme.dart';

class PillsPage extends StatelessWidget {
  const PillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final desktop = Desktop.of(context);
    return Scaffold(
      // On desktop "Add pill" is in the top bar.
      floatingActionButton: desktop
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label: const LText(
                'Add pill',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () => showSheet(context, const MedEditor()),
            ),
      body: PullToSync(
        child: PageWidth(
          child: app.meds.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 60),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconBubble(
                              glyph: Glyphs.pill,
                              color: Baby.pillSoft,
                              iconColor: Baby.pill,
                              size: 80,
                            ),
                            const SizedBox(height: 16),
                            const LText(
                              'No pills yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            LText(
                              'Add a pill, say how often you take it and when you start.\n'
                              'The dose times and alarms are worked out for you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Baby.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, box) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: desktop
                        ? const EdgeInsets.fromLTRB(24, 20, 24, 32)
                        : const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: _columns(desktop && box.maxWidth >= 820 ? 2 : 1, [
                      for (final med in app.meds)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconBubble(
                                      glyph: Glyphs.pill,
                                      color: Baby.pillSoft,
                                      iconColor: Baby.pill,
                                      size: 46,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          LText.raw(
                                            med.name,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          LText(
                                            [
                                              if (med.dose.isNotEmpty) med.dose,
                                              med.scheduleLabel,
                                            ].join(' · '),
                                            style: TextStyle(
                                              color: Baby.muted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      app.remindHere(med)
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_off_outlined,
                                      size: 20,
                                      color: app.remindHere(med)
                                          ? Baby.pill
                                          : Baby.muted,
                                    ),
                                    LIconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => showSheet(
                                        context,
                                        MedEditor(initial: med),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                LText(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Baby.muted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final (at, dose) in app.todaySlots(
                                      med,
                                    ))
                                      ActionChip(
                                        // A dose not yet ticked off can be logged at its planned time.
                                        onPressed: dose != null
                                            ? () => editEntry(context, dose)
                                            : () => showSheet(
                                                context,
                                                TakePillSheet(
                                                  med: med,
                                                  time: at.isBefore(now)
                                                      ? at
                                                      : null,
                                                ),
                                              ),
                                        backgroundColor: dose != null
                                            ? Baby.nappySoft
                                            : Baby.card,
                                        avatar: Icon(
                                          dose != null
                                              ? Icons.check_circle_rounded
                                              : at.isBefore(now)
                                              ? Icons.error_outline_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          size: 18,
                                          color: dose != null
                                              ? Baby.ok
                                              : at.isBefore(now)
                                              ? Baby.warn
                                              : Baby.muted,
                                        ),
                                        label: LText(
                                          dose != null
                                              ? '${hm(at)} · taken ${hm(dose.time)}'
                                              : hm(at),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          icon: const Icon(Icons.check_rounded),
                                          label: const LText('Taken now'),
                                          onPressed: () =>
                                              takeAndUndo(context, app, med),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.schedule_rounded,
                                        ),
                                        label: const LText('Other time'),
                                        onPressed: () => showSheet(
                                          context,
                                          TakePillSheet(med: med),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
        ),
      ),
    );
  }

  /// Lays [cards] out in rows of [count], 12 apart.
  static List<Widget> _columns(int count, List<Widget> cards) => [
    for (var i = 0; i < cards.length; i += count)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: count == 1
            ? cards[i]
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + count; j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(
                        child: j < cards.length
                            ? cards[j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
  ];
}

void takeAndUndo(
  BuildContext context,
  AppState app,
  Medication med, {
  DateTime? time,
}) {
  final dose = app.takePill(med, time: time);
  showUndo(
    context,
    '${med.name} taken at ${whenLabel(dose.time)}',
    () => app.deleteEntry(dose),
  );
}

/// Mark a pill as taken: which pill (if there are several) and when.
class TakePillSheet extends StatefulWidget {
  const TakePillSheet({super.key, this.med, this.time});
  final Medication? med;
  final DateTime? time;

  @override
  State<TakePillSheet> createState() => _TakePillSheetState();
}

class _TakePillSheetState extends State<TakePillSheet> {
  String? medId;
  late DateTime? time = widget.time;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.meds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }
    // Default to the pill that is due soonest.
    final byDue = [...app.meds]
      ..sort((a, b) => app.nextDose(a).compareTo(app.nextDose(b)));
    final med =
        app.meds.where((m) => m.id == (medId ?? widget.med?.id)).firstOrNull ??
        byDue.first;
    final next = app.nextDose(med);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: 'Take a pill',
          subtitle: next.isBefore(DateTime.now())
              ? '${med.name} was due at ${hm(next)}'
              : '${med.name} next due ${hm(next)}',
          glyph: Glyphs.pill,
        ),
        if (app.meds.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in app.meds)
                ChoiceChip(
                  avatar: Glyphs.pill(18, Baby.pill),
                  label: LText(m.name),
                  selected: m.id == med.id,
                  onSelected: (_) => setState(() => medId = m.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        WhenField(value: time, onChanged: (t) => setState(() => time = t)),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: LText(
            time == null
                ? 'Mark as taken now'
                : 'Mark as taken at ${hm(time!)}',
          ),
          onPressed: () {
            Navigator.pop(context);
            takeAndUndo(context, app, med, time: time);
          },
        ),
      ],
    );
  }
}

class MedEditor extends StatefulWidget {
  const MedEditor({super.key, this.initial});
  final Medication? initial;

  @override
  State<MedEditor> createState() => _MedEditorState();
}

class _MedEditorState extends State<MedEditor> {
  late final name = TextEditingController(text: widget.initial?.name);
  late final dose = TextEditingController(text: widget.initial?.dose);
  late ScheduleMode mode = widget.initial?.mode ?? ScheduleMode.timesPerDay;
  late int count = widget.initial?.count ?? 2;
  late int start = widget.initial?.startMinutes ?? 8 * 60;

  /// Reminders on this phone; null until changed (then the saved setting applies).
  bool? remind;
  final Map<int, String> reminderStyles = {};

  @override
  void dispose() {
    name.dispose();
    dose.dispose();
    super.dispose();
  }

  Medication get _draft => Medication(
    id: widget.initial?.id,
    name: name.text.trim(),
    dose: dose.text.trim(),
    mode: mode,
    count: count,
    startMinutes: start,
    remind: widget.initial?.remind ?? true,
    createdBy: widget.initial?.createdBy,
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final perDay = mode == ScheduleMode.timesPerDay;
    final max = perDay ? 8 : 24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: widget.initial == null ? 'Add pill' : 'Edit pill',
          glyph: Glyphs.pill,
        ),
        TextField(
          controller: name,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const LInputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Iron, Vitamins',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: dose,
          decoration: const LInputDecoration(
            labelText: 'How many (optional)',
            hintText: 'e.g. 1 tablet',
          ),
        ),
        const SizedBox(height: 18),
        const LText('How often', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final m in ScheduleMode.values) ...[
              Expanded(
                child: OptionTile(
                  label: m == ScheduleMode.timesPerDay
                      ? 'Times a day'
                      : 'Every X hours',
                  selected: mode == m,
                  color: Baby.pillSoft,
                  onTap: () => setState(() {
                    if (mode == m) return;
                    mode = m;
                    count = (24 / count).round().clamp(
                      1,
                      m == ScheduleMode.timesPerDay ? 8 : 24,
                    );
                  }),
                ),
              ),
              if (m == ScheduleMode.timesPerDay) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: count > 1 ? () => setState(() => count--) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: LText(
                perDay
                    ? '$count× a day'
                    : 'Every $count hour${count == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: count < max ? () => setState(() => count++) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.wb_sunny_outlined, color: Baby.pill),
          title: const LText(
            'First dose at',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: LText(
            minutesOfDay(start),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
            );
            if (t != null) setState(() => start = t.hour * 60 + t.minute);
          },
        ),
        LText(
          'DOSE TIMES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Baby.muted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in _draft.slots)
              Chip(
                backgroundColor: Baby.pillSoft,
                label: LText(minutesOfDay(m)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        LText(
          'REMINDER BY DOSE TIME',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Baby.muted,
          ),
        ),
        const SizedBox(height: 4),
        for (final slot in _draft.slots)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: LText(
                    minutesOfDay(slot),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: () {
                      final style =
                          reminderStyles[slot] ??
                          app.pillReminderOverride(_draft, slot) ??
                          'default';
                      return Distribution.play && style != 'off'
                          ? 'default'
                          : style;
                    }(),
                    items: [
                      if (!Distribution.play) ...[
                        DropdownMenuItem(
                          value: 'default',
                          child: LText(
                            'Use default (${app.pillAlarm ? 'alarm' : 'notification'})',
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'alarm',
                          child: LText('Alarm'),
                        ),
                        const DropdownMenuItem(
                          value: 'notification',
                          child: LText('Notification'),
                        ),
                      ] else
                        const DropdownMenuItem(
                          value: 'default',
                          child: LText('On'),
                        ),
                      const DropdownMenuItem(value: 'off', child: LText('Off')),
                    ],
                    onChanged: (value) => setState(
                      () => reminderStyles[slot] = value ?? 'default',
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!perDay && 24 % count != 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LText(
              'Every $count hours does not fit a day evenly, so the times restart each day at the first dose.',
              style: TextStyle(color: Baby.warn, fontWeight: FontWeight.w600),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const LText(
            'Remind me on this phone',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const LText(
            'Reminders are set per dose time on this phone. The other phone has its own settings.',
          ),
          value:
              remind ??
              (widget.initial == null || app.remindHere(widget.initial!)),
          onChanged: (v) => setState(() => remind = v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (widget.initial != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Baby.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const LText('Delete'),
                onPressed: () {
                  final med = widget.initial!;
                  app.deleteMed(med);
                  Navigator.pop(context);
                  showUndo(
                    context,
                    '${med.name} deleted',
                    () => app.saveMed(med.copyWith(deleted: false)),
                  );
                },
              ),
            const Spacer(),
            FilledButton(
              onPressed: name.text.trim().isEmpty
                  ? null
                  : () async {
                      if (!await okToOverwrite(context, app, widget.initial) ||
                          !context.mounted) {
                        return;
                      }
                      final saved = _draft;
                      app.saveMed(
                        saved,
                        remindHere:
                            remind ?? (widget.initial == null ? true : null),
                      );
                      app.setPillReminderOverrides(saved, reminderStyles);
                      Navigator.pop(context);
                    },
              child: const LText('Save pill'),
            ),
          ],
        ),
      ],
    );
  }
}

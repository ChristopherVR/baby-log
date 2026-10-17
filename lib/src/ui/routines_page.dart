import 'package:flutter/material.dart';

import '../routines.dart';
import 'common.dart';
import 'sheets.dart';
import 'theme.dart';
import 'routine_history.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String repeatLabel(Routine r) => r.weekdays.length == 7
    ? tr('Every day')
    : r.weekdays.map((d) => tr(_days[d - 1])).join(', ');

class BabyPicker extends StatelessWidget {
  const BabyPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          Icon(Icons.child_care_rounded, color: Baby.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: app.activeBabyId,
                items: [
                  for (final b in app.babies)
                    DropdownMenuItem(
                      value: b.id,
                      child: LText.raw(
                        b.name.isEmpty ? tr('Baby') : b.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null && !app.selectBaby(id)) {
                    showMessage(
                      context,
                      'Save or stop the feed timer before switching babies.',
                    );
                  }
                },
              ),
            ),
          ),
          LIconButton(
            tooltip: 'Rename baby',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _babyName(context, rename: true),
          ),
          LIconButton(
            tooltip: 'Add baby',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _babyName(context),
          ),
        ],
      ),
    );
  }
}

Future<void> _babyName(BuildContext context, {bool rename = false}) async {
  final app = AppScope.of(context);
  final name = await showDialog<String>(
    context: context,
    builder: (_) =>
        _BabyNameDialog(rename: rename, name: rename ? app.babyName : ''),
  );
  if (name != null) {
    if (rename) {
      app.setBabyName(name);
    } else {
      app.addBaby(name);
    }
  }
}

class _BabyNameDialog extends StatefulWidget {
  const _BabyNameDialog({required this.rename, required this.name});
  final bool rename;
  final String name;
  @override
  State<_BabyNameDialog> createState() => _BabyNameDialogState();
}

class _BabyNameDialogState extends State<_BabyNameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LText(widget.rename ? 'Rename baby' : 'Add a baby'),
    content: Form(
      key: _form,
      child: LTextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: const LInputDecoration(
          labelText: 'Baby’s name',
          hintText: 'e.g. Markus',
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LText('Cancel'),
      ),
      FilledButton(
        onPressed: _save,
        child: LText(widget.rename ? 'Save' : 'Add baby'),
      ),
    ],
  );
}

class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final routines = app.routines;
    return PullToSync(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: LText(
              'A little rhythm for ${app.babyName.isEmpty ? tr('your baby') : app.babyName}',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: LText(
              'Plan bath time, bedtime and the little things you do together.',
              style: TextStyle(color: Baby.muted),
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const LText('Add routine'),
            onPressed: () => _editRoutine(context),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => openRoutineHistory(context),
              icon: const Icon(Icons.history_rounded),
              label: const LText('Routine history'),
            ),
          ),
          if (routines.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.bathtub_outlined, size: 52, color: Baby.primary),
                    const SizedBox(height: 12),
                    const LText(
                      'Make bath time part of the day',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const LText(
                      'Choose a time and the days that suit your family. Each baby has their own routines.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _editRoutine(context, suggested: tr('Bath time')),
                      icon: const Icon(Icons.bathtub_outlined),
                      label: const LText('Set up bath time'),
                    ),
                  ],
                ),
              ),
            ),
          for (final r in routines)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        r.name.toLowerCase().contains('bath')
                            ? Icons.bathtub_outlined
                            : Icons.event_repeat_rounded,
                        color: r.enabled ? Baby.primary : Baby.muted,
                      ),
                      title: LText.raw(
                        r.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: LText(
                        '${minutesOfDay(r.minutes)} · ${repeatLabel(r)}${r.notes.isEmpty ? '' : '\n${r.notes}'}',
                      ),
                      isThreeLine: r.notes.isNotEmpty,
                      trailing: LIconButton(
                        tooltip: 'Edit ${r.name}',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editRoutine(context, initial: r),
                      ),
                    ),
                    RoutineActions(routine: r),
                    SwitchListTile.adaptive(
                      dense: true,
                      title: LText(
                        r.enabled ? 'Routine active' : 'Routine paused',
                      ),
                      subtitle: LText(
                        app.routineRemindsHere(r)
                            ? 'Reminders on this device'
                            : 'Reminders off on this device',
                      ),
                      value: r.enabled,
                      onChanged: (on) =>
                          app.saveRoutine(r.copyWith(enabled: on)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RoutinePreview extends StatelessWidget {
  const RoutinePreview({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final upcoming = app.routines.expand((r) {
      final at = app.nextRoutineAt(r, now);
      return at == null ? <(Routine, DateTime)>[] : [(r, at)];
    }).toList()..sort((a, b) => a.$2.compareTo(b.$2));
    final next = upcoming.firstOrNull;
    final recent = app.routineHistory().firstOrNull;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.event_repeat_rounded, color: Baby.primary),
            title: LText(
              next == null
                  ? 'Plan your baby’s routines'
                  : 'Next: ${next.$1.name}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: LText(
              next == null
                  ? 'Set up bath time, bedtime and more'
                  : '${dayLabel(next.$2)} · ${hm(next.$2)}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpen,
          ),
          if (recent != null)
            ListTile(
              leading: Icon(Icons.check_circle_outline_rounded, color: Baby.ok),
              title: LText(
                'Last ${recent.routineName.toLowerCase()}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: LText(completionLabel(recent)),
              onTap: () => openRoutineHistory(context),
            ),
        ],
      ),
    );
  }
}

Future<void> _editRoutine(
  BuildContext context, {
  Routine? initial,
  String suggested = '',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _RoutineEditor(
    initial: initial,
    suggested: suggested,
    babyId: AppScope.of(context).activeBabyId,
  ),
);

class _RoutineEditor extends StatefulWidget {
  const _RoutineEditor({
    this.initial,
    required this.suggested,
    required this.babyId,
  });
  final Routine? initial;
  final String suggested;
  final String babyId;
  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?.name ?? widget.suggested,
  );
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late var _minutes = widget.initial?.minutes ?? 18 * 60;
  late final _weekdays = (widget.initial?.weekdays ?? [1, 2, 3, 4, 5, 6, 7])
      .toSet();
  bool? _remind;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 +
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              LText(
                widget.initial == null
                    ? 'A new little routine'
                    : 'Edit routine',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              LTextFormField(
                controller: _name,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const LInputDecoration(
                  labelText: 'Routine name',
                  hintText: 'Bath time',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Give your routine a name'
                    : null,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final name in ['Bath time', 'Bedtime', 'Tummy time'])
                    ActionChip(
                      label: LText(name),
                      onPressed: () => setState(() => _name.text = tr(name)),
                    ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const LText('Time'),
                trailing: LText(
                  minutesOfDay(_minutes),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: _minutes ~/ 60,
                      minute: _minutes % 60,
                    ),
                  );
                  if (time != null && mounted) {
                    setState(() => _minutes = time.hour * 60 + time.minute);
                  }
                },
              ),
              const LText(
                'Repeat on',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              FormField<bool>(
                validator: (_) =>
                    _weekdays.isEmpty ? 'Choose at least one day' : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          FilterChip(
                            label: LText(_days[d - 1]),
                            selected: _weekdays.contains(d),
                            onSelected: (on) => setState(() {
                              if (on) {
                                _weekdays.add(d);
                              } else {
                                _weekdays.remove(d);
                              }
                              field.didChange(true);
                            }),
                          ),
                      ],
                    ),
                    if (field.hasError)
                      LText(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LTextFormField(
                controller: _notes,
                maxLength: 500,
                maxLines: 3,
                decoration: const LInputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Anything that helps your routine',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const LText('Remind me on this device'),
                subtitle: const LText(
                  'At the scheduled time on your chosen days',
                ),
                value:
                    _remind ??
                    (widget.initial != null &&
                        app.routineRemindsHere(widget.initial!)),
                onChanged: (on) => setState(() => _remind = on),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  if (!await okToOverwrite(context, app, widget.initial) ||
                      !context.mounted) {
                    return;
                  }
                  app.saveRoutine(
                    Routine(
                      id: widget.initial?.id,
                      babyId: widget.initial?.babyId ?? widget.babyId,
                      name: _name.text.trim(),
                      notes: _notes.text.trim(),
                      minutes: _minutes,
                      weekdays: _weekdays.toList(),
                      enabled: widget.initial?.enabled ?? true,
                    ),
                    remind:
                        _remind ??
                        (widget.initial != null &&
                            app.routineRemindsHere(widget.initial!)),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const LText('Save routine'),
              ),
              if (widget.initial != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const LText('Delete routine'),
                  onPressed: () async {
                    if (!await okToOverwrite(context, app, widget.initial) ||
                        !context.mounted) {
                      return;
                    }
                    final r = widget.initial!;
                    app.saveRoutine(r.copyWith(deleted: true));
                    Navigator.pop(context);
                    showUndo(
                      context,
                      'Routine deleted',
                      () => app.saveRoutine(r.copyWith(deleted: false)),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

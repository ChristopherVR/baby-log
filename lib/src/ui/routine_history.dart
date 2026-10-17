import 'package:flutter/material.dart';

import '../routines.dart';
import 'common.dart';
import 'theme.dart';

String completionLabel(RoutineCompletion c) =>
    '${whenLabel(c.time)} · ${c.doneBy}';

void openRoutineHistory(
  BuildContext context, {
  String? routineId,
  String? routineName,
}) {
  final babyId = AppScope.of(context).activeBabyId;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _RoutineHistoryPage(
        babyId: babyId,
        routineId: routineId,
        routineName: routineName,
      ),
    ),
  );
}

class RoutineActions extends StatelessWidget {
  const RoutineActions({super.key, required this.routine});
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final last = AppScope.of(context).lastRoutineCompletion(routine);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText(
            last == null
                ? 'Not done yet'
                : 'Last done: ${completionLabel(last)}',
            style: TextStyle(
              color: last == null ? Baby.muted : Baby.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => markRoutineDone(context, routine),
                icon: const Icon(Icons.check_rounded),
                label: const LText('Mark done'),
              ),
              TextButton.icon(
                onPressed: () => openRoutineHistory(
                  context,
                  routineId: routine.id,
                  routineName: routine.name,
                ),
                icon: const Icon(Icons.history_rounded),
                label: const LText('History'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> markRoutineDone(BuildContext context, Routine routine) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _CompletionForm(routine: routine),
    );

class _CompletionForm extends StatefulWidget {
  const _CompletionForm({required this.routine});
  final Routine routine;
  @override
  State<_CompletionForm> createState() => _CompletionFormState();
}

class _CompletionFormState extends State<_CompletionForm> {
  final _form = GlobalKey<FormState>();
  late final _person = TextEditingController(
    text: AppScope.of(context).caregiverName,
  );
  DateTime _at = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LText(
                'Mark ${widget.routine.name} as done',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              LTextFormField(
                controller: _person,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const LInputDecoration(
                  labelText: 'Who did it?',
                  hintText: 'e.g. Mum, Dad or a name',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter who did the routine'
                    : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const LText('Date'),
                trailing: LText(dayLabel(_at)),
                onTap: () async {
                  final day = await showDatePicker(
                    context: context,
                    initialDate: _at,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (day != null && mounted) {
                    setState(() {
                      _at = DateTime(
                        day.year,
                        day.month,
                        day.day,
                        _at.hour,
                        _at.minute,
                      );
                      _error = null;
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const LText('Time'),
                trailing: LText(hm(_at)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_at),
                  );
                  if (time != null && mounted) {
                    setState(() {
                      _at = DateTime(
                        _at.year,
                        _at.month,
                        _at.day,
                        time.hour,
                        time.minute,
                      );
                      _error = null;
                    });
                  }
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const LText('Save completion'),
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  if (_at.isAfter(DateTime.now())) {
                    setState(
                      () => _error = 'Choose a time that has already happened',
                    );
                    return;
                  }
                  final completion = app.completeRoutine(
                    widget.routine,
                    doneBy: _person.text,
                    time: _at,
                  );
                  if (completion == null) {
                    setState(
                      () => _error = 'This routine was removed. Close and refresh the routines list.',
                    );
                    return;
                  }
                  Navigator.pop(context);
                  showUndo(
                    context,
                    '${completion.routineName} marked done',
                    () => app.setRoutineCompletionDeleted(completion, true),
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

class _RoutineHistoryPage extends StatelessWidget {
  const _RoutineHistoryPage({
    required this.babyId,
    this.routineId,
    this.routineName,
  });
  final String babyId;
  final String? routineId;
  final String? routineName;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final history = app.routineHistory(babyId: babyId, routineId: routineId);
    return Scaffold(
      appBar: AppBar(
        title: LText(
          routineName == null ? 'Routine history' : '$routineName history',
        ),
      ),
      body: PageWidth(
        child: history.isEmpty
            ? const Center(child: LText('No completions yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, i) {
                  final c = history[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.check_circle_outline_rounded,
                        color: Baby.ok,
                      ),
                      title: LText.raw(
                        c.routineName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: LText(completionLabel(c)),
                      trailing: LIconButton(
                        tooltip: 'Remove completion',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () {
                          app.setRoutineCompletionDeleted(c, true);
                          showUndo(
                            context,
                            'Completion removed',
                            () => app.setRoutineCompletionDeleted(c, false),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

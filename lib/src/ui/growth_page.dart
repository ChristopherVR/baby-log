import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../growth.dart';
import '../routines.dart';
import 'baby_photo.dart';
import 'common.dart';
import 'sheets.dart';
import 'theme.dart';

String _measurement(double value) => NumberFormat('0.##').format(value);

String babyAge(BabyProfile baby, [DateTime? at]) {
  final birth = baby.dateOfBirth;
  if (birth == null) return tr('Every little moment matters');
  final date = at ?? DateTime.now();
  final months = ageInMonths(birth, date);
  if (months == 0) {
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(birth).inDays;
    return tr('$days days old');
  }
  return tr('$months months old');
}

void editBabyProfile(BuildContext context) => showSheet(
  context,
  BabyProfileEditor(initial: AppScope.of(context).activeBaby),
);

class BabyProfileEditor extends StatefulWidget {
  const BabyProfileEditor({super.key, required this.initial});
  final BabyProfile initial;
  @override
  State<BabyProfileEditor> createState() => _BabyProfileEditorState();
}

class _BabyProfileEditorState extends State<BabyProfileEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.initial.name);
  late DateTime? birth = widget.initial.dateOfBirth;
  late String? photo = widget.initial.photo;
  bool picking = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LText(
          'Baby’s profile',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const LText('A little introduction to your favourite person.'),
        const SizedBox(height: 24),
        Center(child: BabyPhoto(photo: photo, size: 108)),
        TextButton.icon(
          onPressed: picking
              ? null
              : () async {
                  setState(() => picking = true);
                  final value = await pickBabyPhoto(context);
                  if (mounted) {
                    setState(() {
                      if (value != null) photo = value;
                      picking = false;
                    });
                  }
                },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: LText(picking ? 'Opening photo…' : 'Choose profile photo'),
        ),
        if (photo != null)
          TextButton(
            onPressed: () => setState(() => photo = null),
            child: const LText('Remove photo'),
          ),
        LTextFormField(
          controller: name,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const LInputDecoration(labelText: 'Baby’s name'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter a name' : null,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cake_outlined, color: Baby.primary),
          title: const LText('Date of birth'),
          subtitle: LText(
            birth == null
                ? 'Add a birthday to see age and monthly milestones'
                : DateFormat.yMMMMd().format(birth!),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final now = DateTime.now();
            final value = await showDatePicker(
              context: context,
              initialDate: birth != null && !birth!.isAfter(now) ? birth! : now,
              firstDate: DateTime(1900),
              lastDate: now,
            );
            if (value != null && mounted) setState(() => birth = value);
          },
        ),
        if (birth != null)
          TextButton(
            onPressed: () => setState(() => birth = null),
            child: const LText('Remove date of birth'),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: picking
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  final app = AppScope.of(context);
                  if (birth != null &&
                      app.growthEntries.any((e) => e.date.isBefore(birth!))) {
                    showMessage(
                      context,
                      'The birthday must be on or before the first growth entry.',
                    );
                    return;
                  }
                  app.saveBabyProfile(
                    name: name.text,
                    dateOfBirth: birth,
                    photo: photo,
                  );
                  Navigator.pop(context);
                },
          child: const LText('Save profile'),
        ),
      ],
    ),
  );
}

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final baby = app.activeBaby;
    final entries = app.growthEntries;
    final now = DateTime.now();
    final thisMonth = entries.any(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final photos = entries
        .where((e) => e.photo != null)
        .toList()
        .reversed
        .toList();
    return PullToSync(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      'GROWING TOGETHER',
                      style: TextStyle(
                        letterSpacing: 2,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Baby.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const LText(
                      'Little by little.',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const LText('Their story, one month at a time.'),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Edit profile'),
                onPressed: () => editBabyProfile(context),
                icon: const Icon(Icons.manage_accounts_outlined),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: Baby.pillSoft,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  BabyPhoto(photo: baby.photo, size: 68),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText.raw(
                          baby.name.isEmpty ? tr('Baby') : baby.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        LText(babyAge(baby)),
                        if (baby.dateOfBirth != null)
                          LText(
                            DateFormat.yMMMd().format(baby.dateOfBirth!),
                            style: TextStyle(color: Baby.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => showSheet(context, GrowthEditor(baby: baby)),
            icon: const Icon(Icons.add_rounded),
            label: const LText('Add a moment'),
          ),
          const SizedBox(height: 10),
          LText(
            thisMonth
                ? 'This month is in your journal. You can add more anytime.'
                : 'A photo and a measurement each month make a lovely keepsake.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Baby.muted, fontSize: 13),
          ),
          if (photos.length >= 2) ...[
            const SectionTitle('Look how you’ve grown'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Comparison(entry: photos.first, label: 'Then'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Comparison(entry: photos.last, label: 'Now'),
                ),
              ],
            ),
          ],
          if (entries.any((e) => e.weightKg != null || e.heightCm != null)) ...[
            const SectionTitle('Growing at your own pace'),
            GrowthChart(entries: entries, weight: true),
            const SizedBox(height: 12),
            GrowthChart(entries: entries, weight: false),
            const SizedBox(height: 8),
            LText(
              'Your recorded measurements over time.',
              style: TextStyle(fontSize: 12, color: Baby.muted),
            ),
          ],
          const SectionTitle('The little moments'),
          if (entries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 48,
                      color: Baby.primary,
                    ),
                    const SizedBox(height: 16),
                    const LText(
                      'A story only you can tell',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const LText(
                      'Add your first photo, weight or height. Come back each month to see all those little changes.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < entries.length; i++) ...[
            if (i == 0 ||
                entries[i].date.month != entries[i - 1].date.month ||
                entries[i].date.year != entries[i - 1].date.year)
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 10),
                child: LText(
                  DateFormat.yMMMM().format(entries[i].date),
                  style: TextStyle(
                    color: Baby.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            _MomentCard(entry: entries[i], baby: baby),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.entry, required this.label});
  final GrowthEntry entry;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (_, c) =>
            BabyPhoto(photo: entry.photo, size: c.maxWidth, square: true),
      ),
      const SizedBox(height: 8),
      LText(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      LText(
        DateFormat.yMMMd().format(entry.date),
        style: TextStyle(color: Baby.muted, fontSize: 12),
      ),
    ],
  );
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.entry, required this.baby});
  final GrowthEntry entry;
  final BabyProfile baby;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => showSheet(context, GrowthEditor(baby: baby, initial: entry)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.photo != null) ...[
              BabyPhoto(photo: entry.photo, size: 90, square: true),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    baby.dateOfBirth == null
                        ? DateFormat.MMMd().format(entry.date)
                        : '${ageInMonths(baby.dateOfBirth!, entry.date)} months',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  LText(
                    DateFormat.yMMMd().format(entry.date),
                    style: TextStyle(color: Baby.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (entry.weightKg != null)
                        LText(
                          '${_measurement(entry.weightKg!)} kg',
                          style: TextStyle(
                            color: Baby.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (entry.heightCm != null)
                        LText(
                          '${_measurement(entry.heightCm!)} cm',
                          style: TextStyle(
                            color: Baby.feed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  if (entry.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LText.raw(entry.note),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class GrowthEditor extends StatefulWidget {
  const GrowthEditor({super.key, required this.baby, this.initial});
  final BabyProfile baby;
  final GrowthEntry? initial;
  @override
  State<GrowthEditor> createState() => _GrowthEditorState();
}

class _GrowthEditorState extends State<GrowthEditor> {
  final form = GlobalKey<FormState>();
  late final weight = TextEditingController(
    text: widget.initial?.weightKg?.toString() ?? '',
  );
  late final height = TextEditingController(
    text: widget.initial?.heightCm?.toString() ?? '',
  );
  late final note = TextEditingController(text: widget.initial?.note ?? '');
  late DateTime date =
      widget.initial?.date ?? DateUtils.dateOnly(DateTime.now());
  late String? photo = widget.initial?.photo;
  bool picking = false;
  @override
  void dispose() {
    weight.dispose();
    height.dispose();
    note.dispose();
    super.dispose();
  }

  double? number(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
  String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = number(value);
    return n == null || !validMeasurement(n)
        ? tr('Enter a number greater than zero')
        : null;
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LText(
          widget.initial == null ? 'A little moment' : 'Edit moment',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const LText('A photo, a measurement, a memory. Add any or all.'),
        const SizedBox(height: 20),
        if (photo != null)
          Center(child: BabyPhoto(photo: photo, size: 180, square: true)),
        OutlinedButton.icon(
          onPressed: picking
              ? null
              : () async {
                  setState(() => picking = true);
                  final value = await pickBabyPhoto(context);
                  if (mounted) {
                    setState(() {
                      if (value != null) photo = value;
                      picking = false;
                    });
                  }
                },
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: LText(
            picking
                ? 'Opening photo…'
                : photo == null
                ? 'Add a photo'
                : 'Change photo',
          ),
        ),
        if (photo != null)
          TextButton(
            onPressed: () => setState(() => photo = null),
            child: const LText('Remove photo'),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: LText(DateFormat.yMMMMd().format(date)),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final first = widget.baby.dateOfBirth ?? DateTime(1900);
            final chosen = await showDatePicker(
              context: context,
              initialDate: date.isBefore(first) ? first : date,
              firstDate: first,
              lastDate: DateTime.now(),
            );
            if (chosen != null && mounted) setState(() => date = chosen);
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LTextFormField(
                controller: weight,
                validator: validate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const LInputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LTextFormField(
                controller: height,
                validator: validate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const LInputDecoration(
                  labelText: 'Height',
                  suffixText: 'cm',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LTextFormField(
          controller: note,
          maxLines: 3,
          maxLength: 1000,
          decoration: const LInputDecoration(
            labelText: 'A memory (optional)',
            hintText: 'That first little smile…',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: picking
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  final app = AppScope.of(context);
                  final entry = GrowthEntry(
                    id: widget.initial?.id,
                    babyId: widget.baby.id,
                    date: date,
                    weightKg: number(weight.text),
                    heightCm: number(height.text),
                    photo: photo,
                    note: note.text.trim(),
                  );
                  if (!app.saveGrowth(entry)) {
                    showMessage(
                      context,
                      'Add a photo, measurement or memory with a date on or after birth.',
                    );
                    return;
                  }
                  Navigator.pop(context);
                },
          child: const LText('Save moment'),
        ),
        if (widget.initial != null)
          TextButton(
            onPressed: () async {
              final app = AppScope.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const LText('Delete this moment?'),
                  content: const LText(
                    'This removes its photo and measurements from the journal.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const LText('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const LText('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              app.setGrowthDeleted(widget.initial!, true);
              Navigator.pop(context);
              showUndo(
                context,
                'Moment deleted',
                () => app.setGrowthDeleted(widget.initial!, false),
              );
            },
            child: LText('Delete moment', style: TextStyle(color: Baby.error)),
          ),
      ],
    ),
  );
}

class GrowthChart extends StatelessWidget {
  const GrowthChart({super.key, required this.entries, required this.weight});
  final List<GrowthEntry> entries;
  final bool weight;
  @override
  Widget build(BuildContext context) {
    double? value(GrowthEntry e) => weight ? e.weightKg : e.heightCm;
    final points = entries.where((e) => value(e) != null).toList()
      ..sort((a, b) {
        final day = a.date.compareTo(b.date);
        return day != 0 ? day : a.updatedAt.compareTo(b.updatedAt);
      });
    if (points.isEmpty) return const SizedBox.shrink();
    final unit = weight ? 'kg' : 'cm';
    final color = weight ? Baby.primary : Baby.feed;
    final change = value(points.last)! - value(points.first)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LText(
                    weight ? 'Weight' : 'Height',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
                LText(
                  '${_measurement(value(points.last)!)} $unit',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (points.length > 1) ...[
              LText(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} $unit ${tr('since first entry')}',
                style: TextStyle(color: Baby.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: points
                    .map(
                      (e) =>
                          '${DateFormat.yMMMd().format(e.date)}: ${value(e)} $unit',
                    )
                    .join(', '),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _GrowthPainter(
                      points: [
                        for (final e in points)
                          (e.date.millisecondsSinceEpoch.toDouble(), value(e)!),
                      ],
                      color: color,
                      grid: Baby.line,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LText(
                    DateFormat.yMMMd().format(points.first.date),
                    style: TextStyle(fontSize: 11, color: Baby.muted),
                  ),
                  LText(
                    DateFormat.yMMMd().format(points.last.date),
                    style: TextStyle(fontSize: 11, color: Baby.muted),
                  ),
                ],
              ),
            ] else
              LText(
                'Add another measurement to see the changes.',
                style: TextStyle(color: Baby.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.points,
    required this.color,
    required this.grid,
  });
  final List<(double, double)> points;
  final Color color;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.$2).toList()..sort();
    final minY = values.first;
    final rangeY = values.last - minY;
    final rangeX = points.last.$1 - points.first.$1;
    const left = 42.0;
    final width = size.width - left - 8;
    final height = size.height - 28;
    for (var i = 0; i <= 2; i++) {
      final y = 8 + height * i / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - 8, y),
        Paint()..color = grid,
      );
      final label = (minY + (rangeY == 0 ? 1 : rangeY) * (1 - i / 2))
          .toStringAsFixed(1);
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y - 6));
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x =
          left +
          (rangeX == 0 ? .5 : (points[i].$1 - points.first.$1) / rangeX) *
              width;
      final y =
          8 + height * (1 - (points[i].$2 - minY) / (rangeY == 0 ? 1 : rangeY));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GrowthPainter old) =>
      old.points != points || old.color != color || old.grid != grid;
}

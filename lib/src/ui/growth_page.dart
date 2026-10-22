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

void editBabyProfile(BuildContext context, [BabyProfile? baby]) => showSheet(
  context,
  BabyProfileEditor(initial: baby ?? AppScope.of(context).activeBaby),
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
                      app
                          .growthEntriesFor(widget.initial.id)
                          .any((e) => e.date.isBefore(birth!))) {
                    showMessage(
                      context,
                      'The birthday must be on or before the first growth entry.',
                    );
                    return;
                  }
                  app.saveBabyProfile(
                    id: widget.initial.id,
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

Glyph _iconGlyph(IconData icon) =>
    (size, color) => Icon(icon, size: size, color: color);

/// Newest entry (by date, then edit time) that has a value, plus the one
/// before it, so the summary can say how much changed.
(GrowthEntry, GrowthEntry?)? _latestTwo(
  List<GrowthEntry> entries,
  double? Function(GrowthEntry) value,
) {
  final list = entries.where((e) => value(e) != null).toList()
    ..sort((a, b) {
      final day = b.date.compareTo(a.date);
      return day != 0 ? day : b.updatedAt.compareTo(a.updatedAt);
    });
  if (list.isEmpty) return null;
  return (list.first, list.length > 1 ? list[1] : null);
}

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final baby = app.activeBaby;
    final entries = app.growthEntries;
    final photos = entries
        .where((e) => e.photo != null)
        .toList()
        .reversed
        .toList();
    final weight = _latestTwo(entries, (e) => e.weightKg);
    final height = _latestTwo(entries, (e) => e.heightCm);
    return PullToSync(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Card(
            color: Baby.pillSoft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 6, 16),
              child: Row(
                children: [
                  BabyPhoto(photo: baby.photo, size: 64),
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
                          LText.raw(
                            DateFormat.yMMMd().format(baby.dateOfBirth!),
                            style: TextStyle(color: Baby.muted, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Edit profile'),
                    onPressed: () => editBabyProfile(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showSheet(context, GrowthEditor(baby: baby)),
            icon: const Icon(Icons.add_rounded),
            label: const LText('Add a moment'),
          ),
          const SizedBox(height: 8),
          LText(
            'Save a weight, height, photo or memory. Any one is enough.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Baby.muted, fontSize: 13),
          ),
          if (entries.isEmpty)
            const _EmptyGrowth()
          else ...[
            const SectionTitle('Latest measurements'),
            LayoutBuilder(
              builder: (context, c) {
                final stacked =
                    c.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final tiles = [
                  _StatTile(
                    label: 'Weight',
                    unit: 'kg',
                    icon: Icons.monitor_weight_outlined,
                    color: Baby.primary,
                    soft: Baby.pillSoft,
                    latest: weight,
                    value: (e) => e.weightKg,
                  ),
                  _StatTile(
                    label: 'Height',
                    unit: 'cm',
                    icon: Icons.straighten_rounded,
                    color: Baby.feed,
                    soft: Baby.feedSoft,
                    latest: height,
                    value: (e) => e.heightCm,
                  ),
                ];
                return stacked
                    ? Column(
                        children: [
                          tiles[0],
                          const SizedBox(height: 12),
                          tiles[1],
                        ],
                      )
                    : IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: tiles[0]),
                            const SizedBox(width: 12),
                            Expanded(child: tiles[1]),
                          ],
                        ),
                      );
              },
            ),
          ],
          if (_hasTrend(entries)) ...[
            const SectionTitle('Growth over time'),
            GrowthChart(entries: entries, weight: true),
            GrowthChart(entries: entries, weight: false),
          ],
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
          if (entries.isNotEmpty) ...[
            const SectionTitle('Journal'),
            LText(
              'Newest first. Tap an entry to edit it.',
              style: TextStyle(color: Baby.muted, fontSize: 13),
            ),
          ],
          for (var i = 0; i < entries.length; i++) ...[
            if (i == 0 ||
                entries[i].date.month != entries[i - 1].date.month ||
                entries[i].date.year != entries[i - 1].date.year)
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 10),
                child: LText.raw(
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

  /// A trend line needs at least two measurements of the same kind.
  static bool _hasTrend(List<GrowthEntry> entries) =>
      entries.where((e) => e.weightKg != null).length > 1 ||
      entries.where((e) => e.heightCm != null).length > 1;
}

class _EmptyGrowth extends StatelessWidget {
  const _EmptyGrowth();
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          IconBubble(
            glyph: _iconGlyph(Icons.auto_stories_outlined),
            color: Baby.pillSoft,
            iconColor: Baby.primary,
            size: 64,
          ),
          const SizedBox(height: 16),
          const LText(
            'Track how your baby grows',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const LText(
            'Add a weight, height or photo now and then, for example at each clinic visit. You will see the latest numbers, a chart and a keepsake journal here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.soft,
    required this.latest,
    required this.value,
  });
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final Color soft;
  final (GrowthEntry, GrowthEntry?)? latest;
  final double? Function(GrowthEntry) value;
  @override
  Widget build(BuildContext context) {
    final l = latest;
    String? change;
    if (l != null && l.$2 != null) {
      final d = value(l.$1)! - value(l.$2!)!;
      change =
          '${d >= 0 ? '+' : '−'}${_measurement(d.abs())} $unit ${tr('since')} ${DateFormat.MMMd().format(l.$2!.date)}';
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBubble(
                  glyph: _iconGlyph(icon),
                  color: soft,
                  iconColor: color,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LText(
                    label,
                    style: TextStyle(
                      color: Baby.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (l == null)
              LText(
                'Not measured yet',
                style: TextStyle(
                  color: Baby.muted,
                  fontWeight: FontWeight.w700,
                ),
              )
            else ...[
              LText.raw(
                '${_measurement(value(l.$1)!)} $unit',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              LText.raw(
                DateFormat.yMMMd().format(l.$1.date),
                style: TextStyle(color: Baby.muted, fontSize: 12),
              ),
              if (change != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LText.raw(
                    change,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ],
        ),
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
                  LText.raw(
                    baby.dateOfBirth == null
                        ? DateFormat.yMMMd().format(entry.date)
                        : babyAge(baby, entry.date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (baby.dateOfBirth != null)
                    LText.raw(
                      DateFormat.yMMMd().format(entry.date),
                      style: TextStyle(color: Baby.muted, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (entry.weightKg != null)
                        LText.raw(
                          '${_measurement(entry.weightKg!)} kg',
                          style: TextStyle(
                            color: Baby.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (entry.heightCm != null)
                        LText.raw(
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
        const LText(
          'Pick the date, then add a measurement, a photo or a memory. Any one is enough.',
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              weight ? 'Weight' : 'Height',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            if (points.length > 1) ...[
              LText.raw(
                '${_measurement(value(points.first)!)} → ${_measurement(value(points.last)!)} $unit (${change >= 0 ? '+' : '−'}${_measurement(change.abs())} ${tr('since first entry')})',
                style: TextStyle(color: Baby.muted, fontSize: 13),
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

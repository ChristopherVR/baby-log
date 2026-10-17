import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'theme.dart';

Future<void> showSheet(BuildContext context, Widget child) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => Padding(
        // Above the keyboard when open, otherwise above the navigation buttons.
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 +
              max(
                MediaQuery.viewInsetsOf(c).bottom,
                MediaQuery.viewPaddingOf(c).bottom,
              ),
        ),
        child: SingleChildScrollView(child: child),
      ),
    );

/// Opens the right editor for an existing entry.
Future<void> editEntry(BuildContext context, Entry e) =>
    showSheet(context, switch (e.type) {
      EntryType.feed => FeedSheet(initial: e),
      EntryType.nappy => NappySheet(initial: e),
      EntryType.pill => PillDoseSheet(initial: e),
    });

class _DeleteButton extends StatelessWidget {
  const _DeleteButton(this.entry);
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: Baby.error),
      icon: const Icon(Icons.delete_outline_rounded),
      label: const LText('Delete'),
      onPressed: () {
        app.deleteEntry(entry);
        Navigator.pop(context);
        showUndo(context, 'Deleted', () => app.restoreEntry(entry));
      },
    );
  }
}

/// If [initial] was changed on the other phone while it was open here, asks
/// before saving over that change.
Future<bool> okToOverwrite(
  BuildContext context,
  AppState app,
  Syncable? initial,
) async {
  if (initial == null || !app.changedSince(initial)) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const LText('Changed on the other phone'),
      content: const LText(
        'This was changed on the other phone while you had it open. Save your version over it?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const LText('Save mine'),
        ),
      ],
    ),
  );
  return ok == true;
}

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 8),
  child: LText(text, style: const TextStyle(fontWeight: FontWeight.w800)),
);

class FeedSheet extends StatefulWidget {
  const FeedSheet({super.key, this.initial});
  final Entry? initial;

  @override
  State<FeedSheet> createState() => _FeedSheetState();
}

class _FeedSheetState extends State<FeedSheet> {
  FeedSide? side;
  DateTime? time;
  int? minutes;
  int? ml;

  static const _minutes = [5, 10, 15, 20, 25, 30, 45, 60];
  static const _ml = [30, 60, 90, 120, 150, 180, 210];

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    if (e != null) {
      side = e.side;
      time = e.time;
      minutes = e.durationMin;
      ml = e.amountMl;
    }
  }

  Glyph _glyph(FeedSide s) => switch (s) {
    FeedSide.left => Glyphs.left,
    FeedSide.right => Glyphs.right,
    FeedSide.both => Glyphs.bothSides,
    FeedSide.bottle => Glyphs.bottle,
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final editing = widget.initial != null;
    final suggested = editing ? null : app.suggestedSide;
    final s = side ?? suggested ?? FeedSide.left;
    final bottle = s == FeedSide.bottle;

    Future<void> save() async {
      if (!await okToOverwrite(context, app, widget.initial) ||
          !context.mounted) {
        return;
      }
      final entry = Entry(
        id: widget.initial?.id,
        type: EntryType.feed,
        time: time ?? DateTime.now(),
        side: s,
        durationMin: bottle ? null : minutes,
        amountMl: bottle ? ml : null,
      );
      app.addEntry(entry);
      Navigator.pop(context);
      if (!editing) {
        showUndo(context, 'Feed saved', () => app.deleteEntry(entry));
      }
    }

    ChoiceChip chip(
      String label,
      bool selected,
      ValueChanged<bool> onSelected,
    ) => ChoiceChip(
      label: LText(label),
      selected: selected,
      selectedColor: Baby.feedSoft,
      onSelected: onSelected,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: editing ? 'Edit feed' : 'Feed',
          subtitle: editing
              ? null
              : 'Pick a side, then Save or start the timer',
          glyph: Glyphs.feed,
          soft: Baby.feedSoft,
          strong: Baby.feed,
        ),
        Row(
          children: [
            for (final f in FeedSide.values) ...[
              Expanded(
                child: OptionTile(
                  glyph: _glyph(f),
                  glyphColor: Baby.feed,
                  label: sideLabel(f),
                  badge: f == suggested ? 'Next' : null,
                  selected: f == s,
                  color: Baby.feedSoft,
                  onTap: () => setState(() => side = f),
                ),
              ),
              if (f != FeedSide.bottle) const SizedBox(width: 8),
            ],
          ],
        ),
        _label(bottle ? 'Amount (optional)' : 'How long (optional)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (bottle)
              for (final v in _ml)
                chip(
                  '$v ml',
                  ml == v,
                  (on) => setState(() => ml = on ? v : null),
                )
            else ...[
              for (final v in _minutes)
                chip(
                  '$v min',
                  minutes == v,
                  (on) => setState(() => minutes = on ? v : null),
                ),
              if (minutes != null && !_minutes.contains(minutes))
                chip(
                  '$minutes min',
                  true,
                  (_) => setState(() => minutes = null),
                ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        WhenField(value: time, onChanged: (t) => setState(() => time = t)),
        const SizedBox(height: 20),
        Row(
          children: [
            if (editing) ...[_DeleteButton(widget.initial!), const Spacer()],
            if (!editing && !bottle && app.timerStart == null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.timer_outlined),
                  label: const LText('Start timer'),
                  onPressed: () {
                    app.startFeedTimer(s);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Baby.feed,
                  foregroundColor: Baby.onPrimary,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const LText('Save'),
                onPressed: save,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NappySheet extends StatefulWidget {
  const NappySheet({super.key, this.initial});
  final Entry? initial;

  @override
  State<NappySheet> createState() => _NappySheetState();
}

class _NappySheetState extends State<NappySheet> {
  DateTime? time;

  @override
  void initState() {
    super.initState();
    time = widget.initial?.time;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final initial = widget.initial;

    Future<void> pick(NappyKind kind) async {
      if (!await okToOverwrite(context, app, initial) || !context.mounted) {
        return;
      }
      final entry = Entry(
        id: initial?.id,
        type: EntryType.nappy,
        time: time ?? DateTime.now(),
        nappy: kind,
      );
      app.addEntry(entry);
      Navigator.pop(context);
      if (initial == null) {
        showUndo(
          context,
          'Nappy saved: ${nappyLabel(kind)}',
          () => app.deleteEntry(entry),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: initial == null ? 'Nappy change' : 'Edit nappy',
          subtitle: 'Tap one to save',
          glyph: Glyphs.nappy,
          soft: Baby.nappySoft,
          strong: Baby.nappy,
        ),
        Row(
          children: [
            for (final k in NappyKind.values) ...[
              Expanded(
                child: Builder(
                  builder: (context) {
                    final look = nappyLook(k);
                    return Material(
                      color: look.soft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                          color: initial?.nappy == k
                              ? Baby.ink
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => pick(k),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          child: Column(
                            children: [
                              IconBubble(
                                glyph: look.glyph,
                                color: Baby.card,
                                iconColor: look.strong,
                                size: 60,
                              ),
                              const SizedBox(height: 10),
                              LText(
                                nappyLabel(k),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (k != NappyKind.both) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 18),
        WhenField(value: time, onChanged: (t) => setState(() => time = t)),
        if (initial != null)
          Align(alignment: Alignment.centerLeft, child: _DeleteButton(initial)),
      ],
    );
  }
}

class PillDoseSheet extends StatefulWidget {
  const PillDoseSheet({super.key, required this.initial});
  final Entry initial;

  @override
  State<PillDoseSheet> createState() => _PillDoseSheetState();
}

class _PillDoseSheetState extends State<PillDoseSheet> {
  late DateTime? time = widget.initial.time;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = widget.initial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: e.medName ?? 'Pill',
          subtitle: 'Edit when it was taken',
          glyph: Glyphs.pill,
        ),
        WhenField(value: time, onChanged: (t) => setState(() => time = t)),
        const SizedBox(height: 20),
        Row(
          children: [
            _DeleteButton(e),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                if (!await okToOverwrite(context, app, e) || !context.mounted) {
                  return;
                }
                app.addEntry(
                  Entry(
                    id: e.id,
                    type: EntryType.pill,
                    time: time ?? DateTime.now(),
                    medId: e.medId,
                    medName: e.medName,
                  ),
                );
                Navigator.pop(context);
              },
              child: const LText('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'theme.dart';

Future<void> showSheet(BuildContext context, Widget child) async {
  if ((child is FeedSheet && child.initial == null) ||
      (child is NappySheet && child.initial == null)) {
    final app = AppScope.of(context);
    final nap = app.activeSleep;
    if (nap != null) {
      final finished = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const LText('Has the nap finished?'),
          content: const LText('End the nap now, or keep tracking sleep.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const LText('Still sleeping'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const LText('End nap'),
            ),
          ],
        ),
      );
      if (!context.mounted || finished == null) return;
      if (finished) app.endSleep(nap);
    }
  }
  if (!context.mounted) return;
  return _openSheet(context, child);
}

Future<void> _openSheet(BuildContext context, Widget child) {
  final editing = switch (child) {
    FeedSheet(:final initial) => initial != null,
    NappySheet(:final initial) => initial != null,
    PillDoseSheet() => true,
    SleepSheet(:final initial) => initial != null,
    PumpSheet(:final initial) => initial != null,
    _ => false,
  };
  // The sheet may never be taller than the window (minus a small gap at the
  // top): the content scrolls inside it instead. This matters on short desktop
  // windows, large text and with the keyboard open.
  Widget builder(BuildContext c) {
    final media = MediaQuery.of(c);
    final maxHeight = max(200.0, media.size.height - media.padding.top - 16);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + max(media.viewInsets.bottom, media.viewPadding.bottom),
        ),
        child: _SheetScroll(child: child),
      ),
    );
  }

  // Wide windows get a centred dialog: always fully visible, scrolls inside.
  if (Desktop.of(context)) return showSheetDialog(context, child);
  if (editing) {
    final navigator = Navigator.of(context);
    return Navigator.of(context).push<void>(
      _EditSheetRoute(
        builder: builder,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        barrierLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: builder,
  );
}

/// Shows [child] (a sheet's content) as a centred dialog, as sheets are shown
/// on desktop. With [scroll] the content is padded and scrolls inside the
/// dialog; without, [child] handles that itself. Taps outside use maybePop,
/// so editors can still ask before discarding changes.
Future<void> showSheetDialog(
  BuildContext context,
  Widget child, {
  bool scroll = true,
  double maxWidth = 560,
}) => showDialog<void>(
  context: context,
  useRootNavigator: true,
  builder: (c) {
    final size = MediaQuery.sizeOf(c);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: max(200.0, size.height - 48),
        ),
        child: scroll
            ? _SheetScroll(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: child,
                ),
              )
            : child,
      ),
    );
  },
);

/// A bottom sheet on the phone, a centred dialog on desktop, for content that
/// pads and scrolls itself.
Future<void> showAdaptiveSheet(BuildContext context, WidgetBuilder builder) =>
    Desktop.of(context)
    ? showSheetDialog(context, Builder(builder: builder), scroll: false)
    : showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: builder,
      );

/// Scrolls the sheet's content, with a scrollbar that also works with a mouse.
class _SheetScroll extends StatefulWidget {
  const _SheetScroll({required this.child});
  final Widget child;

  @override
  State<_SheetScroll> createState() => _SheetScrollState();
}

class _SheetScrollState extends State<_SheetScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    child: SingleChildScrollView(controller: _controller, child: widget.child),
  );
}

// Barrier taps must use maybePop so the editor can confirm unsaved changes.
// Native sheet dragging pops directly; the editor supplies a guarded handle.
class _EditSheetRoute extends ModalBottomSheetRoute<void> {
  _EditSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
  }) : super(
         isScrollControlled: true,
         enableDrag: false,
         showDragHandle: false,
         useSafeArea: true,
         constraints: const BoxConstraints(maxWidth: 560),
       );

  @override
  Widget buildModalBarrier() => AnimatedModalBarrier(
    color: animation!.drive(
      ColorTween(
        begin: barrierColor.withValues(alpha: 0),
        end: barrierColor,
      ).chain(CurveTween(curve: barrierCurve)),
    ),
    semanticsLabel: barrierLabel,
    onDismiss: () => navigator?.maybePop(),
  );
}

class _EditGuard extends StatefulWidget {
  const _EditGuard({required this.dirty, required this.child});
  final bool dirty;
  final Widget child;

  @override
  State<_EditGuard> createState() => _EditGuardState();
}

class _EditGuardState extends State<_EditGuard> {
  bool prompting = false;

  Future<void> confirmDiscard() async {
    if (prompting) return;
    prompting = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const LText('Discard changes?'),
        content: const LText('Your changes have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const LText('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const LText('Discard'),
          ),
        ],
      ),
    );
    prompting = false;
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) confirmDiscard();
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dialogs on desktop have no drag handle.
        if (!Desktop.of(context))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 0) {
                Navigator.maybePop(context);
              }
            },
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    ),
  );
}

/// Opens the right editor for an existing entry.
Future<void> editEntry(BuildContext context, Entry e) =>
    showSheet(context, switch (e.type) {
      EntryType.sleep => SleepSheet(initial: e),
      EntryType.feed => FeedSheet(initial: e),
      EntryType.nappy => NappySheet(initial: e),
      EntryType.pill => PillDoseSheet(initial: e),
      EntryType.pump => PumpSheet(initial: e),
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

/// Asks for an amount in ml that is not one of the quick choices.
Future<int?> askMl(BuildContext context, int? initial) {
  final field = TextEditingController(text: initial?.toString() ?? '');
  int? value() {
    final v = int.tryParse(field.text.trim());
    return v == null || v <= 0 || v > 1000 ? null : v;
  }

  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const LText('How much?'),
      content: TextField(
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const LInputDecoration(labelText: 'Amount', suffixText: 'ml'),
        onSubmitted: (_) => Navigator.pop(ctx, value()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, value()),
          child: const LText('Done'),
        ),
      ],
    ),
  );
}

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
    final s =
        side ??
        suggested ??
        (app.bottleFirst ? FeedSide.bottle : FeedSide.left);
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

    final initial = widget.initial;
    final dirty =
        initial != null &&
        (s != initial.side ||
            time != initial.time ||
            (bottle ? ml != initial.amountMl : minutes != initial.durationMin));
    final content = Column(
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
            if (bottle) ...[
              for (final v in _ml)
                chip(
                  '$v ml',
                  ml == v,
                  (on) => setState(() => ml = on ? v : null),
                ),
              if (ml != null && !_ml.contains(ml))
                chip('$ml ml', true, (_) => setState(() => ml = null)),
              ActionChip(
                avatar: const Icon(Icons.edit_rounded, size: 18),
                label: const LText('Other…'),
                onPressed: () async {
                  final v = await askMl(context, ml);
                  if (v != null) setState(() => ml = v);
                },
              ),
            ] else ...[
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
                label: LText(editing ? 'Update' : 'Save'),
                onPressed: editing && !dirty ? null : save,
              ),
            ),
          ],
        ),
      ],
    );
    return editing ? _EditGuard(dirty: dirty, child: content) : content;
  }
}

/// Logs or edits a pumping session. [draft] pre-fills a new one, e.g. from
/// a session just finished on the pumps; the amounts stay editable since a
/// pump's own reading can be off.
class PumpSheet extends StatefulWidget {
  const PumpSheet({super.key, this.initial, this.draft});
  final Entry? initial;
  final Entry? draft;

  @override
  State<PumpSheet> createState() => _PumpSheetState();
}

class _PumpSheetState extends State<PumpSheet> {
  late FeedSide side;
  DateTime? time;
  int? minutes;
  final _total = TextEditingController();
  final _left = TextEditingController();
  final _right = TextEditingController();

  static const _minutes = [10, 15, 20, 25, 30];

  @override
  void initState() {
    super.initState();
    final e = widget.initial ?? widget.draft;
    side = e?.side ?? FeedSide.both;
    time = e?.time;
    minutes = e?.durationMin;
    if (e?.leftMl != null) _left.text = '${e!.leftMl}';
    if (e?.rightMl != null) _right.text = '${e!.rightMl}';
    if (e?.amountMl != null) _total.text = '${e!.amountMl}';
  }

  @override
  void dispose() {
    _total.dispose();
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  int? _ml(TextEditingController c) => int.tryParse(c.text.trim());

  /// (total, left, right) as they would be saved.
  (int?, int?, int?) get _amounts {
    if (side != FeedSide.both) return (_ml(_total), null, null);
    final l = _ml(_left), r = _ml(_right);
    if (l == null && r == null) return (_ml(_total), null, null);
    return ((l ?? 0) + (r ?? 0), l, r);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final editing = widget.initial != null;
    final (total, left, right) = _amounts;

    Future<void> save() async {
      if (!await okToOverwrite(context, app, widget.initial) ||
          !context.mounted) {
        return;
      }
      final start = time ?? widget.draft?.time ?? DateTime.now();
      final entry = Entry(
        id: widget.initial?.id,
        type: EntryType.pump,
        time: start,
        endTime: minutes == null
            ? null
            : start.add(Duration(minutes: minutes!)),
        side: side,
        durationMin: minutes,
        amountMl: total,
        leftMl: left,
        rightMl: right,
      );
      app.addEntry(entry);
      Navigator.pop(context);
      if (!editing) {
        showUndo(context, 'Pumping saved', () => app.deleteEntry(entry));
      }
    }

    final initial = widget.initial;
    final dirty =
        initial != null &&
        (side != initial.side ||
            time != initial.time ||
            minutes != initial.durationMin ||
            total != initial.amountMl ||
            left != initial.leftMl ||
            right != initial.rightMl);

    Widget mlField(TextEditingController c, String label) => TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: LInputDecoration(labelText: label, suffixText: 'ml'),
      onChanged: (_) => setState(() {}),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: editing ? 'Edit pumping' : 'Pumping',
          glyph: Glyphs.pump,
          soft: Baby.pumpSoft,
          strong: Baby.pump,
        ),
        Row(
          children: [
            for (final f in const [
              FeedSide.left,
              FeedSide.both,
              FeedSide.right,
            ]) ...[
              Expanded(
                child: OptionTile(
                  glyph: switch (f) {
                    FeedSide.left => Glyphs.left,
                    FeedSide.right => Glyphs.right,
                    _ => Glyphs.bothSides,
                  },
                  glyphColor: Baby.pump,
                  label: sideLabel(f),
                  selected: f == side,
                  color: Baby.pumpSoft,
                  onTap: () => setState(() => side = f),
                ),
              ),
              if (f != FeedSide.right) const SizedBox(width: 8),
            ],
          ],
        ),
        _label('How much'),
        if (side == FeedSide.both)
          Row(
            children: [
              Expanded(child: mlField(_left, 'Left')),
              const SizedBox(width: 12),
              Expanded(child: mlField(_right, 'Right')),
            ],
          )
        else
          mlField(_total, 'Amount'),
        _label('How long (optional)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in [
              ..._minutes,
              if (minutes != null && !_minutes.contains(minutes)) minutes!,
            ])
              ChoiceChip(
                label: LText('$v min'),
                selected: minutes == v,
                selectedColor: Baby.pumpSoft,
                onSelected: (on) => setState(() => minutes = on ? v : null),
              ),
          ],
        ),
        const SizedBox(height: 14),
        WhenField(value: time, onChanged: (t) => setState(() => time = t)),
        const SizedBox(height: 20),
        Row(
          children: [
            if (editing) ...[_DeleteButton(widget.initial!), const Spacer()],
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Baby.pump,
                  foregroundColor: Baby.onPrimary,
                ),
                icon: const Icon(Icons.check_rounded),
                label: LText(editing ? 'Update' : 'Save'),
                onPressed: editing && !dirty ? null : save,
              ),
            ),
          ],
        ),
      ],
    );
    return editing ? _EditGuard(dirty: dirty, child: content) : content;
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
  NappyKind? kind;

  @override
  void initState() {
    super.initState();
    time = widget.initial?.time;
    kind = widget.initial?.nappy ?? NappyKind.pee;
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

    final dirty =
        initial != null && (kind != initial.nappy || time != initial.time);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: initial == null ? 'Nappy change' : 'Edit nappy',
          subtitle: initial == null ? 'Tap one to save' : null,
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
                          color: initial != null && kind == k
                              ? Baby.ink
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          if (initial == null) {
                            pick(k);
                          } else {
                            setState(() => kind = k);
                          }
                        },
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
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                _DeleteButton(initial),
                const Spacer(),
                FilledButton(
                  onPressed: dirty ? () => pick(kind!) : null,
                  child: const LText('Update'),
                ),
              ],
            ),
          ),
      ],
    );
    return initial != null ? _EditGuard(dirty: dirty, child: content) : content;
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
    final dirty = time != e.time;
    return _EditGuard(
      dirty: dirty,
      child: Column(
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
                onPressed: !dirty
                    ? null
                    : () async {
                        if (!await okToOverwrite(context, app, e) ||
                            !context.mounted) {
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
                child: const LText('Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SleepSheet extends StatefulWidget {
  const SleepSheet({super.key, this.initial});
  final Entry? initial;

  @override
  State<SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends State<SleepSheet> {
  late DateTime start = widget.initial?.time ?? DateTime.now();
  late DateTime? end = widget.initial?.endTime;
  String? error;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final initial = widget.initial;
    final dirty =
        initial != null && (start != initial.time || end != initial.endTime);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: initial == null ? 'Put down for a nap' : 'Edit sleep',
          glyph: Glyphs.sleep,
          soft: Baby.pillSoft,
          strong: Baby.pill,
        ),
        const LText('Nap started'),
        WhenField(
          value: start,
          onChanged: (t) => setState(() => start = t ?? start),
        ),
        if (end != null) ...[
          const SizedBox(height: 16),
          const LText('Nap ended'),
          WhenField(value: end, onChanged: (t) => setState(() => end = t)),
        ],
        if (error != null) LText(error!, style: TextStyle(color: Baby.error)),
        const SizedBox(height: 20),
        Row(
          children: [
            if (initial != null) _DeleteButton(initial),
            const Spacer(),
            FilledButton(
              onPressed: initial != null && !dirty
                  ? null
                  : () async {
                      if (start.isAfter(DateTime.now()) ||
                          (end != null &&
                              (end!.isBefore(start) ||
                                  end!.isAfter(DateTime.now())))) {
                        setState(
                          () => error =
                              'Choose valid start and end times in the past',
                        );
                        return;
                      }
                      if (!await okToOverwrite(context, app, initial) ||
                          !context.mounted) {
                        return;
                      }
                      if (initial == null) {
                        if (!app.startSleep(time: start)) {
                          setState(
                            () => error = 'A nap is already being tracked',
                          );
                          return;
                        }
                      } else {
                        app.addEntry(
                          Entry(
                            id: initial.id,
                            type: EntryType.sleep,
                            time: start,
                            endTime: end,
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
              child: LText(initial == null ? 'Start nap' : 'Update'),
            ),
          ],
        ),
      ],
    );
    return initial == null ? content : _EditGuard(dirty: dirty, child: content);
  }
}

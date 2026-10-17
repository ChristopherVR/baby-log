import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../store.dart';
import 'theme.dart';
import '../localization.dart';
export '../localization.dart';

/// Gives every widget below access to [AppState] and rebuilds them on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

// ------------------------------------------------------------------ formatting

final _hm = DateFormat.Hm();
DateFormat get _longDay => DateFormat('EEEE d MMMM');

String hm(DateTime t) => _hm.format(t);

String minutesOfDay(int m) => hm(DateTime(2000, 1, 1, m ~/ 60, m % 60));

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return tr('Today');
  if (sameDay(d, DateTime(now.year, now.month, now.day - 1))) {
    return tr('Yesterday');
  }
  return _longDay.format(d);
}

String whenLabel(DateTime t) =>
    sameDay(t, DateTime.now()) ? hm(t) : '${dayLabel(t)} ${hm(t)}';

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.isNegative) return tr('in ${duration(-d)}');
  if (d.inMinutes < 1) return tr('just now');
  return tr('${duration(d)} ago');
}

String duration(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 48) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inDays} days';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return tr('Night shift');
  if (h < 12) return tr('Good morning');
  if (h < 18) return tr('Good afternoon');
  return tr('Good evening');
}

String sideLabel(FeedSide s) => switch (s) {
  FeedSide.left => tr('Left'),
  FeedSide.right => tr('Right'),
  FeedSide.both => tr('Both'),
  FeedSide.bottle => tr('Bottle'),
};

String nappyLabel(NappyKind k) => switch (k) {
  NappyKind.pee => tr('Pee'),
  NappyKind.poo => tr('Poo'),
  NappyKind.both => tr('Pee + Poo'),
};

String entryTitle(Entry e) => switch (e.type) {
  EntryType.feed => switch (e.side) {
    null => 'Feed',
    FeedSide.bottle => 'Bottle feed',
    final side => 'Feed · ${sideLabel(side)}',
  },
  EntryType.nappy => 'Nappy · ${nappyLabel(e.nappy ?? NappyKind.pee)}',
  EntryType.pill => e.medName ?? 'Pill',
};

String? entryDetail(Entry e) {
  final parts = [
    if (e.durationMin != null) '${e.durationMin} min',
    if (e.amountMl != null) '${e.amountMl} ml',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

// ------------------------------------------------------------------ icons

/// Draws an icon at a size and colour. Most are Material Symbols; there is no
/// poo symbol, so that one is painted.
typedef Glyph = Widget Function(double size, Color color);

Glyph _sym(IconData icon) =>
    (size, color) => Icon(icon, size: size, color: color, fill: 1);

abstract final class Glyphs {
  static final feed = _sym(Symbols.breastfeeding_rounded);
  static final bottle = _sym(Symbols.water_bottle_rounded);
  static final nappy = _sym(Symbols.baby_changing_station_rounded);
  static final pee = _sym(Symbols.water_drop_rounded);
  static final pill = _sym(Symbols.pill_rounded);
  static final alarm = _sym(Symbols.alarm_rounded);
  static final left = _sym(Symbols.arrow_back_rounded);
  static final right = _sym(Symbols.arrow_forward_rounded);
  static final bothSides = _sym(Symbols.sync_alt_rounded);
  static final baby = _sym(Symbols.child_care_rounded);
  static final light = _sym(Symbols.light_mode_rounded);
  static final dark = _sym(Symbols.dark_mode_rounded);
  static final auto = _sym(Symbols.brightness_auto_rounded);
  static final wifi = _sym(Symbols.wifi_rounded);
  static final heart = _sym(Symbols.favorite_rounded);

  static Widget poo(double size, Color color) =>
      CustomPaint(size: Size.square(size), painter: _PooPainter(color));

  /// Pee and poo together: a drop and a poo, overlapping.
  static Widget peeAndPoo(double size, Color color) => SizedBox.square(
    dimension: size,
    child: Stack(
      children: [
        Positioned(left: 0, top: 0, child: pee(size * 0.62, Baby.pee)),
        Positioned(right: 0, bottom: 0, child: poo(size * 0.66, Baby.poo)),
      ],
    ),
  );
}

class _PooPainter extends CustomPainter {
  _PooPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..color = color;
    RRect tier(double l, double t, double r, double b, double radius) =>
        RRect.fromLTRBR(
          l * s,
          t * s,
          r * s,
          b * s,
          Radius.circular(radius * s),
        );
    canvas
      ..drawRRect(tier(0.10, 0.62, 0.90, 0.90, 0.14), paint)
      ..drawRRect(tier(0.20, 0.42, 0.80, 0.68, 0.13), paint)
      ..drawRRect(tier(0.32, 0.24, 0.68, 0.48, 0.12), paint)
      ..drawPath(
        Path()
          ..moveTo(0.42 * s, 0.30 * s)
          ..quadraticBezierTo(0.48 * s, 0.10 * s, 0.64 * s, 0.07 * s)
          ..quadraticBezierTo(0.60 * s, 0.20 * s, 0.62 * s, 0.30 * s)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_PooPainter old) => old.color != color;
}

/// Icon and colours used for an entry everywhere in the app.
({Glyph glyph, Color soft, Color strong}) lookOf(Entry e) => switch (e.type) {
  EntryType.feed => (
    glyph: e.side == FeedSide.bottle ? Glyphs.bottle : Glyphs.feed,
    soft: Baby.feedSoft,
    strong: Baby.feed,
  ),
  EntryType.nappy => nappyLook(e.nappy ?? NappyKind.pee),
  EntryType.pill => (
    glyph: Glyphs.pill,
    soft: Baby.pillSoft,
    strong: Baby.pill,
  ),
};

({Glyph glyph, Color soft, Color strong}) nappyLook(NappyKind k) => switch (k) {
  NappyKind.pee => (glyph: Glyphs.pee, soft: Baby.peeSoft, strong: Baby.pee),
  NappyKind.poo => (glyph: Glyphs.poo, soft: Baby.pooSoft, strong: Baby.poo),
  NappyKind.both => (
    glyph: Glyphs.peeAndPoo,
    soft: Baby.nappySoft,
    strong: Baby.nappy,
  ),
};

// ------------------------------------------------------------------ actions

void showUndo(BuildContext context, String message, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: LText(message),
        action: SnackBarAction(label: tr('Undo'), onPressed: onUndo),
        duration: const Duration(seconds: 4),
      ),
    );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: LText(message)));
}

/// Picks a time; if the time would be in the future it is taken as yesterday,
/// so logging a 23:30 feed at 00:10 just works.
Future<DateTime?> pickTime(BuildContext context, DateTime initial) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (t == null) return null;
  final now = DateTime.now();
  // A time within the last day: today, or yesterday if that would be in the
  // future. Older dates (picked with the calendar) keep their day.
  if (now.difference(initial).inHours < 24) {
    var result = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (result.isAfter(now.add(const Duration(minutes: 5)))) {
      result = DateTime(now.year, now.month, now.day - 1, t.hour, t.minute);
    }
    return result;
  }
  return DateTime(initial.year, initial.month, initial.day, t.hour, t.minute);
}

// ------------------------------------------------------------------ widgets

/// Pull down to refresh: syncs with the paired phones (or runs [onRefresh])
/// and says how it went.
class PullToSync extends StatelessWidget {
  const PullToSync({super.key, required this.child, this.onRefresh});
  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: Baby.primary,
    backgroundColor: Baby.card,
    onRefresh: onRefresh ?? () => _syncAll(context),
    child: child,
  );

  static Future<void> _syncAll(BuildContext context) async {
    final app = context.findAncestorWidgetOfExactType<AppScope>()!.notifier!;
    await app.refreshIps();
    if (app.peers.isEmpty) {
      if (context.mounted) {
        showMessage(
          context,
          'Up to date. Pair the other phone in Settings to sync.',
        );
      }
      return;
    }
    final error = await app.syncAll(force: true);
    if (!context.mounted) return;
    final names = app.peers
        .map((p) => p.name.isEmpty ? p.host : p.name)
        .join(', ');
    showMessage(
      context,
      error == null ? 'Synced with $names' : 'Could not sync: $error',
    );
  }
}

/// Keeps content phone-width on wide (desktop) windows.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  );
}

class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.glyph,
    required this.color,
    required this.iconColor,
    this.size = 44,
  });
  final Glyph glyph;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: glyph(size * 0.52, iconColor),
  );
}

/// Today's totals as small icons with numbers: feeds, wet and dirty nappies.
class Counts extends StatelessWidget {
  const Counts({
    super.key,
    required this.feeds,
    required this.pee,
    required this.poo,
    this.extra,
  });
  final int feeds;
  final int pee;
  final int poo;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: FontWeight.w800, color: Baby.muted);
    Widget item(Glyph g, Color c, String n) => Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          g(17, c),
          const SizedBox(width: 3),
          LText(n, style: style),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(
          Glyphs.feed,
          Baby.feed,
          extra == null ? '$feeds' : '$feeds ($extra)',
        ),
        item(Glyphs.pee, Baby.pee, '$pee'),
        item(Glyphs.poo, Baby.poo, '$poo'),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: LText(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Baby.ink,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Big pastel tile for the main actions on the Today screen.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.glyph,
    required this.label,
    required this.hint,
    required this.soft,
    required this.strong,
    required this.onTap,
  });

  final Glyph glyph;
  final String label;
  final String hint;
  final Color soft;
  final Color strong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: soft,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          child: Column(
            children: [
              IconBubble(
                glyph: glyph,
                color: Baby.card,
                iconColor: strong,
                size: 56,
              ),
              const SizedBox(height: 10),
              LText(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Baby.ink,
                ),
              ),
              const SizedBox(height: 2),
              LText(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: strong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One logged entry as a row: icon, title/detail, time.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.showDay = false,
  });
  final Entry entry;
  final VoidCallback onTap;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final look = lookOf(entry);
    final elsewhere = app.loggedElsewhere(entry);
    final detail = [
      ?entryDetail(entry),
      if (elsewhere != null) 'by $elsewhere',
    ].join(' · ');
    final duplicate = app.isPossibleDuplicate(entry);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            IconBubble(
              glyph: look.glyph,
              color: look.soft,
              iconColor: look.strong,
              size: 42,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    entryTitle(entry),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    LText(
                      detail,
                      style: TextStyle(
                        color: Baby.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (duplicate)
                    Row(
                      children: [
                        Icon(
                          Icons.content_copy_rounded,
                          size: 14,
                          color: Baby.warn,
                        ),
                        const SizedBox(width: 4),
                        LText(
                          'Possible duplicate from the other phone',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Baby.warn,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            LText(
              showDay && !sameDay(entry.time, DateTime.now())
                  ? DateFormat('EEE d MMM, HH:mm').format(entry.time)
                  : hm(entry.time),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Baby.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card holding a list of rows separated by thin lines.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: 70),
          children[i],
        ],
      ],
    ),
  );
}

/// Title row at the top of every bottom sheet, with a close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.glyph,
    this.soft,
    this.strong,
  });
  final String title;
  final String? subtitle;
  final Glyph? glyph;
  final Color? soft;
  final Color? strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        if (glyph != null) ...[
          IconBubble(
            glyph: glyph!,
            color: soft ?? Baby.pillSoft,
            iconColor: strong ?? Baby.pill,
            size: 48,
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                LText(
                  subtitle!,
                  style: TextStyle(
                    color: Baby.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        LIconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

/// Selectable option tile (feed side, appearance, schedule type...).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
    this.glyph,
    this.glyphColor,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Glyph? glyph;
  final Color? glyphColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Baby.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? Colors.transparent : Baby.line,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                glyph!(26, glyphColor ?? Baby.ink),
                const SizedBox(height: 4),
              ],
              LText(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (badge != null || glyph != null)
                SizedBox(
                  height: 16,
                  child: badge == null
                      ? null
                      : LText(
                          badge!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Baby.feed,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A "When" row: Now / an earlier time, plus a calendar button for the date.
class WhenField extends StatelessWidget {
  const WhenField({super.key, required this.value, required this.onChanged});

  /// Null means "now".
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Row(
      children: [
        const LText('When', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const LText('Now'),
                selected: v == null,
                onSelected: (_) => onChanged(null),
              ),
              ChoiceChip(
                avatar: Icon(Icons.schedule_rounded, size: 18, color: Baby.ink),
                label: LText(v == null ? 'Earlier' : whenLabel(v)),
                selected: v != null,
                onSelected: (_) async {
                  final t = await pickTime(context, v ?? DateTime.now());
                  if (t != null) onChanged(t);
                },
              ),
            ],
          ),
        ),
        LIconButton(
          tooltip: 'Pick date',
          icon: Icon(Icons.calendar_month_rounded, color: Baby.muted),
          onPressed: () async {
            final base = v ?? DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: base,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (d != null) {
              onChanged(
                DateTime(d.year, d.month, d.day, base.hour, base.minute),
              );
            }
          },
        ),
      ],
    );
  }
}

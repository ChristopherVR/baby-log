import 'package:flutter/material.dart';

import '../distribution.dart';

import 'common.dart';
import 'pills_page.dart';
import 'settings_page.dart';
import 'sheets.dart';
import 'theme.dart';
import 'language_picker.dart';
import 'setup/illustrations.dart';
import 'setup/motion.dart';

/// First-time setup: a few short steps, all optional and changeable later in Settings.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _pages = PageController();
  int _step = 0;
  late final _baby = TextEditingController(text: AppScope.of(context).babyName);
  // More babies added during setup; the first baby is [_baby].
  final _more = <TextEditingController>[];
  static const _count = 6;

  @override
  void dispose() {
    _pages.dispose();
    _baby.dispose();
    for (final c in _more) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveNames() {
    final app = AppScope.of(context);
    if (_baby.text.trim() != app.babyName) app.setBabyName(_baby.text);
  }

  /// Extra babies are added once, when setup finishes. The first baby stays
  /// selected.
  void _saveMoreBabies() {
    final app = AppScope.of(context);
    final seen = {
      for (final b in app.babies) b.name.trim().toLowerCase(),
      _baby.text.trim().toLowerCase(),
    };
    for (final c in _more) {
      final name = c.text.trim();
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      app.addBaby(name, select: false);
    }
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    if (step >= _count) {
      _saveNames();
      _saveMoreBabies();
      AppScope.of(context).completeSetup();
      return;
    }
    // Ask for notification permission when leaving the reminders step.
    if (_step == 3 && step > 3) {
      AppScope.of(context).reminders.requestPermission();
    }
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: PageWidth(
          maxWidth: 560,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _Progress(step: _step, count: _count),
                    ),
                    const SizedBox(width: 12),
                    if (!last)
                      TextButton(
                        onPressed: () => _go(_count),
                        child: const LText('Skip'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) {
                    if (_step == 1) _saveNames();
                    setState(() => _step = i);
                  },
                  children: [
                    for (final (i, page) in [
                      const _Welcome(),
                      _Names(
                        baby: _baby,
                        more: _more,
                        onAdd: () => setState(
                          () => _more.add(TextEditingController()),
                        ),
                        onRemove: (c) => setState(() {
                          _more.remove(c);
                          c.dispose();
                        }),
                      ),
                      const _NightLightStep(),
                      const _Reminders(),
                      const _Partner(),
                      const _Done(),
                    ].indexed)
                      PageFx(controller: _pages, index: i, child: page),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const LText('Back'),
                        onPressed: () => _go(_step - 1),
                      ),
                    const Spacer(),
                    Flexible(
                      child: FilledButton.icon(
                        iconAlignment: IconAlignment.end,
                        icon: Icon(
                          last
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: LText(
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          _step == 0
                              ? 'Get started'
                              : last
                              ? 'Start using Nestling'
                              : 'Next',
                        ),
                        onPressed: () => _go(_step + 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated progress bar: the fill glides to the current step.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.count});
  final int step;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    value: '${step + 1} / $count',
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: (step + 1) / count),
      duration: reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 10,
          color: Baby.primary,
          backgroundColor: Baby.line,
        ),
      ),
    ),
  );
}

/// A setup step: optional animated illustration, heading, explanation and
/// content, scrollable on small screens. Each part eases in one after another.
class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.text,
    required this.child,
    this.art,
  });
  final String title;
  final String text;
  final Widget child;
  final Widget? art;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    children: [
      if (art != null) ...[Entrance(child: art!), const SizedBox(height: 12)],
      Entrance(
        index: 1,
        child: LText(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 6),
      Entrance(
        index: 2,
        child: LText(
          text,
          style: TextStyle(
            fontSize: 16,
            color: Baby.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 24),
      Entrance(index: 3, child: child),
    ],
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    Widget feature(
      int index,
      Glyph g,
      Color soft,
      Color strong,
      String title,
      String text,
    ) => Entrance(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            IconBubble(glyph: g, color: soft, iconColor: strong, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  LText(
                    text,
                    style: TextStyle(
                      color: Baby.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        const LanguagePicker(),
        const SizedBox(height: 12),
        const WelcomeArt(),
        const SizedBox(height: 12),
        const Entrance(
          index: 1,
          child: LText(
            'Welcome to Nestling',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        Entrance(
          index: 2,
          child: LText(
            'Everything about the little one in one place, in a single tap.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Baby.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 28),
        feature(
          2,
          Glyphs.feed,
          Baby.feedSoft,
          Baby.feed,
          'Feeds',
          'Which side, when and for how long',
        ),
        feature(
          3,
          Glyphs.nappy,
          Baby.nappySoft,
          Baby.nappy,
          'Nappies',
          'Pee, poo or both, with daily totals',
        ),
        feature(
          4,
          Glyphs.pill,
          Baby.pillSoft,
          Baby.pill,
          'Your pills',
          'Dose times worked out, with alarms',
        ),
        feature(
          5,
          Glyphs.wifi,
          Baby.peeSoft,
          Baby.pee,
          'Shared',
          'Both phones stay in sync over Wi‑Fi',
        ),
      ],
    );
  }
}

class _Names extends StatelessWidget {
  const _Names({
    required this.baby,
    required this.more,
    required this.onAdd,
    required this.onRemove,
  });
  final TextEditingController baby;
  final List<TextEditingController> more;
  final VoidCallback onAdd;
  final ValueChanged<TextEditingController> onRemove;

  @override
  Widget build(BuildContext context) => _Step(
    title: 'Who is this for?',
    text:
        "Optional. Names are shared with your partner's phone when you connect. "
        'Add every baby you want to keep track of.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: baby,
          textCapitalization: TextCapitalization.words,
          decoration: LInputDecoration(
            labelText: "Baby's name",
            hintText: 'e.g. Emma',
            prefixIcon: Icon(Icons.child_care_rounded, color: Baby.primary),
          ),
        ),
        for (final c in more)
          Padding(
            key: ObjectKey(c),
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: c,
              textCapitalization: TextCapitalization.words,
              decoration: LInputDecoration(
                labelText: 'Another baby',
                hintText: 'e.g. Noah',
                prefixIcon: Icon(Icons.child_care_rounded, color: Baby.primary),
                suffixIcon: LIconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onRemove(c),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const LText('Add another baby'),
            onPressed: onAdd,
          ),
        ),
      ],
    ),
  );
}

class _NightLightStep extends StatelessWidget {
  const _NightLightStep();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return _Step(
      title: 'Night light',
      text: 'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.',
      art: NightLightDemo(active: app.nightLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: LText(
                  'Night light',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Switch(value: app.nightLight, onChanged: app.setNightLight),
            ],
          ),
          const SizedBox(height: 20),
          const LText(
            'Light or dark?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const AppearancePicker(),
        ],
      ),
    );
  }
}

class _Partner extends StatelessWidget {
  const _Partner();

  @override
  Widget build(BuildContext context) => const _Step(
    title: 'Share with your partner',
    text: 'Connect the other phone now, or skip and do it later in Settings.',
    art: PairDemo(),
    child: PairCard(),
  );
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
    children: [
      const SuccessArt(),
      const SizedBox(height: 16),
      const Entrance(
        index: 2,
        child: LText(
          'You are all set!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 6),
      Entrance(
        index: 3,
        child: LText(
          'Change anything later in Settings.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Baby.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _Reminders extends StatelessWidget {
  const _Reminders();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return _Step(
      title: 'Reminders',
      art: const ReminderDemo(),
      text: Distribution.play
          ? 'Get a reminder when the next feed is due, and when it is time for your pills.'
          : 'Get an alarm when the next feed is due, and when it is time for your pills.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FeedReminderOptions(),
          const SizedBox(height: 24),
          const LText(
            'Your pills',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (app.meds.isNotEmpty) ...[
            ListCard(
              children: [
                for (final med in app.meds)
                  ListTile(
                    leading: IconBubble(
                      glyph: Glyphs.pill,
                      color: Baby.pillSoft,
                      iconColor: Baby.pill,
                      size: 38,
                    ),
                    title: LText.raw(
                      med.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: LText(
                      '${med.scheduleLabel} · ${med.slots.map(minutesOfDay).join(', ')}',
                    ),
                    onTap: () => showSheet(context, MedEditor(initial: med)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: LText(app.meds.isEmpty ? 'Add a pill' : 'Add another pill'),
            onPressed: () => showSheet(context, const MedEditor()),
          ),
        ],
      ),
    );
  }
}

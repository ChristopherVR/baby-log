import 'package:flutter/material.dart';

import 'common.dart';
import 'pills_page.dart';
import 'settings_page.dart';
import 'sheets.dart';
import 'theme.dart';
import 'language_picker.dart';

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
  late final _device = TextEditingController(
    text: AppScope.of(context).deviceName,
  );

  static const _count = 5;

  @override
  void dispose() {
    _pages.dispose();
    _baby.dispose();
    _device.dispose();
    super.dispose();
  }

  void _saveNames() {
    final app = AppScope.of(context);
    if (_baby.text.trim() != app.babyName) app.setBabyName(_baby.text);
    if (_device.text.trim().isNotEmpty &&
        _device.text.trim() != app.deviceName) {
      app.setDeviceName(_device.text);
    }
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    if (step >= _count) {
      _saveNames();
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < _count; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _step ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= _step ? Baby.primary : Baby.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    const Spacer(),
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
                    const _Welcome(),
                    _Names(baby: _baby, device: _device),
                    const _Step(
                      title: 'Light or dark?',
                      text: 'The app switches to dark from 6 pm to 6 am.',
                      child: AppearancePicker(),
                    ),
                    const _Reminders(),
                    const _Step(
                      title: 'Share with your partner',
                      text: 'Connect the other phone now, or skip and do it later in Settings.',
                      child: PairCard(),
                    ),
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
                    FilledButton.icon(
                      iconAlignment: IconAlignment.end,
                      icon: Icon(
                        last
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: LText(
                        _step == 0
                            ? 'Get started'
                            : last
                            ? 'Start using Baby Log'
                            : 'Next',
                      ),
                      onPressed: () => _go(_step + 1),
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

/// A setup step: heading, explanation and content, scrollable on small screens.
class _Step extends StatelessWidget {
  const _Step({required this.title, required this.text, required this.child});
  final String title;
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      LText(
        title,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      LText(
        text,
        style: TextStyle(
          fontSize: 16,
          color: Baby.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 24),
      child,
    ],
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    Widget feature(
      Glyph g,
      Color soft,
      Color strong,
      String title,
      String text,
    ) => Padding(
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
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      children: [
        const LanguagePicker(),
        const SizedBox(height: 24),
        Center(
          child: IconBubble(
            glyph: Glyphs.baby,
            color: Baby.pillSoft,
            iconColor: Baby.primary,
            size: 96,
          ),
        ),
        const SizedBox(height: 20),
        const LText(
          'Welcome to Baby Log',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        LText(
          'Everything about the little one in one place, in a single tap.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Baby.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 32),
        feature(
          Glyphs.feed,
          Baby.feedSoft,
          Baby.feed,
          'Feeds',
          'Which side, when and for how long',
        ),
        feature(
          Glyphs.nappy,
          Baby.nappySoft,
          Baby.nappy,
          'Nappies',
          'Pee, poo or both, with daily totals',
        ),
        feature(
          Glyphs.pill,
          Baby.pillSoft,
          Baby.pill,
          'Your pills',
          'Dose times worked out, with alarms',
        ),
        feature(
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
  const _Names({required this.baby, required this.device});
  final TextEditingController baby;
  final TextEditingController device;

  @override
  Widget build(BuildContext context) => _Step(
    title: 'Who is this for?',
    text: 'Both are optional. The baby\'s name is shared with your partner\'s phone when you connect.',
    child: Column(
      children: [
        TextField(
          controller: baby,
          textCapitalization: TextCapitalization.words,
          decoration: LInputDecoration(
            labelText: 'Baby\'s name',
            hintText: 'e.g. Emma',
            prefixIcon: Icon(Icons.child_care_rounded, color: Baby.primary),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: device,
          textCapitalization: TextCapitalization.words,
          decoration: LInputDecoration(
            labelText: 'This phone belongs to',
            hintText: 'e.g. Mom\'s phone',
            prefixIcon: Icon(Icons.phone_android_rounded, color: Baby.primary),
          ),
        ),
      ],
    ),
  );
}

class _Reminders extends StatelessWidget {
  const _Reminders();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return _Step(
      title: 'Reminders',
      text: 'Get an alarm when the next feed is due, and when it is time for your pills.',
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

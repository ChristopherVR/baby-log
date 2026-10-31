import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../background.dart';
import '../distribution.dart';
import '../store.dart';
import '../sync.dart';
import '../routines.dart';
import 'baby_photo.dart';
import 'common.dart';
import 'growth_page.dart';
import 'data_transfer.dart';
import 'hub_page.dart';
import 'peer_page.dart';
import 'pump_lab_page.dart';
import 'pump_page.dart';
import 'qr_sync_page.dart';
import 'sheets.dart';
import 'theme.dart';
import 'language_picker.dart';
import 'update_card.dart';

void openSettings(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const SettingsPage()),
);

String feedIntervalLabel(int m) =>
    m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} m';

String appearanceLabel(String a) => switch (a) {
  'dark' => 'Dark',
  'system' => 'Match phone',
  _ => 'Light',
};

/// Small status pill in the app bar: shows whether the hub's devices are in sync.
/// Tapping it opens the hub view with every device's status.
class SyncChip extends StatelessWidget {
  const SyncChip({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final (Color color, String label) = app.peers.isEmpty
        ? (Baby.primary, 'Share')
        : app.syncing
        ? (Baby.primary, 'Syncing')
        : app.syncPausedForVersion
        ? (Baby.warn, 'Sync paused')
        : app.syncHasError
        ? (Baby.warn, 'Not synced')
        : (Baby.ok, app.lastSync == null ? 'Paired' : 'Synced');
    if (compact) {
      return LIconButton(
        tooltip: label,
        icon: Icon(
          app.peers.isEmpty ? Icons.people_alt_rounded : Icons.circle,
          color: color,
          size: app.peers.isEmpty ? 22 : 12,
        ),
        onPressed: () => openHub(context),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        avatar: Icon(
          app.peers.isEmpty ? Icons.people_alt_rounded : Icons.circle,
          size: app.peers.isEmpty ? 18 : 10,
          color: color,
        ),
        label: LText(label),
        onPressed: () => openHub(context),
      ),
    );
  }
}

/// Light / Dark / Match phone choice (used in Settings and the first-time setup).
class AppearancePicker extends StatelessWidget {
  const AppearancePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Row(
      children: [
        for (final (value, glyph) in [
          ('light', Glyphs.light),
          ('dark', Glyphs.dark),
          ('system', Glyphs.auto),
        ]) ...[
          Expanded(
            child: OptionTile(
              glyph: glyph,
              glyphColor: Baby.primary,
              label: appearanceLabel(value),
              selected: app.appearance == value,
              color: Baby.pillSoft,
              onTap: () => app.setAppearance(value),
            ),
          ),
          if (value != 'system') const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// Feed reminder switch and interval (used in Settings and the first-time setup).
/// Notification or alarm, for feed or pill reminders on this phone.
class RingStylePicker extends StatelessWidget {
  const RingStylePicker({
    super.key,
    required this.alarm,
    required this.onChanged,
  });
  final bool alarm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // The Play build only has normal notifications.
    if (Distribution.play) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OptionTile(
                glyph: (s, c) =>
                    Icon(Icons.notifications_rounded, size: s, color: c),
                glyphColor: Baby.primary,
                label: 'Notification',
                selected: !alarm,
                color: Baby.pillSoft,
                onTap: () => onChanged(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OptionTile(
                glyph: (s, c) => Icon(Icons.alarm_rounded, size: s, color: c),
                glyphColor: Baby.feed,
                label: 'Alarm',
                selected: alarm,
                color: Baby.feedSoft,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LText(
          alarm
              ? 'Rings with your alarm sound until you stop or snooze it, even on silent, and shows on the lock screen.'
              : 'A normal notification with your notification sound.',
          style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

Future<void> _showPillRingSheet(BuildContext context) => showSheet(
  context,
  Builder(
    builder: (context) {
      final app = AppScope.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: 'Pill reminders',
            subtitle: 'How they ring on this phone',
            glyph: Glyphs.pill,
          ),
          if (Distribution.play)
            LText(
              'Pill reminders show as normal notifications.',
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            )
          else
            RingStylePicker(
              alarm: app.pillAlarm,
              onChanged: (v) => app.setReminderAlarm(pill: v),
            ),
          const SizedBox(height: 8),
        ],
      );
    },
  ),
);

class FeedReminderOptions extends StatelessWidget {
  const FeedReminderOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: SwitchListTile(
            secondary: Icon(Icons.alarm_rounded, color: Baby.feed),
            title: const LText(
              'Remind me to feed',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const LText('Counted from the start of the last feed'),
            value: app.feedReminderOn,
            onChanged: (v) => app.setFeedReminder(on: v),
          ),
        ),
        const SizedBox(height: 14),
        const LText(
          'How long after a feed?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in const [90, 120, 150, 180, 210, 240, 300])
              ChoiceChip(
                label: LText(feedIntervalLabel(m)),
                selected: app.feedReminderOn && app.feedReminderMinutes == m,
                selectedColor: Baby.feedSoft,
                onSelected: (_) => app.setFeedReminder(on: true, minutes: m),
              ),
          ],
        ),
        if (!Distribution.play) ...[
          const SizedBox(height: 18),
          const LText(
            'How it rings',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          RingStylePicker(
            alarm: app.feedAlarm,
            onChanged: (v) => app.setReminderAlarm(feed: v),
          ),
        ],
      ],
    );
  }
}

Future<void> showFeedReminderSheet(BuildContext context) => showSheet(
  context,
  Builder(
    builder: (context) {
      final name = AppScope.of(context).babyName;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: 'Feed reminder',
            subtitle: name.isEmpty ? null : 'For $name',
            glyph: Glyphs.alarm,
            soft: Baby.feedSoft,
            strong: Baby.feed,
          ),
          const FeedReminderOptions(),
          const SizedBox(height: 8),
        ],
      );
    },
  ),
);

Future<void> _showAppearanceSheet(BuildContext context) => showSheet(
  context,
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SheetHeader(title: 'Appearance', glyph: Glyphs.dark),
      const AppearancePicker(),
      const SizedBox(height: 16),
      const NightLightSwitch(),
      const SizedBox(height: 8),
    ],
  ),
);

/// Night light: a dimmer, warmer version of the light theme from 6 pm to 6 am.
/// It is not dark mode, so the text says so.
class NightLightSwitch extends StatelessWidget {
  const NightLightSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        secondary: const _Badge(Icons.nightlight_round),
        title: const LText(
          'Night light',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: LText(
            'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.\n'
            'It is a softer light theme, not dark mode. Choose Dark above for dark all day.',
            style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
          ),
        ),
        value: app.nightLight,
        onChanged: app.setNightLight,
      ),
    );
  }
}

/// Round tinted icon badge used on settings rows.
class _Badge extends StatelessWidget {
  const _Badge(this.icon, {this.tone});
  final IconData icon;

  /// 0 purple (default), 1 orange, 2 green, 3 yellow, 4 brown.
  final int? tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      1 => (Baby.feedSoft, Baby.feed),
      2 => (Baby.nappySoft, Baby.nappy),
      3 => (Baby.peeSoft, Baby.pee),
      4 => (Baby.pooSoft, Baby.poo),
      _ => (Baby.pillSoft, Baby.primary),
    };
    return IconBubble(
      glyph: (s, c) => Icon(icon, size: s, color: c),
      color: bg,
      iconColor: fg,
      size: 40,
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initialQuery = ''});

  /// Text already in the search box, e.g. when opened from the global search.
  final String initialQuery;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _search = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Iterable<String> terms) {
    final words = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    final searchable = terms
        .expand((term) => [term, tr(term, language: 'af')])
        .join(' ')
        .toLowerCase();
    return words.every(searchable.contains);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sections = <Widget>[];
    void addSection(
      String title,
      List<({List<String> terms, Widget child})> entries, {
      Widget? footer,
      bool card = true,
    }) {
      final matches = entries
          .where((entry) => _matches([title, ...entry.terms]))
          .map((entry) => entry.child)
          .toList();
      if (matches.isEmpty) return;
      sections.addAll([
        SectionTitle(title),
        if (card) ListCard(children: matches) else ...matches,
        ?footer,
      ]);
    }

    addSection('Language', [
      (
        terms: ['Language', 'English', 'Afrikaans'],
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: LanguagePicker(showLabel: false),
        ),
      ),
    ]);
    addSection(
      'Babies',
      [
        for (final baby in app.babies)
          (
            terms: [baby.name, 'Babies', 'Baby profile', 'Photo', 'Birthday'],
            child: _BabyTile(baby: baby),
          ),
        (
          terms: ['Add a baby', 'Another baby', 'Twins'],
          child: _Tile(
            icon: Icons.person_add_alt_1_rounded,
            tone: 2,
            title: 'Add a baby',
            value: '',
            onTap: () => _addBaby(context, app),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: LText(
          'Tap a baby to change their name, birthday or photo. '
          'The selected baby is the one you see on the other tabs.',
          style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
    addSection(
      'Reminders',
      [
        if (Distribution.play && !app.reminders.exactAllowed)
          (
            terms: ['Allow exact reminders', 'Alarms & reminders'],
            child: _Tile(
              icon: Icons.alarm_on_rounded,
              tone: 1,
              title: 'Allow exact reminders',
              subtitle:
                  'Without this, Android can delay reminders by several minutes',
              value: '',
              onTap: () async {
                await app.reminders.openExactAccessSettings();
              },
            ),
          ),
        (
          terms: [
            'Feed reminder',
            'Remind me to feed',
            'How long after a feed?',
            'How it rings',
            'Notification',
            'Alarm',
            app.babyName,
            feedIntervalLabel(app.feedReminderMinutes),
          ],
          child: _Tile(
            icon: Icons.alarm_rounded,
            tone: 1,
            title: 'Feed reminder',
            subtitle: app.babyName.isEmpty ? null : 'For ${app.babyName}',
            value: app.feedReminderOn
                ? '${feedIntervalLabel(app.feedReminderMinutes)}${app.feedAlarm && !Distribution.play ? ', alarm' : ''}'
                : 'Off',
            onTap: () => showFeedReminderSheet(context),
          ),
        ),
        (
          terms: ['Pill reminders', 'How it rings', 'Notification', 'Alarm'],
          child: _Tile(
            icon: Glyphs.pillIcon,
            title: 'Pill reminders',
            subtitle: 'For you, on this phone',
            value: app.pillAlarm && !Distribution.play ? 'Alarm' : 'Notification',
            onTap: () => _showPillRingSheet(context),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: LText(
          app.babies.length > 1
              ? 'The feed reminder is kept for each baby: it follows the selected baby. '
                    'Which pills remind you, and when, is set per pill on the Pills tab.'
              : 'Which pills remind you, and when, is set per pill on the Pills tab.',
          style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
    addSection('Appearance', [
      (
        terms: ['Theme', 'Light', 'Dark', 'Match phone'],
        child: _Tile(
          icon: Baby.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          tone: 3,
          title: 'Theme',
          value: appearanceLabel(app.appearance),
          onTap: () => _showAppearanceSheet(context),
        ),
      ),
      (
        terms: [
          'Night light',
          'Nighttime',
          'Dim',
          'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.',
        ],
        child: SwitchListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          secondary: const _Badge(Icons.nightlight_round),
          title: const LText(
            'Night light',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: LText(
            'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.',
            style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
          ),
          value: app.nightLight,
          onChanged: app.setNightLight,
        ),
      ),
    ]);
    addSection('Pumping', [
      (
        terms: ['Show Pump on Today', 'Pumping', 'Breast pump', 'Expressing'],
        child: SwitchListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          secondary: const _Badge(Icons.water_drop_rounded, tone: 1),
          title: const LText(
            'Show Pump on Today',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: LText(
            'A Pump button next to Feed and Nappy, for logging pumping and '
            'controlling Momcozy pumps.',
            style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
          ),
          value: app.pumpOnToday,
          onChanged: app.setShowPump,
        ),
      ),
      (
        terms: ['Pumping', 'Momcozy', 'BP380', 'Bluetooth', 'Your pumps'],
        child: _Tile(
          icon: Icons.bluetooth_rounded,
          tone: 1,
          title: 'Pumping',
          subtitle: Platform.isAndroid
              ? 'Your pumps, sessions and stats'
              : 'Sessions and stats',
          value: app.pumpDevices.isEmpty ? '' : '${app.pumpDevices.length}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PumpPage()),
          ),
        ),
      ),
      if (Platform.isAndroid)
        (
          terms: ['Pump lab', 'Diagnostics', 'Packet log'],
          child: _Tile(
            icon: Icons.science_outlined,
            tone: 4,
            title: 'Pump lab',
            subtitle: 'Diagnostics and raw pump data',
            value: '',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PumpLabPage()),
            ),
          ),
        ),
    ]);
    addSection('Family hub', [
      (
        terms: [
          'Family hub',
          'Devices sharing this log',
          'Add a device',
          'Sync details',
          'This device',
          'Everyone in the hub sees the same log',
          'Pair',
          'Share',
          'Scan code',
          'Type code',
          'Address',
          'Code',
          'Wi-Fi',
          'Sync by QR code',
          for (final peer in app.peers) ...[peer.name, peer.host],
        ],
        child: const HubSummary(),
      ),
      (
        terms: [
          'Sync now',
          'Sync automatically',
          'Keep syncing when closed',
          'Allow background use',
          'After every change and every minute',
        ],
        child: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: _PeersCard(),
        ),
      ),
    ], card: false);
    addSection(
      'Your data',
      [
        (
          terms: ['Export backup', 'History', 'spreadsheet'],
          child: _Tile(
            icon: Icons.save_alt_rounded,
            tone: 2,
            title: 'Export backup',
            value: '',
            onTap: () => exportBackupFile(context),
          ),
        ),
        (
          terms: ['Import backup', 'Your saved data could not be read'],
          child: _Tile(
            icon: Icons.upload_file_rounded,
            tone: 2,
            title: 'Import backup',
            value: '',
            onTap: () => importBackupFile(context),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: LText(
          'Importing adds to your log and never deletes anything. '
          'A spreadsheet export is on the History tab.',
          style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
    addSection('This device', [
      (
        terms: ['Device name', app.deviceName],
        child: _Tile(
          icon: Platform.isAndroid
              ? Icons.phone_android_rounded
              : Icons.computer_rounded,
          title: 'Device name',
          value: app.deviceName,
          subtitle: app.deviceNameCustom
              ? 'A name you chose'
              : 'Set by this device',
          onTap: () => _editDeviceName(context, app),
        ),
      ),
      (
        terms: [
          'App version',
          AppState.appVersion,
          'Check for updates',
          'Update',
          'GitHub',
        ],
        child: _Tile(
          icon: Icons.info_outline_rounded,
          tone: 2,
          title: 'App version',
          value: AppState.appVersion,
          onTap: () => showAppUpdates(context),
        ),
      ),
      (
        terms: ['Run first-time setup again', 'Welcome'],
        child: _Tile(
          icon: Icons.restart_alt_rounded,
          tone: 4,
          title: 'Run first-time setup again',
          value: '',
          onTap: () {
            Navigator.popUntil(context, (r) => r.isFirst);
            app.restartSetup();
          },
        ),
      ),
    ]);
    return Scaffold(
      appBar: AppBar(title: const LText('Settings')),
      body: PageWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: LInputDecoration(
                  labelText: 'Search settings',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : LIconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: PullToSync(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Room for the phone's navigation buttons (e.g. Samsung) below the last item.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (app.loadProblem != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          color: Baby.warn.withValues(alpha: 0.12),
                          child: ListTile(
                            leading: Icon(
                              Icons.warning_amber_rounded,
                              color: Baby.warn,
                            ),
                            title: const LText(
                              'Your saved data could not be read',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: LText(
                              'A copy was kept. Use Import backup and choose:\n${app.loadProblem}',
                            ),
                          ),
                        ),
                      ),
                    if (_search.text.trim().isEmpty) const _Summary(),
                    ...sections,
                    if (sections.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: LText(
                          'No settings found. Try a different search.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.tone,
  });
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final int? tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: _Badge(icon, tone: tone),
    title: LText(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: subtitle == null
        ? null
        : LText(
            subtitle!,
            style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
          ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: LText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            ),
          ),
        Icon(Icons.chevron_right_rounded, color: Baby.muted),
      ],
    ),
    onTap: onTap,
  );
}

/// Friendly summary at the top: baby, this device and how syncing is going.
class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final status = app.peers.isEmpty
        ? 'Not paired yet'
        : app.syncing
        ? 'Syncing'
        : app.syncPausedForVersion
        ? 'Sync paused'
        : app.syncHasError
        ? 'Not synced'
        : app.lastSync == null
        ? 'Paired'
        : 'Synced ${ago(app.lastSync!)}';
    final ok =
        app.peers.isNotEmpty && !app.syncPausedForVersion && !app.syncHasError;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Card(
        color: Baby.pillSoft,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: tr('Change photo'),
                child: Tooltip(
                  message: tr('Change photo'),
                  child: InkResponse(
                    radius: 40,
                    onTap: () async {
                      final photo = await pickBabyPhoto(context);
                      if (photo == null || !context.mounted) return;
                      app.saveBabyProfile(
                        name: app.activeBaby.name,
                        dateOfBirth: app.activeBaby.dateOfBirth,
                        photo: photo,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        BabyPhoto(photo: app.activeBaby.photo, size: 56),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Baby.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Baby.pillSoft,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.photo_camera_rounded,
                                size: 12,
                                color: Baby.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => editBabyProfile(context),
                      child: Row(
                        children: [
                          Flexible(
                            child: LText.raw(
                              app.babyName.isEmpty
                                  ? tr('Nestling')
                                  : app.babyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Baby.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    LText(
                      app.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Baby.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          ok ? Icons.check_circle_rounded : Icons.circle,
                          size: ok ? 16 : 10,
                          color: ok
                              ? Baby.ok
                              : app.peers.isEmpty
                              ? Baby.muted
                              : Baby.warn,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LText(
                            status,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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

/// Device name: starts as the device's own name; typing replaces it, and a
/// button goes back to the device's own name.
Future<void> _editDeviceName(BuildContext context, AppState app) async {
  final c = TextEditingController(text: app.deviceName);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const LText('Device name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const LInputDecoration(
              hintText: 'Type a name your partner will recognise',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          if (app.deviceNameCustom) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: const LText("Use this device's own name"),
              onPressed: () => Navigator.pop(ctx, ''),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const LText('Save'),
        ),
      ],
    ),
  );
  if (result == null) return;
  if (result.trim().isEmpty) {
    await app.useDeviceOwnName();
  } else if (result.trim() != app.deviceName) {
    app.setDeviceName(result.trim());
  }
}

/// One baby in the Babies list: photo, name, age. Tap to edit the profile; the
/// trailing control shows or picks which baby the app is following.
class _BabyTile extends StatelessWidget {
  const _BabyTile({required this.baby});
  final BabyProfile baby;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final active = baby.id == app.activeBabyId;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: BabyPhoto(photo: baby.photo, size: 44),
      title: LText.raw(
        baby.name.isEmpty ? tr('Baby') : baby.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: LText.raw(
        '${babyAge(baby)}${active ? ' · ${tr('Selected')}' : ''}',
        style: TextStyle(
          color: active ? Baby.primary : Baby.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: active
          ? Icon(Icons.check_circle_rounded, color: Baby.primary)
          : TextButton(
              onPressed: () {
                if (!app.selectBaby(baby.id)) {
                  showMessage(
                    context,
                    'Save or stop the feed timer before switching babies.',
                  );
                }
              },
              child: const LText('Select'),
            ),
      onTap: () => editBabyProfile(context, baby),
    );
  }
}

Future<void> _addBaby(BuildContext context, AppState app) async {
  final name = await _ask(context, 'Add a baby', '', 'e.g. Emma');
  if (name == null || name.trim().isEmpty) return;
  app.addBaby(name);
}

Future<String?> _ask(
  BuildContext context,
  String title,
  String value,
  String hint,
) {
  final c = TextEditingController(text: value);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: LText(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: LInputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const LText('Save'),
        ),
      ],
    ),
  );
}

/// This device's QR code and code, plus the buttons to connect to the other device.
class PairCard extends StatelessWidget {
  const PairCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ip = app.ips.isEmpty ? null : app.ips.first;
    final port = app.server.port;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            LText(
              'Everyone in the hub keeps the same log over your home Wi‑Fi. '
              'On the device you are adding, open Settings and scan this code. '
              'Add a device once and it shares with everyone else automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            if (ip == null || port == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: LText(
                  port == null
                      ? 'Sync could not start on this device.'
                      : 'Connect to Wi‑Fi to pair.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else ...[
              // Always dark on white so it scans well in dark mode too.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: PairInfo(ip, port, app.syncKey).toUri(),
                  size: 180,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: Color(0xFF3B2A2F),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF3B2A2F),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Big(
                      label: 'ADDRESS',
                      value: port == defaultSyncPort ? ip : '$ip:$port',
                    ),
                  ),
                  Expanded(
                    child: _Big(
                      label: 'CODE',
                      value:
                          '${app.syncKey.substring(0, 3)} ${app.syncKey.substring(3)}',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const LText(
              'Add a device',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (Platform.isAndroid || Platform.isIOS) ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const LText('Scan code'),
                      onPressed: () async {
                        final info = await Navigator.push<PairInfo>(
                          context,
                          MaterialPageRoute(builder: (_) => const _ScanPage()),
                        );
                        if (info != null && context.mounted) {
                          await _pair(
                            context,
                            app,
                            info.host,
                            info.port,
                            info.key,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const LText('Type code'),
                    onPressed: () => _typeCode(context, app),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const LText('Not on the same Wi-Fi? Sync by QR code'),
              onPressed: () => openQrSync(
                context,
                peer: app.peers.length == 1 ? app.peers.first : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _typeCode(BuildContext context, AppState app) async {
    // Pre-fill our own network prefix so usually only the last number is typed.
    final own = app.ips.isEmpty ? '' : app.ips.first;
    final address = TextEditingController(
      text: own.isEmpty ? '' : own.substring(0, own.lastIndexOf('.') + 1),
    );
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const LText('Add a device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LText(
              'Type the address and code shown on the other device (Settings, Family hub).',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: address,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const LInputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              decoration: const LInputDecoration(labelText: 'Code'),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const LText('Connect'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final parts = address.text.trim().split(':');
    final port = parts.length > 1
        ? int.tryParse(parts[1]) ?? defaultSyncPort
        : defaultSyncPort;
    await _pair(
      context,
      app,
      parts[0],
      port,
      code.text.replaceAll(RegExp(r'\D'), ''),
    );
  }

  Future<void> _pair(
    BuildContext context,
    AppState app,
    String host,
    int port,
    String key,
  ) async {
    String message;
    try {
      await app.pair(host, port, key);
      message = 'Device added and synced';
    } on VersionMismatchException catch (e) {
      // Paired, but the versions differ: let the user decide.
      final peer = app.peers.where((p) => p.deviceId == e.deviceId).firstOrNull;
      if (peer == null || !context.mounted) return;
      if (!await confirmVersionMismatch(context, peer)) {
        message =
            'Paired. Syncing waits until both phones have the same version';
      } else {
        try {
          await app.acceptVersion(peer);
          message = 'Device added and synced';
        } catch (e) {
          message = 'Could not sync: $e';
        }
      }
    } catch (e) {
      message = 'Could not connect: $e';
    }
    if (context.mounted) showMessage(context, message);
  }
}

/// Sync options for the hub.
class _PeersCard extends StatelessWidget {
  const _PeersCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListCard(
      children: [
        if (app.peers.isNotEmpty)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: const _Badge(Icons.sync_rounded),
            title: const LText(
              'Sync now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: app.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: app.syncing
                ? null
                : () async {
                    final error = await app.syncAll();
                    if (context.mounted) {
                      showMessage(context, error ?? 'Synced');
                    }
                  },
          ),
        SwitchListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          secondary: const _Badge(Icons.autorenew_rounded),
          title: const LText(
            'Sync automatically',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const LText('After every change and every minute'),
          value: app.autoSync,
          onChanged: app.setAutoSync,
        ),
        if (BackgroundSync.supported)
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            secondary: const _Badge(Icons.cloud_sync_rounded),
            title: const LText(
              'Keep syncing when closed',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const LText('Shows a quiet notification while on'),
            value: app.backgroundSync,
            onChanged: app.setBackgroundSync,
          ),
        if (BackgroundSync.batteryExemptSupported &&
            app.backgroundSync &&
            !app.batteryExempt)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: IconBubble(
              glyph: (s, c) =>
                  Icon(Icons.battery_alert_rounded, size: s, color: c),
              color: Baby.peeSoft,
              iconColor: Baby.warn,
              size: 40,
            ),
            title: const LText(
              'Allow background use',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const LText(
              'Otherwise Android may pause syncing while the screen is off',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: app.requestBatteryExempt,
          ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LText(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Baby.muted,
        ),
      ),
      SelectableText(
        value,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LText('Scan the other device\'s code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          for (final b in capture.barcodes) {
            final info = PairInfo.parse(b.rawValue ?? '');
            if (info != null) {
              _done = true;
              Navigator.pop(context, info);
              return;
            }
          }
        },
      ),
    );
  }
}

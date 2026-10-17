import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../background.dart';
import '../store.dart';
import '../sync.dart';
import 'common.dart';
import 'data_transfer.dart';
import 'peer_page.dart';
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

/// Small status pill in the app bar: shows whether the partner's device is in sync.
class SyncChip extends StatelessWidget {
  const SyncChip({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final (Color color, String label) = app.peers.isEmpty
        ? (Baby.primary, 'Pair partner')
        : app.syncing
        ? (Baby.primary, 'Syncing')
        : app.syncPausedForVersion
        ? (Baby.warn, 'Sync paused')
        : app.syncHasError
        ? (Baby.warn, 'Not synced')
        : (Baby.ok, app.lastSync == null ? 'Paired' : 'Synced');
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        avatar: Icon(
          app.peers.isEmpty ? Icons.people_alt_rounded : Icons.circle,
          size: app.peers.isEmpty ? 18 : 10,
          color: color,
        ),
        label: LText(label),
        onPressed: () => openSettings(context),
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
    );
  }
}

Future<void> showFeedReminderSheet(BuildContext context) => showSheet(
  context,
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SheetHeader(
        title: 'Feed reminder',
        glyph: Glyphs.alarm,
        soft: Baby.feedSoft,
        strong: Baby.feed,
      ),
      const FeedReminderOptions(),
      const SizedBox(height: 8),
    ],
  ),
);

Future<void> _showAppearanceSheet(BuildContext context) => showSheet(
  context,
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SheetHeader(title: 'Appearance', glyph: Glyphs.dark),
      const AppearancePicker(),
      const SizedBox(height: 8),
    ],
  ),
);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _search = TextEditingController();

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
      'Baby',
      [
        (
          terms: ["Baby's name", app.babyName],
          child: _Tile(
            icon: Icons.child_care_rounded,
            title: 'Baby\'s name',
            value: app.babyName.isEmpty ? 'Not set' : app.babyName,
            onTap: () async {
              final name = await _ask(
                context,
                'Baby\'s name',
                app.babyName,
                'e.g. Emma',
              );
              if (name != null) app.setBabyName(name);
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
            feedIntervalLabel(app.feedReminderMinutes),
          ],
          child: _Tile(
            icon: Icons.alarm_rounded,
            title: 'Feed reminder',
            value: app.feedReminderOn
                ? '${feedIntervalLabel(app.feedReminderMinutes)}${app.feedAlarm ? ', alarm' : ''}'
                : 'Off',
            onTap: () => showFeedReminderSheet(context),
          ),
        ),
        (
          terms: ['Pill reminders', 'How it rings', 'Notification', 'Alarm'],
          child: _Tile(
            icon: Icons.medication_rounded,
            title: 'Pill reminders',
            value: app.pillAlarm ? 'Alarm' : 'Notification',
            onTap: () => _showPillRingSheet(context),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: LText(
          'Which pills remind you, and when, is set per pill on the Pills tab.',
          style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
    addSection('Appearance', [
      (
        terms: ['Theme', 'Light', 'Dark', 'Match phone'],
        child: _Tile(
          icon: Baby.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          title: 'Theme',
          value: appearanceLabel(app.appearance),
          onTap: () => _showAppearanceSheet(context),
        ),
      ),
    ]);
    addSection('Share with partner', [
      (
        terms: [
          'Pair partner',
          'Connect to the other phone',
          'Scan code',
          'Type code',
          'Address',
          'Code',
          'Wi-Fi',
          'Sync by QR code',
        ],
        child: const PairCard(),
      ),
      (
        terms: [
          'Paired devices',
          'Sync now',
          'Sync automatically',
          'Keep syncing when closed',
          'Allow background use',
          'After every change and every minute',
          for (final peer in app.peers) ...[peer.name, peer.host],
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
            title: 'Export backup',
            value: '',
            onTap: () => exportBackupFile(context),
          ),
        ),
        (
          terms: ['Import backup', 'Your saved data could not be read'],
          child: _Tile(
            icon: Icons.upload_file_rounded,
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
    if (Platform.isAndroid) {
      addSection('App updates', [
        (
          terms: ['Check for updates', 'Update', 'GitHub', 'App version'],
          child: const UpdateCard(settings: true),
        ),
      ], card: false);
    }
    addSection('This device', [
      (
        terms: ['Device name', app.deviceName],
        child: _Tile(
          icon: Platform.isAndroid
              ? Icons.phone_android_rounded
              : Icons.computer_rounded,
          title: 'Device name',
          value: app.deviceName,
          onTap: () async {
            final name = await _ask(
              context,
              'Device name',
              app.deviceName,
              'e.g. Mom\'s phone',
            );
            if (name != null) app.setDeviceName(name);
          },
        ),
      ),
      (
        terms: ['App version', AppState.appVersion],
        child: _Tile(
          icon: Icons.info_outline_rounded,
          title: 'App version',
          value: AppState.appVersion,
          onTap: () {},
        ),
      ),
      (
        terms: ['Run first-time setup again', 'Welcome'],
        child: _Tile(
          icon: Icons.restart_alt_rounded,
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
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Baby.primary),
    title: LText(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LText(
          value,
          style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
        ),
        Icon(Icons.chevron_right_rounded, color: Baby.muted),
      ],
    ),
    onTap: onTap,
  );
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
              'Both phones keep the same log over your home Wi‑Fi. '
              'On the other phone, open Settings and scan this code.',
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
                    color: Color(0xFF34304A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF34304A),
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
              'Connect to the other phone',
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
        title: const LText('Connect to the other phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LText(
              'Type the address and code shown in Settings on the other phone.',
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
      message = 'Connected and synced';
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
          message = 'Connected and synced';
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

/// Paired devices and sync options.
class _PeersCard extends StatelessWidget {
  const _PeersCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListCard(
      children: [
        if (app.peers.isEmpty)
          ListTile(
            leading: Icon(Icons.link_off_rounded, color: Baby.muted),
            title: const LText(
              'No partner device yet',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const LText('Connect once, then it syncs by itself.'),
          ),
        for (final p in app.peers)
          ListTile(
            leading: Icon(
              p.blockedVersion != null
                  ? Icons.pause_circle_rounded
                  : p.lastError == null
                  ? Icons.check_circle_rounded
                  : Icons.sync_problem_rounded,
              color: p.blockedVersion == null && p.lastError == null
                  ? Baby.ok
                  : Baby.warn,
            ),
            title: LText(
              p.name.isEmpty ? p.host : p.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: LText(
              p.blockedVersion != null
                  ? 'Paused: different app version. Tap to review'
                  : p.lastError ??
                        (p.lastSync == null
                            ? 'Not synced yet'
                            : 'Synced ${ago(p.lastSync!)} · tap for details'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openPeer(context, p),
          ),
        if (app.peers.isNotEmpty)
          ListTile(
            leading: Icon(Icons.sync_rounded, color: Baby.primary),
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
          secondary: Icon(Icons.autorenew_rounded, color: Baby.primary),
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
            secondary: Icon(Icons.nights_stay_rounded, color: Baby.primary),
            title: const LText(
              'Keep syncing when closed',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const LText('Shows a quiet notification while on'),
            value: app.backgroundSync,
            onChanged: app.setBackgroundSync,
          ),
        if (BackgroundSync.supported &&
            app.backgroundSync &&
            !app.batteryExempt)
          ListTile(
            leading: Icon(Icons.battery_alert_rounded, color: Baby.warn),
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
      appBar: AppBar(title: const LText('Scan partner\'s code')),
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

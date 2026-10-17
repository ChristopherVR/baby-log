import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../sync.dart';
import 'common.dart';
import 'qr_sync_page.dart';
import 'theme.dart';

void openPeer(BuildContext context, Peer p) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => PeerPage(deviceId: p.deviceId)),
);

String versionLabel(String? v) => switch (v) {
  null => 'Not known yet',
  olderVersion => 'Older version',
  _ => v,
};

/// Asks whether to sync with a phone on a different app version.
Future<bool> confirmVersionMismatch(BuildContext context, Peer p) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: Baby.warn, size: 36),
      title: const LText('Different app versions'),
      content: LText(
        'This phone has version ${AppState.appVersion}, ${p.name.isEmpty ? 'the other phone' : p.name} '
        'has ${versionLabel(p.blockedVersion ?? p.appVersion).toLowerCase()}.\n\n'
        'Different versions may store things differently, so some entries could sync wrongly. '
        'Best is to install the same version on both phones.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const LText('Not now'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Baby.warn,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const LText('Continue anyway'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Everything about one paired device: versions, what is shared, and recent syncs.
class PeerPage extends StatelessWidget {
  const PeerPage({super.key, required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.peers.where((p) => p.deviceId == deviceId).firstOrNull;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: LText('This device is no longer paired')),
      );
    }
    final name = p.name.isEmpty ? p.host : p.name;
    final mismatch =
        p.appVersion != null && !AppState.sameFeatures(p.appVersion);
    final here = app.counts;

    Future<void> sync() async {
      try {
        await app.syncPeer(p);
        if (context.mounted) showMessage(context, 'Synced with $name');
      } on VersionMismatchException {
        if (!context.mounted || !await confirmVersionMismatch(context, p)) {
          return;
        }
        if (context.mounted) await _accept(context, app, p);
      } catch (e) {
        if (context.mounted) showMessage(context, 'Could not sync: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(title: LText(name)),
      body: PageWidth(
        child: PullToSync(
          onRefresh: sync,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Room for the phone's navigation buttons (e.g. Samsung) below the last item.
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      IconBubble(
                        glyph: (s, c) => Icon(
                          Icons.phone_android_rounded,
                          size: s,
                          color: c,
                        ),
                        color: Baby.pillSoft,
                        iconColor: Baby.primary,
                        size: 56,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            LText(
                              p.host.isEmpty
                                  ? 'Address not known yet (synced by QR code)'
                                  : '${p.host}:${p.port}',
                              style: TextStyle(
                                color: Baby.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _Status(peer: p),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (p.blockedVersion != null) ...[
                const SizedBox(height: 12),
                _Banner(
                  color: Baby.warn,
                  icon: Icons.pause_circle_outline_rounded,
                  title: 'Syncing is paused',
                  text:
                      'The two phones have different app versions, which may cause sync problems. '
                      'Install the same version on both, or continue anyway.',
                  action: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Baby.warn,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (await confirmVersionMismatch(context, p) &&
                          context.mounted) {
                        await _accept(context, app, p);
                      }
                    },
                    child: const LText('Continue anyway'),
                  ),
                ),
              ] else if (mismatch && p.acceptedVersion != null) ...[
                const SizedBox(height: 12),
                _Banner(
                  color: Baby.warn,
                  icon: Icons.warning_amber_rounded,
                  title: 'Syncing despite different versions',
                  text: 'You chose to continue. If entries look wrong, update both phones to the same version.',
                  action: OutlinedButton(
                    onPressed: () => app.pauseForVersion(p),
                    child: const LText('Pause syncing'),
                  ),
                ),
              ],
              const SectionTitle('App version'),
              ListCard(
                children: [
                  _Row(label: 'This phone', value: AppState.appVersion),
                  _Row(
                    label: name,
                    value: versionLabel(p.appVersion),
                    trailing: p.appVersion == null
                        ? null
                        : Icon(
                            mismatch
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                            color: mismatch ? Baby.warn : Baby.ok,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SectionTitle('What is shared'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: SizedBox()),
                          SizedBox(width: 80, child: _Head('This phone')),
                          SizedBox(width: 80, child: _Head(name)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final (kind, label, glyph, color) in [
                        ('feed', 'Feeds', Glyphs.feed, Baby.feed),
                        ('nappy', 'Nappies', Glyphs.nappy, Baby.nappy),
                        ('pill', 'Pill doses', Glyphs.pill, Baby.pill),
                        ('med', 'Pills', Glyphs.pill, Baby.pill),
                        ('baby', 'Babies', Glyphs.baby, Baby.primary),
                        ('routine', 'Routines', Glyphs.alarm, Baby.primary),
                        ('completion', 'Routines done', Glyphs.heart, Baby.ok),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              glyph(20, color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: LText(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: _Num('${here[kind] ?? 0}'),
                              ),
                              SizedBox(
                                width: 80,
                                child: _Num(
                                  p.remoteCounts[kind]?.toString() ?? '?',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: LText(
                  'Feeds, nappies, pill doses, pills and deletions are shared. Settings, reminders, '
                  'the theme and device names stay on each phone. The counts match once both phones are in sync.',
                  style: TextStyle(
                    color: Baby.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SectionTitle('Last sync'),
              if (p.last == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LText(
                      'Not synced yet',
                      style: TextStyle(
                        color: Baby.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                ListCard(
                  children: [
                    _Row(
                      label: 'When',
                      value: '${ago(p.last!.at)} (${whenLabel(p.last!.at)})',
                    ),
                    _Row(
                      label: 'Started by',
                      value: p.last!.outgoing ? 'This phone' : name,
                    ),
                    _Row(
                      label: 'Sent',
                      value: _amount(
                        p.last!.sent,
                        p.last!.outgoing ? p.last!.newThere : null,
                        'for them',
                      ),
                    ),
                    _Row(
                      label: 'Received',
                      value: _amount(
                        p.last!.received,
                        p.last!.newHereTotal,
                        'here',
                      ),
                    ),
                    if (p.last!.newHereTotal > 0)
                      _Row(label: 'New here', value: _kinds(p.last!.newHere)),
                    if (p.last!.bytes > 0)
                      _Row(label: 'Size', value: _size(p.last!.bytes)),
                  ],
                ),
              const SectionTitle('Recent changes synced'),
              if (p.history.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LText(
                      'Nothing has changed in a sync yet',
                      style: TextStyle(
                        color: Baby.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                ListCard(
                  children: [
                    for (final r in p.history.take(15))
                      ListTile(
                        leading: Icon(
                          r.outgoing
                              ? Icons.north_east_rounded
                              : Icons.south_west_rounded,
                          color: Baby.primary,
                        ),
                        title: LText(
                          [
                            if (r.newHereTotal > 0)
                              '${_kinds(r.newHere)} came in',
                            if (r.newThere > 0) '${r.newThere} sent',
                          ].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: LText(
                          '${whenLabel(r.at)} · started by ${r.outgoing ? 'this phone' : name}',
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: app.syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: const LText('Sync now'),
                onPressed: app.syncing ? null : sync,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const LText('Sync by QR code (no Wi-Fi needed)'),
                onPressed: () => openQrSync(context, peer: p),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi_find_rounded),
                label: const LText('Find on this Wi-Fi'),
                onPressed: app.syncing
                    ? null
                    : () async {
                        showMessage(
                          context,
                          'Looking for $name on this Wi-Fi...',
                        );
                        final found = await app.findPeer(p, force: true);
                        if (!context.mounted) return;
                        if (found) {
                          showMessage(context, 'Found $name at ${p.host}');
                          await sync();
                        } else {
                          showMessage(
                            context,
                            'Not found. Is $name on the same Wi-Fi with Baby Log open?',
                          );
                        }
                      },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded),
                label: const LText('Send everything again'),
                onPressed: app.syncing
                    ? null
                    : () async {
                        try {
                          await app.resyncEverything(p);
                          if (context.mounted) {
                            showMessage(context, 'Everything sent to $name');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, 'Could not sync: $e');
                          }
                        }
                      },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Baby.error),
                icon: const Icon(Icons.link_off_rounded),
                label: const LText('Unpair this device'),
                onPressed: () {
                  app.forgetPeer(p);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, AppState app, Peer p) async {
    try {
      await app.acceptVersion(p);
      if (context.mounted) showMessage(context, 'Synced with ${p.name}');
    } catch (e) {
      if (context.mounted) showMessage(context, 'Could not sync: $e');
    }
  }

  static String _amount(int total, int? isNew, String where) {
    final records = '$total record${total == 1 ? '' : 's'}';
    return isNew == null ? records : '$records, $isNew new $where';
  }

  static String _kinds(Map<String, int> m) => [
    for (final (k, one, many) in [
      ('feed', 'feed', 'feeds'),
      ('nappy', 'nappy', 'nappies'),
      ('pill', 'pill dose', 'pill doses'),
      ('med', 'pill', 'pills'),
      ('baby', 'baby profile', 'baby profiles'),
      ('routine', 'routine', 'routines'),
      ('completion', 'routine completion', 'routine completions'),
    ])
      if ((m[k] ?? 0) > 0) '${m[k]} ${tr(m[k] == 1 ? one : many)}',
  ].join(', ');

  static String _size(int bytes) => bytes < 1024
      ? '$bytes bytes'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

class _Status extends StatelessWidget {
  const _Status({required this.peer});
  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color color,
      String text,
    ) = peer.blockedVersion != null
        ? (Icons.pause_circle_rounded, Baby.warn, 'Paused: different versions')
        : peer.lastError != null
        ? (Icons.sync_problem_rounded, Baby.warn, peer.lastError!)
        : peer.lastSync != null
        ? (Icons.check_circle_rounded, Baby.ok, 'Synced ${ago(peer.lastSync!)}')
        : (Icons.schedule_rounded, Baby.muted, 'Not synced yet');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LText(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: LText(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LText(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: action),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.trailing});
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: LText(
            label,
            style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w700),
          ),
        ),
        Flexible(
          flex: 2,
          child: LText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => LText(
    text,
    textAlign: TextAlign.right,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Baby.muted,
    ),
  );
}

class _Num extends StatelessWidget {
  const _Num(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => LText(
    text,
    textAlign: TextAlign.right,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );
}

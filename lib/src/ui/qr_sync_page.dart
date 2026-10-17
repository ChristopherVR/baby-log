import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models.dart';
import '../qr_transfer.dart';
import '../store.dart';
import '../sync.dart';
import 'common.dart';
import 'peer_page.dart';
import 'theme.dart';

void openQrSync(BuildContext context, {Peer? peer}) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => QrSyncPage(peerId: peer?.deviceId)),
);

bool get _canScan => Platform.isAndroid || Platform.isIOS;

/// Sync without shared Wi-Fi: one phone shows its changes as QR codes, the
/// other scans them, then they swap.
class QrSyncPage extends StatefulWidget {
  const QrSyncPage({super.key, this.peerId});

  /// The phone being synced with, if already known.
  final String? peerId;

  @override
  State<QrSyncPage> createState() => _QrSyncPageState();
}

class _QrSyncPageState extends State<QrSyncPage> {
  late bool showing = !_canScan;
  String? peerId;

  /// What the last scan brought in, shown until the next action.
  String? scanned;

  @override
  void initState() {
    super.initState();
    peerId = widget.peerId;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final peer = app.peers.where((p) => p.deviceId == peerId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const LText('Sync by QR code')),
      body: PageWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            LText(
              'For when the phones are not on the same Wi-Fi. One phone shows its code and the other scans '
              'it, then swap so both have everything.',
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            if (_canScan)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.qr_code_2_rounded),
                    label: LText('Show my code'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.qr_code_scanner_rounded),
                    label: LText('Scan theirs'),
                  ),
                ],
                selected: {showing},
                onSelectionChanged: (v) => setState(() {
                  showing = v.first;
                  scanned = null;
                }),
              ),
            const SizedBox(height: 16),
            if (scanned != null) ...[
              Card(
                color: Baby.nappySoft,
                child: ListTile(
                  leading: Icon(Icons.check_circle_rounded, color: Baby.ok),
                  title: LText(
                    scanned!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const LText(
                    'Now show your code so the other phone gets your changes too.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (showing)
              _ShowCodes(
                key: ValueKey('show-${peer?.deviceId}-${peer?.theirSeq}'),
                peer: peer,
              )
            else
              _Scan(
                onDone: (result) => setState(() {
                  peerId = result.peer.deviceId;
                  scanned = result.newHere.isEmpty
                      ? 'Up to date with ${result.peer.name}'
                      : 'Got ${_describe(result.newHere)} from ${result.peer.name}';
                  showing = true;
                }),
              ),
          ],
        ),
      ),
    );
  }

  static String _describe(Map<String, int> m) => [
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
}

/// Cycles through this phone's QR codes.
class _ShowCodes extends StatefulWidget {
  const _ShowCodes({super.key, required this.peer});
  final Peer? peer;

  @override
  State<_ShowCodes> createState() => _ShowCodesState();
}

class _ShowCodesState extends State<_ShowCodes> {
  List<String>? codes;
  int index = 0;
  Timer? _cycle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (codes != null) return;
    codes = AppScope.of(context).qrCodesFor(widget.peer);
    if (codes!.length > 1 && codes!.length <= QrTransfer.maxParts) {
      _cycle = Timer.periodic(const Duration(milliseconds: 800), (_) {
        setState(() => index = (index + 1) % codes!.length);
      });
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = codes!;
    if (list.length > QrTransfer.maxParts) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.info_outline_rounded, color: Baby.warn),
          title: const LText(
            'Too much to send by QR code',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: LText(
            'This would take ${list.length} codes. Connect both phones to the same Wi-Fi once; '
            'after that, QR codes only need to carry new changes.',
          ),
        ),
      );
    }
    final who = widget.peer?.name;
    return Column(
      children: [
        LText(
          who == null
              ? 'On the other phone: Sync by QR code, then Scan theirs'
              : 'Let $who scan this',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        // Dark on white so it scans well in dark mode too.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: QrImageView(
            data: list[index],
            size: 280,
            errorCorrectionLevel: QrErrorCorrectLevel.L,
          ),
        ),
        const SizedBox(height: 12),
        if (list.length > 1) ...[
          LText(
            'Code ${index + 1} of ${list.length}. Keep the camera on it until it says done.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < list.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == index ? Baby.primary : Baby.line,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ] else
          LText(
            'Includes ${widget.peer == null ? 'everything' : 'all changes since you last synced'}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}

/// Scans the other phone's codes and merges them once all parts are in.
class _Scan extends StatefulWidget {
  const _Scan({required this.onDone});
  final void Function(({Peer peer, Map<String, int> newHere}) result) onDone;

  @override
  State<_Scan> createState() => _ScanState();
}

class _ScanState extends State<_Scan> {
  final collector = QrCollector();
  bool busy = false;
  String? problem;

  Future<void> _complete() async {
    busy = true;
    final app = AppScope.of(context);
    try {
      final body = collector.result();
      try {
        widget.onDone(app.receiveQr(body));
      } on VersionMismatchException catch (e) {
        if (!mounted || !await _confirmVersion(context, e.theirVersion)) {
          setState(() => problem = 'Not synced: different app versions');
          return;
        }
        widget.onDone(app.receiveQr(body, acceptVersion: true));
      }
    } catch (e) {
      if (mounted) setState(() => problem = 'Could not read the codes: $e');
    } finally {
      busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 340,
            child: MobileScanner(
              onDetect: (capture) {
                if (busy) return;
                for (final b in capture.barcodes) {
                  final text = b.rawValue ?? '';
                  if (PairInfo.parse(text) != null) {
                    setState(
                      () => problem = 'That is a pairing code. On the other phone choose Sync by QR code.',
                    );
                  } else if (collector.add(text)) {
                    setState(() => problem = null);
                    if (collector.done) _complete();
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        LText(
          collector.total == 0
              ? 'Point the camera at the code on the other phone'
              : 'Got ${collector.received} of ${collector.total} codes',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (collector.total > 1) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: collector.received / collector.total,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        if (problem != null) ...[
          const SizedBox(height: 10),
          LText(
            problem!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Baby.warn, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

Future<bool> _confirmVersion(BuildContext context, String theirVersion) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: Baby.warn, size: 36),
      title: const LText('Different app versions'),
      content: LText(
        'This phone has version ${AppState.appVersion}, the other phone has '
        '${versionLabel(theirVersion).toLowerCase()}. Some entries could sync wrongly. Continue anyway?',
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

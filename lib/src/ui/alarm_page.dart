import 'package:flutter/material.dart';

import '../background.dart';
import '../notifications.dart';
import 'common.dart';
import 'sheets.dart';
import 'routines_page.dart';
import 'theme.dart';

/// Full screen for a ringing reminder: stop it, snooze it, or act on it
/// (mark the pill taken, log the feed).
class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, required this.info});
  final ReminderInfo info;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  @override
  void dispose() {
    BackgroundSync.leaveLockScreen();
    super.dispose();
  }

  Future<void> _close({bool snooze = false}) async {
    final reminders = AppScope.of(context).reminders;
    if (snooze) {
      await reminders.snooze(widget.info);
    } else {
      await reminders.stop(widget.info);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final info = widget.info;
    final isFeed = info.kind == 'feed';
    final isRoutine = info.kind == 'routine';
    final med = app.meds.where((m) => m.id == info.medId).firstOrNull;
    final soft = isFeed ? Baby.feedSoft : Baby.pillSoft;
    final strong = isFeed ? Baby.feed : Baby.pill;
    final navigator = Navigator.of(context);

    return PopScope(
      // Going back stops the alarm, like pressing Stop.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) app.reminders.stop(info);
      },
      child: Scaffold(
        backgroundColor: soft,
        body: SafeArea(
          child: PageWidth(
            maxWidth: 560,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  IconBubble(
                    glyph: isRoutine
                        ? Glyphs.baby
                        : isFeed
                        ? Glyphs.feed
                        : Glyphs.pill,
                    color: Baby.card,
                    iconColor: strong,
                    size: 140,
                  ),
                  const SizedBox(height: 24),
                  LText(
                    hm(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LText(
                    info.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LText(
                    info.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: Baby.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (med != null)
                    _Big(
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: strong,
                          foregroundColor: Baby.onPrimary,
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const LText('Taken'),
                        onPressed: () async {
                          app.takePill(med);
                          await _close();
                        },
                      ),
                    ),
                  if (isFeed)
                    _Big(
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: strong,
                          foregroundColor: Baby.onPrimary,
                        ),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const LText('Log feed'),
                        onPressed: () async {
                          if (info.babyId != null &&
                              !app.selectBaby(info.babyId!)) {
                            showMessage(
                              context,
                              'Save or stop the feed timer before switching babies.',
                            );
                            return;
                          }
                          await _close();
                          if (navigator.mounted) {
                            showSheet(navigator.context, const FeedSheet());
                          }
                        },
                      ),
                    ),
                  if (isRoutine)
                    _Big(
                      FilledButton.icon(
                        icon: const Icon(Icons.event_repeat_rounded),
                        label: const LText('View routines'),
                        onPressed: () async {
                          if (info.babyId != null &&
                              !app.selectBaby(info.babyId!)) {
                            showMessage(
                              context,
                              'Save or stop the feed timer before switching babies.',
                            );
                            return;
                          }
                          await _close();
                          if (navigator.mounted) {
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const LText('Routines'),
                                  ),
                                  body: const PageWidth(child: RoutinesPage()),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  _Big(
                    OutlinedButton.icon(
                      icon: const Icon(Icons.snooze_rounded),
                      label: LText('Snooze ${Reminders.snoozeMinutes} min'),
                      onPressed: () => _close(snooze: true),
                    ),
                  ),
                  _Big(
                    TextButton.icon(
                      icon: const Icon(Icons.alarm_off_rounded),
                      label: const LText('Stop'),
                      onPressed: _close,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.button);
  final Widget button;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: SizedBox(width: double.infinity, height: 58, child: button),
  );
}

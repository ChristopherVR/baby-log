import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/notifications.dart';
import 'src/store.dart';
import 'src/sync.dart';
import 'src/ui/nighttime.dart';
import 'src/ui/changelog_dialog.dart';
import 'src/ui/alarm_page.dart';
import 'src/ui/common.dart';
import 'src/ui/history_page.dart';
import 'src/ui/home_page.dart';
import 'src/ui/growth_page.dart';
import 'src/ui/pills_page.dart';
import 'src/ui/routines_page.dart';
import 'src/ui/settings_page.dart';
import 'src/ui/setup_page.dart';
import 'src/ui/theme.dart';

/// Desktop testing flags:
///   --profile=b                 separate data file (or BABYLOG_PROFILE=b), to run a second "device"
///   --pair=host:port:code       pair with another running copy on start
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  var profile = Platform.environment['BABYLOG_PROFILE'] ?? '';
  String? pair;
  for (final a in args) {
    if (a.startsWith('--profile=')) profile = a.substring('--profile='.length);
    if (a.startsWith('--pair=')) pair = a.substring('--pair='.length);
  }
  // Android's sync service starts the app with --headless (no screen yet).
  final state = await AppState.load(
    profile: profile,
    foreground: !args.contains('--headless'),
  );
  runApp(BabyApp(state: state, profile: profile));

  final p = pair?.split(':');
  if (p != null && p.length == 3) {
    try {
      await state.pair(p[0], int.tryParse(p[1]) ?? defaultSyncPort, p[2]);
    } catch (e) {
      debugPrint('Pairing failed: $e');
    }
  }
}

class BabyApp extends StatefulWidget {
  const BabyApp({super.key, required this.state, this.profile = '', this.now});
  final AppState state;
  final String profile;

  /// Local clock, injectable for testing day/night transitions.
  final DateTime Function()? now;

  @override
  State<BabyApp> createState() => _BabyAppState();
}

class _BabyAppState extends State<BabyApp> with WidgetsBindingObserver {
  late String _language;
  late bool _nighttime;
  final _navigator = GlobalKey<NavigatorState>();
  Timer? _appearanceTimer;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  void _scheduleAppearance() {
    _appearanceTimer?.cancel();
    final now = _now;
    final next = now.hour < 6
        ? DateTime(now.year, now.month, now.day, 6)
        : now.hour < 18
        ? DateTime(now.year, now.month, now.day, 18)
        : DateTime(now.year, now.month, now.day + 1, 6);
    _appearanceTimer = Timer(next.difference(now), () {
      _applyAppearance();
      _scheduleAppearance();
    });
  }

  /// A reminder was opened (tapped, or shown full screen as an alarm).
  void _openReminder(ReminderInfo info) => _navigator.currentState?.push(
    MaterialPageRoute(builder: (_) => AlarmPage(info: info)),
  );

  late final AppLifecycleListener _lifecycle;
  bool _showingChangelog = false;

  Future<void> _showChangelog() async {
    if (!Platform.isAndroid ||
        _showingChangelog ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _showingChangelog = true;
    try {
      final notes = await InstalledChangelog.load();
      final dialogContext = _navigator.currentState?.overlay?.context;
      if (!mounted ||
          dialogContext == null ||
          !dialogContext.mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          notes == null ||
          !notes.shouldShow(widget.state.changelogSeenVersion)) {
        return;
      }
      await showInstalledChangelog(dialogContext, widget.state, notes);
    } catch (error) {
      debugPrint('Could not show release notes: $error');
    } finally {
      _showingChangelog = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _language = widget.state.language;
    _nighttime = isNighttime(_now);
    AppLanguage.use(_language);
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(_applyAppearance);
    widget.state.reminders.onOpen = _openReminder;
    final launchedWith = widget.state.reminders.launchedWith;
    if (launchedWith != null) {
      widget.state.reminders.launchedWith = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openReminder(launchedWith),
      );
    }
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _applyAppearance();
        _scheduleAppearance();
        widget.state.appResumed();
        _showChangelog();
      },
      onHide: widget.state.appPaused,
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) _appearanceTimer?.cancel();
      },
    );
    Baby.dark = _wantDark;
    _scheduleAppearance();
    if (!widget.state.startedHeadless) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showChangelog());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.removeListener(_applyAppearance);
    _appearanceTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _applyAppearance();

  bool get _wantDark =>
      isNighttime(_now) ||
      switch (widget.state.appearance) {
        'dark' => true,
        'system' =>
          PlatformDispatcher.instance.platformBrightness == Brightness.dark,
        _ => false,
      };

  /// The palette is read directly by many widgets, so when it flips every
  /// widget is rebuilt, not just those that depend on the Theme.
  void _applyAppearance() {
    final dark = _wantDark;
    final nighttime = isNighttime(_now);
    if (dark == Baby.dark &&
        nighttime == _nighttime &&
        _language == widget.state.language) {
      return;
    }
    _nighttime = nighttime;
    _language = widget.state.language;
    AppLanguage.use(_language);
    Baby.dark = dark;
    void markAll(Element e) {
      e.markNeedsBuild();
      e.visitChildren(markAll);
    }

    (context as Element).visitChildren(markAll);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.state;
    return AppScope(
      state: app,
      child: MaterialApp(
        title: 'Baby Log',
        locale: Locale(app.language),
        supportedLocales: const [Locale('en'), Locale('af')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        theme: babyTheme(),
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => Column(
          children: [
            if (_nighttime) const NighttimeNotice(),
            Expanded(
              child: _nighttime
                  ? MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: child!,
                    )
                  : child!,
            ),
          ],
        ),
        // Lists can also be dragged with a mouse (Windows testing), e.g. pull to refresh.
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        navigatorKey: _navigator,
        home: Builder(
          builder: (context) => AppScope.of(context).setupDone
              ? Shell(profile: widget.profile)
              : const SetupPage(),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, this.profile = ''});
  final String profile;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final title = switch (tab) {
      0 => app.babyName.isEmpty ? 'Today' : '${app.babyName}\'s day',
      1 => 'History',
      2 => 'Pills',
      3 => 'Routines',
      _ => 'Growth',
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: LText(
          widget.profile.isEmpty ? title : '$title [${widget.profile}]',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          SyncChip(
            compact:
                MediaQuery.sizeOf(context).width <
                380 * MediaQuery.textScalerOf(context).scale(1),
          ),
          LIconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openSettings(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageWidth(
        child: Column(
          children: [
            const BabyPicker(),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  HomePage(
                    onSeeHistory: () => setState(() => tab = 1),
                    onSeeRoutines: () => setState(() => tab = 3),
                  ),
                  const HistoryPage(),
                  const PillsPage(),
                  const RoutinesPage(),
                  const GrowthPage(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: tr('Today'),
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: tr('History'),
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication_rounded),
            label: tr('Pills'),
          ),
          NavigationDestination(
            icon: Icon(Icons.event_repeat_rounded),
            label: tr('Routines'),
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_album_outlined),
            selectedIcon: Icon(Icons.photo_album_rounded),
            label: tr('Growth'),
          ),
        ],
      ),
    );
  }
}

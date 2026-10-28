import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'src/notifications.dart';
import 'src/store.dart';
import 'src/sync.dart';
import 'src/ui/nighttime.dart';
import 'src/ui/changelog_dialog.dart';
import 'src/ui/alarm_page.dart';
import 'src/ui/common.dart';
import 'src/ui/desktop/desktop_shell.dart';
import 'src/ui/global_search.dart';
import 'src/ui/history_page.dart';
import 'src/ui/home_page.dart';
import 'src/ui/growth_page.dart';
import 'src/ui/pills_page.dart';
import 'src/ui/routines_page.dart';
import 'src/ui/settings_page.dart';
import 'src/ui/sheets.dart';
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

  /// Whether the night light is dimming the palette right now.
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
    _nighttime = _wantDim;
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
    Baby.dim = _nighttime;
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

  bool get _wantDark => switch (widget.state.appearance) {
    'dark' => true,
    'system' =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    _ => false,
  };

  /// The night light dims the light palette; dark mode needs no dimming.
  bool get _wantDim =>
      widget.state.nightLight && !_wantDark && isNighttime(_now);

  /// The palette is read directly by many widgets, so when it flips every
  /// widget is rebuilt, not just those that depend on the Theme.
  void _applyAppearance() {
    final dark = _wantDark;
    final dim = _wantDim;
    if (dark == Baby.dark &&
        dim == _nighttime &&
        _language == widget.state.language) {
      return;
    }
    _nighttime = dim;
    _language = widget.state.language;
    AppLanguage.use(_language);
    Baby.dark = dark;
    Baby.dim = dim;
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
        title: 'Nestling',
        locale: Locale(app.language),
        supportedLocales: const [Locale('en'), Locale('af')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        theme: babyTheme(),
        themeAnimationDuration: Duration.zero,
        // Wide windows get the compact desktop theme, dialogs included.
        builder: (context, child) => DesktopScope(
          child: Column(
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
  final _historyKey = GlobalKey<HistoryPageState>();

  /// The tab pages keep their state when the layout switches between phone
  /// and desktop on resize.
  final _pagesKey = GlobalKey();
  bool _searching = false;

  void _goTo(int value) {
    if (value == ShellTabs.history) _historyKey.currentState?.showLog();
    if (mounted) setState(() => tab = value);
  }

  Future<void> _openSearch() async {
    if (_searching) return;
    _searching = true;
    try {
      final item = await showGlobalSearch(context);
      if (item != null && mounted) openSearchItem(context, item, _goTo);
    } finally {
      _searching = false;
    }
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, control: !mac, meta: mac);
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];
    return {
      key(LogicalKeyboardKey.keyK): _openSearch,
      key(LogicalKeyboardKey.keyF): _openSearch,
      for (var i = 0; i < digits.length; i++) key(digits[i]): () => _goTo(i),
      key(LogicalKeyboardKey.comma): () => openSettings(context),
      const SingleActivator(LogicalKeyboardKey.f5): () =>
          refreshAndSync(context),
    };
  }

  String _title(AppState app) => switch (tab) {
    0 => app.babyName.isEmpty ? 'Today' : '${app.babyName}\'s day',
    1 => 'History',
    2 => 'Pills',
    3 => 'Routines',
    _ => 'Growth',
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final title = _title(app);
    final pages = IndexedStack(
      key: _pagesKey,
      index: tab,
      children: [
        HomePage(
          onSeeHistory: () => _goTo(ShellTabs.history),
          onSeeRoutines: () => _goTo(ShellTabs.routines),
        ),
        HistoryPage(key: _historyKey),
        const PillsPage(),
        const RoutinesPage(),
        const GrowthPage(),
      ],
    );
    return DesktopScope(
      child: CallbackShortcuts(
        bindings: _shortcuts,
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= Desktop.breakpoint
                ? _desktop(context, constraints, title, pages)
                : _phone(context, constraints, title, pages),
          ),
        ),
      ),
    );
  }

  Widget _desktop(
    BuildContext context,
    BoxConstraints constraints,
    String title,
    Widget pages,
  ) {
    final expanded = constraints.maxWidth >= Desktop.wideSidebar;
    final wideSearch = constraints.maxWidth >= 1000;
    return Scaffold(
      backgroundColor: Baby.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopSidebar(
            destinations: shellDestinations,
            selected: tab,
            onSelect: _goTo,
            onSearch: _openSearch,
            expanded: expanded,
            profile: widget.profile,
          ),
          Expanded(
            key: const ValueKey('shell-content'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopTopBar(
                  title: title,
                  subtitle: tab == ShellTabs.today
                      ? '${greeting()} · ${DateFormat('EEEE d MMMM').format(DateTime.now())}'
                      : null,
                  actions: [
                    if (!expanded)
                      wideSearch
                          ? SearchTrigger(onTap: _openSearch, width: 240)
                          : LIconButton(
                              tooltip: 'Search',
                              icon: const Icon(Icons.search_rounded),
                              onPressed: _openSearch,
                            ),
                    ..._pageActions(context),
                    const RefreshSyncButton(),
                  ],
                ),
                Expanded(child: PageWidth(maxWidth: 1240, child: pages)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Main action of the current page, shown in the desktop top bar.
  List<Widget> _pageActions(BuildContext context) => switch (tab) {
    ShellTabs.today => [
      OutlinedButton.icon(
        icon: const Icon(Icons.history_rounded, size: 18),
        label: const LText('See all history'),
        onPressed: () => _goTo(ShellTabs.history),
      ),
    ],
    ShellTabs.pills => [
      FilledButton.icon(
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const LText('Add pill'),
        onPressed: () => showSheet(context, const MedEditor()),
      ),
    ],
    ShellTabs.routines => [
      FilledButton.icon(
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const LText('Add routine'),
        onPressed: () => editRoutine(context),
      ),
    ],
    _ => const [],
  };

  Widget _phone(
    BuildContext context,
    BoxConstraints constraints,
    String title,
    Widget pages,
  ) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 68,
      title: LText(
        widget.profile.isEmpty ? title : '$title [${widget.profile}]',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        LIconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          onPressed: _openSearch,
        ),
        const RefreshSyncButton(),
        SyncChip(
          compact:
              constraints.maxWidth <
              420 * MediaQuery.textScalerOf(context).scale(14) / 14,
        ),
        LIconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => openSettings(context),
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: Column(
      key: const ValueKey('shell-content'),
      children: [
        const BabyPicker(),
        Expanded(child: pages),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: _goTo,
      destinations: [
        for (final d in shellDestinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: tr(d.label),
          ),
      ],
    ),
  );
}

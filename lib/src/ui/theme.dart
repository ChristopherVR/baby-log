import 'package:flutter/material.dart';

/// Warm blush palette, one colour family per kind of entry. Every colour has
/// a light, a dim and a dark value. [dark] follows the appearance setting;
/// [dim] is the night light: a warmer, darker version of the light palette
/// used from 6 pm to 6 am so the screen is gentle in a dark room without
/// switching the whole app to dark mode.
abstract final class Baby {
  static bool dark = false;
  static bool dim = false;

  /// The app's typeface (Figtree, see assets/fonts).
  static const font = 'Figtree';

  static Color _c(int light, int dimmed, int night) =>
      Color(dark ? night : (dim ? dimmed : light));

  static Color get bg => _c(0xFFFFF8F6, 0xFFEADBD4, 0xFF1B1517);
  static Color get card => _c(0xFFFFFFFF, 0xFFF4E8E2, 0xFF271F22);
  static Color get ink => _c(0xFF3B2A2F, 0xFF33252A, 0xFFF7ECEE);
  static Color get muted => _c(0xFF7E686D, 0xFF6C575C, 0xFFB7A3A8);
  static Color get line => _c(0xFFF3E5E1, 0xFFDCC8C0, 0xFF3A2E32);
  static Color get primary => _c(0xFFD65C6C, 0xFFBF4C5C, 0xFFF4909C);
  static Color get primarySoft => _c(0xFFFDE8EA, 0xFFEFD0CF, 0xFF3D2529);
  static Color get onPrimary => _c(0xFFFFFFFF, 0xFFFFF6F2, 0xFF1B1517);
  static Color get error => _c(0xFFC8443A, 0xFFAE3A30, 0xFFFF8A80);

  /// The welcome and Today hero cards: a soft peach-to-blush wash.
  static List<Color> get hero => [
    _c(0xFFFFE6D8, 0xFFEBCDBC, 0xFF3A2826),
    _c(0xFFFCD9E0, 0xFFE6C3C6, 0xFF3A2430),
  ];

  static Color get feed => _c(0xFFE07A45, 0xFFC4632F, 0xFFFFA477);
  static Color get feedSoft => _c(0xFFFFEDE2, 0xFFEFD3C2, 0xFF3B2A24);
  static Color get nappy => _c(0xFF3A9C86, 0xFF2D826F, 0xFF66CDB4);
  static Color get nappySoft => _c(0xFFE3F4EF, 0xFFCFDFD5, 0xFF1D3430);
  static Color get sleep => _c(0xFF6A7BD4, 0xFF5767BB, 0xFFA2AEF5);
  static Color get sleepSoft => _c(0xFFEBEEFC, 0xFFD8D6E6, 0xFF262A44);
  static Color get pill => _c(0xFFA764BC, 0xFF8E52A2, 0xFFD3A0E4);
  static Color get pillSoft => _c(0xFFF5EAF8, 0xFFE3D0E0, 0xFF33263A);
  static Color get pee => _c(0xFFE3A72F, 0xFFBC8A1E, 0xFFF2C45C);
  static Color get peeSoft => _c(0xFFFFF3D6, 0xFFEEDCB5, 0xFF3A311C);
  static Color get poo => _c(0xFF9C6B52, 0xFF835842, 0xFFD1A387);
  static Color get pooSoft => _c(0xFFF5E8E0, 0xFFE3CFC2, 0xFF382B25);
  static Color get ok => nappy;
  static Color get warn => _c(0xFFE08A1F, 0xFFC27214, 0xFFF3A94F);

  /// Soft, warm shadow under raised cards on the phone layout.
  static List<BoxShadow> get shadow => dark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF8A4A55).withValues(alpha: dim ? 0.10 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

  // ---------------------------------------------------------------- desktop
  // Neutral, warm blush-grey surfaces for the desktop layout (shadcn-like): content
  // sits on [surface], panels are [card] with a 1px [border]; the sidebar is
  // a slightly darker [sidebar]. The pastel per-kind colours stay as accents.

  /// Page background on desktop.
  static Color get surface => _c(0xFFFCF8F7, 0xFFE8DAD3, 0xFF171214);

  /// Sidebar background on desktop.
  static Color get sidebar => _c(0xFFF7EFED, 0xFFDFCEC6, 0xFF1E1719);

  /// Hairline borders around cards, inputs and between regions.
  static Color get border => _c(0xFFEFE3E0, 0xFFD3C0B7, 0xFF33292C);

  /// Stronger border: inputs, outlined buttons, keyboard hints.
  static Color get borderStrong => _c(0xFFE0D1CD, 0xFFC2ADA3, 0xFF473B3F);

  /// Hover and selected-row background.
  static Color get hover => _c(0xFFF7ECE9, 0xFFDDCBC2, 0xFF2C2326);

  /// Focus ring colour.
  static Color get ring => _c(0x99D65C6C, 0x99BF4C5C, 0x99F4909C);

  /// Background behind matched text in search results.
  static Color get highlight => _c(0xFFFFEDB0, 0xFFE8D592, 0xFF5A4C1E);
}

/// Shape and size scale for the desktop design layer.
abstract final class DesktopTokens {
  static const double radiusSm = 6;
  static const double radius = 8;
  static const double radiusLg = 12;
  static const double controlHeight = 38;
  static const double topBarHeight = 56;
  static const double sidebarWidth = 248;
  static const double railWidth = 64;
}

final _themes = <(bool, bool, bool), ThemeData>{};

/// The app theme. [desktop] gives the compact, bordered desktop variant.
/// Themes are cached per palette, so calling this on every build is cheap.
ThemeData babyTheme({bool desktop = false}) {
  final key = (Baby.dark, Baby.dim, desktop);
  final cached = _themes[key];
  if (cached != null) return cached;
  final theme = desktop ? _desktopTheme(_baseTheme()) : _baseTheme();
  return _themes[key] = theme;
}

ThemeData _baseTheme() {
  const font = Baby.font;
  final brightness = Baby.dark ? Brightness.dark : Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Baby.primary,
        brightness: brightness,
      ).copyWith(
        primary: Baby.primary,
        onPrimary: Baby.onPrimary,
        secondaryContainer: Baby.primarySoft,
        onSecondaryContainer: Baby.ink,
        surface: Baby.bg,
        onSurface: Baby.ink,
        onSurfaceVariant: Baby.muted,
        outlineVariant: Baby.line,
        error: Baby.error,
        surfaceContainerLowest: Baby.card,
        surfaceContainerLow: Baby.card,
        surfaceContainer: Baby.card,
        surfaceContainerHigh: Baby.card,
        surfaceContainerHighest: Baby.line,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: font,
    scaffoldBackgroundColor: Baby.bg,
  );
  const stadium = StadiumBorder();
  const buttonText = TextStyle(
    fontFamily: font,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: 0.1,
  );
  OutlineInputBorder field(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  final t = base.textTheme.apply(bodyColor: Baby.ink, displayColor: Baby.ink);

  return base.copyWith(
    textTheme: t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.4),
    ),
    iconTheme: IconThemeData(color: Baby.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Baby.bg,
      foregroundColor: Baby.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 23,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Baby.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Baby.card,
      // A barely-there warm shadow lifts white cards off the blush page.
      elevation: Baby.dark ? 0 : 1,
      shadowColor: const Color(0x408A4A55),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Baby.card,
      indicatorColor: Baby.primarySoft,
      indicatorShape: stadium,
      selectedIconTheme: IconThemeData(color: Baby.primary),
      unselectedIconTheme: IconThemeData(color: Baby.muted),
      selectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.w800,
        color: Baby.ink,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.w600,
        color: Baby.muted,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Baby.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Baby.primarySoft,
      indicatorShape: stadium,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: font,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Baby.ink : Baby.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Baby.primary : Baby.muted,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Baby.card,
      selectedColor: Baby.primarySoft,
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.selected)
              ? Baby.primary.withValues(alpha: 0.45)
              : Baby.line,
        ),
      ),
      shape: stadium,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.w600,
        color: Baby.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(horizontal: 26),
        shape: stadium,
        textStyle: buttonText,
        animationDuration: const Duration(milliseconds: 150),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: stadium,
        textStyle: buttonText,
        foregroundColor: Baby.ink,
        backgroundColor: Baby.card,
        side: BorderSide(color: Baby.line, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: buttonText.copyWith(fontSize: 15)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Baby.primary,
      foregroundColor: Baby.onPrimary,
      shape: stadium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Baby.card,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Baby.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Baby.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Baby.dark
          ? const Color(0xFFF7ECEE)
          : const Color(0xFF3B2A2F),
      contentTextStyle: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.w600,
        color: Baby.dark ? const Color(0xFF1B1517) : Colors.white,
      ),
      actionTextColor: Baby.dark
          ? const Color(0xFFBF4C5C)
          : const Color(0xFFFFB3BC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Baby.card,
      border: field(Baby.line),
      enabledBorder: field(Baby.line),
      focusedBorder: field(Baby.primary, 1.8),
      floatingLabelStyle: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.w600,
        color: Baby.primary,
      ),
    ),
    dividerTheme: DividerThemeData(color: Baby.line, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: Baby.primary,
      textColor: Baby.ink,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? null : Baby.line,
      ),
    ),
  );
}

/// Compact, bordered variant for wide windows: 1px borders, radius 8-12,
/// 38px controls, hover states and visible focus rings.
ThemeData _desktopTheme(ThemeData base) {
  const font = Baby.font;
  final radius = BorderRadius.circular(DesktopTokens.radius);
  final shape = RoundedRectangleBorder(borderRadius: radius);
  const text = TextStyle(
    fontFamily: font,
    fontWeight: FontWeight.w700,
    fontSize: 14,
  );
  const size = Size(40, DesktopTokens.controlHeight);
  const padding = EdgeInsets.symmetric(horizontal: 14);
  BorderSide? ring(Set<WidgetState> s, [BorderSide? otherwise]) =>
      s.contains(WidgetState.focused)
      ? BorderSide(color: Baby.ring, width: 2)
      : otherwise;
  WidgetStateProperty<Color?> overlay(Color color) =>
      WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed)
            ? color.withValues(alpha: 0.14)
            : s.contains(WidgetState.hovered)
            ? color.withValues(alpha: 0.08)
            : s.contains(WidgetState.focused)
            ? color.withValues(alpha: 0.06)
            : null,
      );
  OutlineInputBorder input(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  final t = base.textTheme;
  return base.copyWith(
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: NoSplash.splashFactory,
    scaffoldBackgroundColor: Baby.surface,
    colorScheme: base.colorScheme.copyWith(
      surface: Baby.surface,
      outline: Baby.borderStrong,
      outlineVariant: Baby.border,
    ),
    hoverColor: Baby.hover,
    focusColor: Baby.ring.withValues(alpha: 0.12),
    highlightColor: Baby.hover,
    textTheme: t.copyWith(
      headlineSmall: t.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 15),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, color: Baby.muted),
      labelLarge: t.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: Baby.surface,
      toolbarHeight: DesktopTokens.topBarHeight,
      shape: Border(bottom: BorderSide(color: Baby.border)),
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(fontSize: 18),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: Baby.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopTokens.radiusLg),
        side: BorderSide(color: Baby.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(size),
        padding: const WidgetStatePropertyAll(padding),
        shape: WidgetStatePropertyAll(shape),
        textStyle: const WidgetStatePropertyAll(text),
        side: WidgetStateProperty.resolveWith(ring),
        overlayColor: overlay(Baby.onPrimary),
        elevation: const WidgetStatePropertyAll(0),
        animationDuration: const Duration(milliseconds: 120),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(size),
        padding: const WidgetStatePropertyAll(padding),
        shape: WidgetStatePropertyAll(shape),
        textStyle: const WidgetStatePropertyAll(text),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? Baby.muted : Baby.ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered) ? Baby.hover : Baby.card,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => ring(s, BorderSide(color: Baby.borderStrong)),
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        shape: WidgetStatePropertyAll(shape),
        textStyle: const WidgetStatePropertyAll(text),
        side: WidgetStateProperty.resolveWith(ring),
        overlayColor: overlay(Baby.ink),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        iconSize: const WidgetStatePropertyAll(20),
        shape: WidgetStatePropertyAll(shape),
        side: WidgetStateProperty.resolveWith(ring),
        overlayColor: overlay(Baby.ink),
      ),
    ),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      shape: shape,
      elevation: 1,
      hoverElevation: 2,
      focusElevation: 2,
      highlightElevation: 2,
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 40),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
      extendedTextStyle: text,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopTokens.radius),
      ),
      side: BorderSide(color: Baby.border),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      labelStyle: base.chipTheme.labelStyle?.copyWith(fontSize: 13),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Baby.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: input(Baby.borderStrong),
      enabledBorder: input(Baby.borderStrong),
      focusedBorder: input(Baby.primary, 1.5),
      hoverColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Baby.card,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopTokens.radiusLg),
        side: BorderSide(color: Baby.border),
      ),
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Baby.ink,
      ),
      insetPadding: const EdgeInsets.all(32),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesktopTokens.radiusLg),
        ),
        side: BorderSide(color: Baby.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Baby.card,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Baby.border),
      ),
      textStyle: TextStyle(fontFamily: font, fontSize: 14, color: Baby.ink),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      textStyle: TextStyle(
        fontFamily: font,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Baby.dark ? const Color(0xFF1B1517) : Colors.white,
      ),
      decoration: BoxDecoration(
        color: Baby.dark ? const Color(0xFFF7ECEE) : const Color(0xFF3B2A2F),
        borderRadius: BorderRadius.circular(DesktopTokens.radiusSm),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => Baby.muted.withValues(
          alpha:
              s.contains(WidgetState.dragged) || s.contains(WidgetState.hovered)
              ? 0.55
              : 0.3,
        ),
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      shape: shape,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: Baby.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Baby.muted,
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelStyle: const TextStyle(
        fontFamily: font,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: font,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      dividerColor: Baby.border,
      overlayColor: overlay(Baby.ink),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      width: 440,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopTokens.radius),
      ),
    ),
    dividerTheme: DividerThemeData(color: Baby.border, space: 1, thickness: 1),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(shape),
        side: WidgetStatePropertyAll(BorderSide(color: Baby.borderStrong)),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

/// Soft pastel palette, one colour family per kind of entry. Every colour has
/// a light, a dim and a dark value. [dark] follows the appearance setting;
/// [dim] is the night light: a warmer, darker version of the light palette
/// used from 6 pm to 6 am so the screen is gentle in a dark room without
/// switching the whole app to dark mode.
abstract final class Baby {
  static bool dark = false;
  static bool dim = false;

  static Color _c(int light, int dimmed, int night) =>
      Color(dark ? night : (dim ? dimmed : light));

  static Color get bg => _c(0xFFFFF8F2, 0xFFE4D8CA, 0xFF1A1922);
  static Color get card => _c(0xFFFFFFFF, 0xFFEEE4D8, 0xFF25232F);
  static Color get ink => _c(0xFF34304A, 0xFF2E2938, 0xFFF1EDF7);
  static Color get muted => _c(0xFF8A849A, 0xFF6F6779, 0xFFA59FB5);
  static Color get line => _c(0xFFF1E6DE, 0xFFD5C7B7, 0xFF363244);
  static Color get primary => _c(0xFF7C6FDC, 0xFF6658C4, 0xFFA99BFF);
  static Color get onPrimary => _c(0xFFFFFFFF, 0xFFFFF6EC, 0xFF1A1922);
  static Color get error => _c(0xFFC8443A, 0xFFAE3A30, 0xFFFF8A80);

  static Color get feed => _c(0xFFE9795A, 0xFFC9603F, 0xFFFF9C80);
  static Color get feedSoft => _c(0xFFFFE7DD, 0xFFEBCDBB, 0xFF3B2A28);
  static Color get nappy => _c(0xFF34A27F, 0xFF2A876A, 0xFF5FCDA7);
  static Color get nappySoft => _c(0xFFDDF4EA, 0xFFCFDECF, 0xFF1E3530);
  static Color get pill => primary;
  static Color get pillSoft => _c(0xFFEDE9FC, 0xFFDDD1E2, 0xFF2D2946);
  static Color get pee => _c(0xFFE0A21F, 0xFFB98512, 0xFFF2C14E);
  static Color get peeSoft => _c(0xFFFFF1CF, 0xFFEBD9AE, 0xFF39311C);
  static Color get poo => _c(0xFF9A6A4F, 0xFF815640, 0xFFCF9F82);
  static Color get pooSoft => _c(0xFFF4E6DC, 0xFFE2CFBE, 0xFF372B25);
  static Color get ok => nappy;
  static Color get warn => _c(0xFFE08A1F, 0xFFC27214, 0xFFF3A94F);

  // ---------------------------------------------------------------- desktop
  // Neutral, warm-grey surfaces for the desktop layout (shadcn-like): content
  // sits on [surface], panels are [card] with a 1px [border]; the sidebar is
  // a slightly darker [sidebar]. The pastel per-kind colours stay as accents.

  /// Page background on desktop.
  static Color get surface => _c(0xFFFAF8F6, 0xFFE6DCCF, 0xFF16151C);

  /// Sidebar background on desktop.
  static Color get sidebar => _c(0xFFF4F1EE, 0xFFDDD1C3, 0xFF1C1B23);

  /// Hairline borders around cards, inputs and between regions.
  static Color get border => _c(0xFFE8E3DE, 0xFFCDBFAF, 0xFF2F2D3A);

  /// Stronger border: inputs, outlined buttons, keyboard hints.
  static Color get borderStrong => _c(0xFFD8D2CC, 0xFFBDAE9D, 0xFF423F50);

  /// Hover and selected-row background.
  static Color get hover => _c(0xFFF1EDE9, 0xFFD9CCBC, 0xFF292733);

  /// Focus ring colour.
  static Color get ring => _c(0x997C6FDC, 0x996658C4, 0x99A99BFF);

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
  const font = 'Nunito';
  final brightness = Baby.dark ? Brightness.dark : Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Baby.primary,
        brightness: brightness,
      ).copyWith(
        primary: Baby.primary,
        onPrimary: Baby.onPrimary,
        secondaryContainer: Baby.pillSoft,
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
  );
  final rounded14 = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Baby.line),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Baby.ink,
      displayColor: Baby.ink,
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
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: Baby.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Baby.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Baby.card,
      indicatorColor: Baby.pillSoft,
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
      indicatorColor: Baby.pillSoft,
      indicatorShape: stadium,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: font,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
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
      selectedColor: Baby.pillSoft,
      side: BorderSide(color: Baby.line.withValues(alpha: 0.6)),
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
          ? const Color(0xFFF1EDF7)
          : const Color(0xFF34304A),
      contentTextStyle: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.w600,
        color: Baby.dark ? const Color(0xFF1A1922) : Colors.white,
      ),
      actionTextColor: Baby.dark
          ? const Color(0xFF5B4FC0)
          : const Color(0xFFCFC8FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Baby.card,
      border: rounded14,
      enabledBorder: rounded14,
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
  const font = 'Nunito';
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
        color: Baby.dark ? const Color(0xFF1A1922) : Colors.white,
      ),
      decoration: BoxDecoration(
        color: Baby.dark ? const Color(0xFFF1EDF7) : const Color(0xFF2B2833),
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

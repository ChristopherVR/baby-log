import 'package:flutter/material.dart';

/// Soft pastel palette, one colour family per kind of entry. Every colour has
/// a light and a dark value; [dark] is switched by the app from the
/// appearance setting and local nighttime schedule.
abstract final class Baby {
  static bool dark = false;

  static Color _c(int light, int night) => Color(dark ? night : light);

  static Color get bg => _c(0xFFFFF8F2, 0xFF1A1922);
  static Color get card => _c(0xFFFFFFFF, 0xFF25232F);
  static Color get ink => _c(0xFF34304A, 0xFFF1EDF7);
  static Color get muted => _c(0xFF8A849A, 0xFFA59FB5);
  static Color get line => _c(0xFFF1E6DE, 0xFF363244);
  static Color get primary => _c(0xFF7C6FDC, 0xFFA99BFF);
  static Color get onPrimary => _c(0xFFFFFFFF, 0xFF1A1922);
  static Color get error => _c(0xFFC8443A, 0xFFFF8A80);

  static Color get feed => _c(0xFFE9795A, 0xFFFF9C80);
  static Color get feedSoft => _c(0xFFFFE7DD, 0xFF3B2A28);
  static Color get nappy => _c(0xFF34A27F, 0xFF5FCDA7);
  static Color get nappySoft => _c(0xFFDDF4EA, 0xFF1E3530);
  static Color get pill => primary;
  static Color get pillSoft => _c(0xFFEDE9FC, 0xFF2D2946);
  static Color get pee => _c(0xFFE0A21F, 0xFFF2C14E);
  static Color get peeSoft => _c(0xFFFFF1CF, 0xFF39311C);
  static Color get poo => _c(0xFF9A6A4F, 0xFFCF9F82);
  static Color get pooSoft => _c(0xFFF4E6DC, 0xFF372B25);
  static Color get ok => nappy;
  static Color get warn => _c(0xFFE08A1F, 0xFFF3A94F);
}

ThemeData babyTheme() {
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
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Baby.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Baby.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Baby.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Baby.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Baby.pillSoft,
      height: 68,
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
      side: BorderSide(color: Baby.line),
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
        minimumSize: const Size(64, 52),
        shape: stadium,
        textStyle: buttonText,
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

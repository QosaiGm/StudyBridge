import 'package:flutter/material.dart';

abstract final class StudyBridgeColors {
  // Midnight plum, smoked violet, and restrained champagne accents.
  static const lavender = Color(0xFFC7A7FF);
  static const purple = Color(0xFFA77AE8);
  static const cream = Color(0xFFF2EADB);
  static const pink = Color(0xFFD8A5C1);
  static const background = Color(0xFF0B0911);
  static const surface = Color(0xFF14111C);
  static const elevated = Color(0xFF1C1726);
  static const ink = Color(0xFFF3EDF7);
  static const muted = Color(0xFFB0A5BA);
  static const lilacWash = Color(0xFF292135);
  static const border = Color(0xFF352C41);
  static const gold = Color(0xFFD7BD84);
  static const success = Color(0xFF8DBDA2);
  static const danger = Color(0xFFE59CA8);
}

abstract final class StudyBridgeTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: StudyBridgeColors.purple,
      brightness: Brightness.dark,
      primary: StudyBridgeColors.lavender,
      onPrimary: const Color(0xFF21152F),
      secondary: StudyBridgeColors.gold,
      onSecondary: const Color(0xFF211B10),
      surface: StudyBridgeColors.surface,
      onSurface: StudyBridgeColors.ink,
      error: StudyBridgeColors.danger,
    );
    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: StudyBridgeColors.border),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: StudyBridgeColors.background,
      canvasColor: StudyBridgeColors.surface,
      fontFamily: 'NotoNaskhArabic',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: StudyBridgeColors.ink,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          color: StudyBridgeColors.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        titleLarge: TextStyle(
          color: StudyBridgeColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: StudyBridgeColors.ink,
          fontSize: 16,
          height: 1.65,
        ),
        bodyMedium: TextStyle(
          color: StudyBridgeColors.muted,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: StudyBridgeColors.background,
        foregroundColor: StudyBridgeColors.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StudyBridgeColors.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: StudyBridgeColors.muted),
        labelStyle: const TextStyle(color: StudyBridgeColors.muted),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(
            color: StudyBridgeColors.lavender,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StudyBridgeColors.lavender,
          foregroundColor: const Color(0xFF21152F),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: StudyBridgeColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: StudyBridgeColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: StudyBridgeColors.surface,
        indicatorColor: StudyBridgeColors.lilacWash,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? StudyBridgeColors.ink
                : StudyBridgeColors.muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: StudyBridgeColors.elevated,
        selectedColor: StudyBridgeColors.lilacWash,
        side: const BorderSide(color: StudyBridgeColors.border),
        labelStyle: const TextStyle(color: StudyBridgeColors.ink),
        secondaryLabelStyle: const TextStyle(color: StudyBridgeColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: StudyBridgeColors.border,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: StudyBridgeColors.elevated,
        contentTextStyle: TextStyle(color: StudyBridgeColors.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: StudyBridgeColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: StudyBridgeColors.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StudyBridgeColors.lavender,
      ),
    );
  }
}

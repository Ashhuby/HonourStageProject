import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Builds the application [ThemeData].
///
/// Exported as a top-level function so [MyApp] stays lean. All token
/// decisions are co-located here rather than scattered across widget trees.
ThemeData buildAppTheme() {
  const bg = OneRepColors.background;
  const surface = OneRepColors.surface;
  const accent = OneRepColors.accent;

  const colorScheme = ColorScheme.dark(
    brightness: Brightness.dark,
    primary: accent,
    onPrimary: OneRepColors.background,
    secondary: OneRepColors.gold,
    onSecondary: OneRepColors.background,
    surface: surface,
    onSurface: OneRepColors.textPrimary,
    surfaceContainerHighest: OneRepColors.surfaceHighest,
    onSurfaceVariant: OneRepColors.textSecondary,
    error: OneRepColors.error,
    outline: OneRepColors.surfaceHighest,
    primaryContainer: OneRepColors.surfaceElevated,
    onPrimaryContainer: OneRepColors.textPrimary,
    secondaryContainer: OneRepColors.surfaceElevated,
    onSecondaryContainer: OneRepColors.gold,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: bg,

    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: OneRepColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: OneRepColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: OneRepColors.textSecondary),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: OneRepColors.gold,
      unselectedLabelColor: OneRepColors.textSecondary,
      indicatorColor: OneRepColors.gold,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: OneRepColors.surfaceElevated,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OneRepColors.surfaceElevated, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: OneRepColors.background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: OneRepColors.background,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: OneRepColors.gold,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: const BorderSide(color: OneRepColors.surfaceHighest),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OneRepColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OneRepColors.surfaceHighest),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OneRepColors.surfaceHighest),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OneRepColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OneRepColors.error),
      ),
      labelStyle: const TextStyle(color: OneRepColors.textSecondary),
      hintStyle: const TextStyle(color: OneRepColors.textDisabled),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: OneRepColors.textSecondary,
      titleTextStyle: TextStyle(
        color: OneRepColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(
        color: OneRepColors.textSecondary,
        fontSize: 13,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: OneRepColors.surfaceElevated,
      thickness: 1,
      space: 1,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: OneRepColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: OneRepColors.surfaceElevated,
      labelStyle: const TextStyle(
        color: OneRepColors.textSecondary,
        fontSize: 12,
      ),
      side: const BorderSide(color: OneRepColors.surfaceHighest),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: OneRepColors.surfaceElevated,
      contentTextStyle: const TextStyle(color: OneRepColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: OneRepColors.gold,
      foregroundColor: OneRepColors.background,
      elevation: 0,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: OneRepColors.gold,
      linearTrackColor: OneRepColors.surfaceHighest,
    ),

    sliderTheme: const SliderThemeData(
      activeTrackColor: OneRepColors.gold,
      thumbColor: OneRepColors.gold,
      inactiveTrackColor: OneRepColors.surfaceHighest,
      overlayColor: OneRepColors.goldDim,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: OneRepColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        color: OneRepColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: OneRepColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    ),

    iconTheme: const IconThemeData(color: OneRepColors.textSecondary),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: OneRepColors.textPrimary, height: 1.5),
      bodyMedium: TextStyle(color: OneRepColors.textSecondary, height: 1.5),
      bodySmall: TextStyle(color: OneRepColors.textSecondary),
      labelLarge: TextStyle(
        color: OneRepColors.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );
}

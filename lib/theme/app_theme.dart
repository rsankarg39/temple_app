import 'package:flutter/material.dart';

/// Consistent typography and theming across Android, iOS, and web.
/// Web loads Noto Sans via [web/index.html]; mobile uses fallbacks if missing.
class AppTheme {
  static const Color seedColor = Color(0xFFE65100);
  static const Color bodyColor = Color(0xFF1A1A1A);
  static const Color subtitleColor = Color(0xFF616161);

  static const String fontFamily = 'Noto Sans';
  static const List<String> fontFamilyFallback = [
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static Future<void> preloadFonts() async {
    // Web: fonts preloaded in index.html. No async work required.
  }

  static TextTheme _textTheme(TextTheme base) {
    return base
        .apply(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          bodyColor: bodyColor,
          displayColor: bodyColor,
        )
        .copyWith(
          titleLarge: base.titleLarge?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            height: 1.35,
            color: bodyColor,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            height: 1.35,
            color: bodyColor,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.35,
            color: bodyColor,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 16,
            height: 1.45,
            color: bodyColor,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 14,
            height: 1.45,
            color: bodyColor,
          ),
          bodySmall: base.bodySmall?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 12,
            height: 1.4,
            color: subtitleColor,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.3,
            color: bodyColor,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 12,
            height: 1.3,
            color: bodyColor,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 11,
            height: 1.25,
            color: subtitleColor,
          ),
        );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    );

    final textTheme = _textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 56,
        titleTextStyle: textTheme.titleLarge,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(
          color: base.colorScheme.error,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 8,
        minLeadingWidth: 28,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelMedium,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }

}

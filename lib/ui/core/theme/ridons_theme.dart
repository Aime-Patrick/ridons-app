import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/models/app_role.dart';
import 'ridons_colors.dart';

abstract final class RidonsTheme {
  static ThemeData forRole(
    AppRole role, {
    Brightness brightness = Brightness.light,
  }) {
    final seed = role.isPassenger ? RidonsColors.primary : RidonsColors.navy;
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? ColorScheme.dark(
            primary: seed,
            onPrimary: Colors.white,
            secondary: RidonsColors.accent,
            onSecondary: RidonsColors.navy,
            surface: RidonsColors.darkSurface,
            onSurface: RidonsColors.darkInk,
            onSurfaceVariant: RidonsColors.darkMuted,
            error: RidonsColors.primary,
            onError: Colors.white,
          ).copyWith(
            surfaceContainerHighest: RidonsColors.darkFill,
            outline: RidonsColors.darkLine,
          )
        : ColorScheme.light(
            primary: seed,
            onPrimary: Colors.white,
            secondary: RidonsColors.accent,
            onSecondary: RidonsColors.navy,
            surface: RidonsColors.surface,
            onSurface: RidonsColors.textPrimary,
            onSurfaceVariant: RidonsColors.textSecondary,
            error: RidonsColors.primary,
            onError: Colors.white,
          ).copyWith(
            surfaceContainerHighest: RidonsColors.inputFill,
            outline: RidonsColors.border,
          );
    final textColor = scheme.onSurface;
    final pageColor = isDark ? RidonsColors.darkPage : RidonsColors.background;
    final lineColor = isDark ? RidonsColors.darkLine : RidonsColors.border;
    final fillColor = isDark ? RidonsColors.darkFill : RidonsColors.inputFill;

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageColor,
      canvasColor: pageColor,
      textTheme: textTheme,
      primaryColor: seed,
      splashColor: seed.withValues(alpha: 0.12),
      highlightColor: seed.withValues(alpha: 0.08),
      appBarTheme: AppBarTheme(
        backgroundColor: pageColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RidonsColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? RidonsColors.primary.withValues(alpha: 0.35)
              : const Color(0xFFF4B4B6),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: isDark ? fillColor : RidonsColors.surface,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: BorderSide(color: lineColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: isDark ? RidonsColors.darkMuted : RidonsColors.textSecondary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        // Navigation selection uses the Ridons brand red in both themes and
        // for both roles. Role colors still control the rest of the theme.
        selectedItemColor: RidonsColors.primary,
        unselectedItemColor:
            isDark ? RidonsColors.darkMuted : RidonsColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerColor: isDark ? const Color(0xFF1F2937) : RidonsColors.border,
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textColor,
        textColor: textColor,
        selectedColor: seed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? RidonsColors.darkFill : RidonsColors.navy,
        contentTextStyle: TextStyle(
          color: isDark ? RidonsColors.darkInk : Colors.white,
        ),
      ),
    );
  }

  static ThemeData get passenger => forRole(AppRole.passenger);
  static ThemeData get driver => forRole(AppRole.driver);
}

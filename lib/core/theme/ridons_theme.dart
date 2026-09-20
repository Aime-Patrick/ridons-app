import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../role/app_role.dart';
import 'ridons_colors.dart';

abstract final class RidonsTheme {
  static ThemeData passenger() => _build(
        seed: RidonsColors.primary,
        primary: RidonsColors.primary,
      );

  static ThemeData driver() => _build(
        seed: RidonsColors.navy,
        primary: RidonsColors.navy,
      );

  static ThemeData forRole(RidonsAppRole role) =>
      role == RidonsAppRole.driver ? driver() : passenger();

  static ThemeData _build({
    required Color seed,
    required Color primary,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: primary,
      onPrimary: Colors.white,
      surface: RidonsColors.surface,
      onSurface: RidonsColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: RidonsColors.background,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: RidonsColors.surface,
        foregroundColor: RidonsColors.text,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: RidonsColors.text,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RidonsColors.text,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: RidonsColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RidonsColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RidonsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RidonsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: RidonsColors.muted),
      ),
      dividerTheme: const DividerThemeData(
        color: RidonsColors.border,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: RidonsColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

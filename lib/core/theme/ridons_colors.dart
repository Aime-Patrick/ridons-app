import 'package:flutter/material.dart';

/// Brand tokens from Ridons ASSETS.md / style.css.
abstract final class RidonsColors {
  static const primary = Color(0xFFC91D22);
  static const primaryDark = Color(0xFF9B1419);
  static const primaryDarker = Color(0xFF7A1014);
  static const primaryLight = Color(0xFFFEE2E4);
  static const primarySoft = Color(0xFFFEF1F2);

  static const navy = Color(0xFF0F172A);
  static const accent = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);

  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const muted = Color(0xFF64748B);
  static const text = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);

  static const splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryDarker],
  );
}

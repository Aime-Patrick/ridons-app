import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand tokens from `ridons/docs/ASSETS.md` and `css/style.css`.
abstract final class RidonsColors {
  static const Color primary = Color(0xFFC91D22);
  static const Color primaryDark = Color(0xFF9B1419);
  static const Color primaryDarker = Color(0xFF7A1014);
  static const Color primaryLight = Color(0xFFFEE2E4);
  static const Color primarySoft = Color(0xFFFEF1F2);

  static const Color navy = Color(0xFF0F172A);
  static const Color accent = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color inputFill = Color(0xFFF1F5F9);

  static const Color darkPage = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkInk = Color(0xFFF8FAFC);
  static const Color darkMuted = Color(0xFF94A3B8);
  static const Color darkLine = Color(0xFF334155);
  static const Color darkFill = Color(0xFF1E293B);

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryDarker],
  );
}

/// Light/dark colors for sheets, fields, and map overlays.
extension RidonsThemeColors on BuildContext {
  bool get ridonsDark => Theme.of(this).brightness == Brightness.dark;

  ColorScheme get ridonsScheme => Theme.of(this).colorScheme;

  Color get ridonsPage =>
      ridonsDark ? RidonsColors.darkPage : RidonsColors.background;

  Color get ridonsSheet =>
      ridonsDark ? RidonsColors.darkSurface : ridonsScheme.surface;

  Color get ridonsInk =>
      ridonsDark ? RidonsColors.darkInk : RidonsColors.textPrimary;

  Color get ridonsMuted =>
      ridonsDark ? RidonsColors.darkMuted : RidonsColors.textSecondary;

  Color get ridonsLine =>
      ridonsDark ? RidonsColors.darkLine : RidonsColors.border;

  Color get ridonsFill =>
      ridonsDark ? RidonsColors.darkFill : RidonsColors.inputFill;

  Color get ridonsSoft => ridonsDark
      ? RidonsColors.primary.withValues(alpha: 0.18)
      : RidonsColors.primarySoft;

  SystemUiOverlayStyle get ridonsOverlay {
    final dark = Theme.of(this).brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: ridonsPage,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }
}

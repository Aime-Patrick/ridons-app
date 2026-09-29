import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/ridons_colors.dart';

enum RidonsNoticeTone { info, success, warning, error }

/// Consistent transient feedback for actions throughout the app.
///
/// Screen-level load failures should still use an inline retry state. This is
/// for short-lived action results such as save, copy, upload, or call errors.
class RidonsNotice {
  const RidonsNotice._();

  static void show(
    BuildContext context,
    String message, {
    RidonsNoticeTone tone = RidonsNoticeTone.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || message.trim().isEmpty) return;

    final colors = _colors(context, tone);
    final localizedMessage = message.tr();
    final localizedAction = actionLabel?.tr();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          backgroundColor: colors.background,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(colors.icon, color: colors.foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  localizedMessage,
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: localizedAction == null || onAction == null
              ? null
              : SnackBarAction(
                  label: localizedAction,
                  textColor: colors.foreground,
                  onPressed: onAction,
                ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.success);

  static void info(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.info);

  static void warning(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.warning);

  static void error(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.error);

  static _NoticeColors _colors(BuildContext context, RidonsNoticeTone tone) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      RidonsNoticeTone.success => _NoticeColors(
        background: dark ? const Color(0xFF14532D) : const Color(0xFF166534),
        foreground: Colors.white,
        icon: Icons.check_circle_outline_rounded,
      ),
      RidonsNoticeTone.warning => _NoticeColors(
        background: dark ? const Color(0xFF78350F) : const Color(0xFFB45309),
        foreground: Colors.white,
        icon: Icons.warning_amber_rounded,
      ),
      RidonsNoticeTone.error => _NoticeColors(
        background: dark ? const Color(0xFF7F1D1D) : RidonsColors.primaryDark,
        foreground: Colors.white,
        icon: Icons.error_outline_rounded,
      ),
      RidonsNoticeTone.info => _NoticeColors(
        background: dark ? RidonsColors.darkFill : RidonsColors.navy,
        foreground: dark ? RidonsColors.darkInk : Colors.white,
        icon: Icons.info_outline_rounded,
      ),
    };
  }
}

class _NoticeColors {
  const _NoticeColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

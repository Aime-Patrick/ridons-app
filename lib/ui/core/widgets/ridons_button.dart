import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/ridons_colors.dart';

enum RidonsButtonVariant { primary, secondary, outline }

/// Full-width action button used across auth and ride flows.
class RidonsButton extends StatelessWidget {
  const RidonsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RidonsButtonVariant.primary,
    this.isLoading = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final RidonsButtonVariant variant;
  final bool isLoading;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == RidonsButtonVariant.primary
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Text(label.tr()),
            ],
          );

    return switch (variant) {
      RidonsButtonVariant.primary => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: RidonsColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              Theme.of(context).brightness == Brightness.dark
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
        ),
        child: child,
      ),
      RidonsButtonVariant.secondary => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : const Color(0xFFE2E8F0),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: child,
      ),
      RidonsButtonVariant.outline => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.ridonsInk,
          backgroundColor: context.ridonsDark
              ? RidonsColors.darkFill
              : RidonsColors.surface,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          side: BorderSide(color: context.ridonsLine, width: 1),
        ),
        child: child,
      ),
    };
  }
}

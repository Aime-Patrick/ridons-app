import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ridons_colors.dart';

class CoverageStatusSheet extends StatelessWidget {
  const CoverageStatusSheet({
    super.key,
    required this.messageKey,
    required this.isChecking,
    required this.isError,
    required this.actionLabelKey,
    required this.onAction,
  });

  final String messageKey;
  final bool isChecking;
  final bool isError;
  final String actionLabelKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.56),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isChecking)
                    SizedBox(
                      height: 156,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: RidonsColors.primary,
                        ),
                      ),
                    )
                  else if (!isError)
                    Image.asset(
                      'assets/image/out_of_service_area.gif',
                      width: 164,
                      height: 156,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.location_off_outlined,
                        size: 76,
                        color: RidonsColors.primary,
                      ),
                    )
                  else
                    SizedBox(
                      height: 156,
                      child: Icon(
                        Icons.wifi_tethering_error_rounded,
                        size: 72,
                        color: RidonsColors.primary,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    (isChecking
                            ? 'coverage_checking_title'
                            : isError
                            ? 'coverage_error_title'
                            : 'out_of_service_title')
                        .tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    messageKey.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isChecking ? null : onAction,
                      child: Text(actionLabelKey.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

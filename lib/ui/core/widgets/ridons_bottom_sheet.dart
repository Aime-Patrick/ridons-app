import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/ridons_colors.dart';

/// Rounded sheet used under map / onboarding hero. Follows phone light/dark.
class RidonsBottomSheet extends StatelessWidget {
  const RidonsBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.showHandle = true,
    this.decorate = true,
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;
  final bool showHandle;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHandle)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.ridonsLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        if (title != null) ...[
          Text(
            title!.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.ridonsInk,
            ),
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    );

    if (!decorate) {
      return Padding(padding: padding, child: inner);
    }

    return Material(
      color: context.ridonsSheet,
      elevation: 12,
      shadowColor: const Color(0x33000000),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: inner),
    );
  }
}

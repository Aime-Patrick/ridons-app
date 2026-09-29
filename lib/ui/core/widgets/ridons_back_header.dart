import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Back chevron + optional title used on auth screens.
class RidonsBackHeader extends StatelessWidget {
  const RidonsBackHeader({super.key, this.title, this.onBack});

  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        if (title != null)
          Expanded(
            child: Text(
              title!.tr(),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

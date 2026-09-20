import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';

class RidonsTextLink extends StatelessWidget {
  const RidonsTextLink({
    super.key,
    required this.text,
    required this.onTap,
    this.prefix,
    this.underline = false,
  });

  final String text;
  final VoidCallback? onTap;
  final String? prefix;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          decoration: underline ? TextDecoration.underline : null,
          decorationColor: Theme.of(context).colorScheme.primary,
        );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix != null)
          Text(
            prefix!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RidonsColors.textSecondary,
                ),
          ),
        GestureDetector(
          onTap: onTap,
          child: Text(text, style: linkStyle),
        ),
      ],
    );
  }
}

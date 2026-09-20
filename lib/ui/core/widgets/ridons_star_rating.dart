import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';

class RidonsStarRating extends StatelessWidget {
  const RidonsStarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= value;
        return IconButton(
          onPressed: onChanged == null ? null : () => onChanged!(star),
          iconSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          constraints: BoxConstraints(minWidth: size, minHeight: size),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? RidonsColors.accent : const Color(0xFF94A3B8),
          ),
        );
      }),
    );
  }
}

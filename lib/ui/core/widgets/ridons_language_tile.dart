import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';

/// Language selection row with flag/icon and custom radio checkmark.
class RidonsLanguageTile extends StatelessWidget {
  const RidonsLanguageTile({
    super.key,
    required this.title,
    required this.flag,
    required this.isSelected,
    required this.onTap,
    this.outlined = false,
  });

  final String title;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: outlined
              ? Colors.transparent
              : (isSelected ? context.ridonsSoft : context.ridonsFill),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: outlined
                ? (isSelected ? RidonsColors.primary : context.ridonsLine)
                : (isSelected ? RidonsColors.primary : Colors.transparent),
            width: outlined ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: context.ridonsInk,
                    ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? RidonsColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? RidonsColors.primary : context.ridonsMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/ridons_colors.dart';

/// Compact role selection card (Passenger vs Driver) with a 3D avatar.
class RidonsRoleCard extends StatelessWidget {
  const RidonsRoleCard({
    super.key,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.isSelected,
    required this.onTap,
    required this.scale,
  });

  final String title;
  final String description;
  final String imageAsset;
  final bool isSelected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 16 * scale,
          ),
          decoration: BoxDecoration(
            color: isSelected ? context.ridonsSoft : context.ridonsSheet,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? RidonsColors.primary : context.ridonsLine,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: RidonsColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 93 * scale,
                        height: 93 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.ridonsFill,
                          border: Border.all(
                            color: isSelected
                                ? RidonsColors.primaryLight
                                : context.ridonsSheet,
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            size: 36,
                            color: RidonsColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        title.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w600,
                          height: 0.88,
                          color: context.ridonsInk,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        description.tr(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                        style: GoogleFonts.inter(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w400,
                          height: 1,
                          color: context.ridonsMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

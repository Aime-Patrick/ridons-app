import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';

/// Responsive pickup-to-destination row shared by trip cards and sheets.
class RidonsRouteEndpoints extends StatelessWidget {
  const RidonsRouteEndpoints({
    super.key,
    required this.pickup,
    required this.destination,
    this.pickupColor,
    this.destinationColor,
  });

  final String pickup;
  final String destination;
  final Color? pickupColor;
  final Color? destinationColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            pickup,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: pickupColor ?? RidonsColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: context.ridonsMuted,
          ),
        ),
        Expanded(
          child: Text(
            destination,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: destinationColor ?? context.ridonsInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

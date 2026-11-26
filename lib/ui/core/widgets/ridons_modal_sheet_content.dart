import 'package:flutter/material.dart';

/// Keeps content-driven modal sheets within the usable screen height and
/// scrollable on compact displays, with large text, or while the keyboard is
/// visible.
class RidonsModalSheetContent extends StatelessWidget {
  const RidonsModalSheetContent({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
  });

  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        (media.size.height - media.padding.top - media.viewInsets.bottom)
            .clamp(0.0, media.size.height)
            .toDouble();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: availableHeight * maxHeightFactor,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';

/// Red splash gradient plane from Splash-screens.pdf.
class RidonsSplashBackground extends StatelessWidget {
  const RidonsSplashBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: RidonsColors.splashGradient),
      child: SizedBox.expand(child: child),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum RidonsLogoKind { icon, wordmark }

class RidonsLogo extends StatelessWidget {
  const RidonsLogo({
    super.key,
    this.kind = RidonsLogoKind.icon,
    this.height = 72,
    this.color,
  });

  final RidonsLogoKind kind;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final asset = kind == RidonsLogoKind.icon
        ? 'assets/brand/logo_icon.svg'
        : 'assets/brand/logo_full.svg';

    return SvgPicture.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

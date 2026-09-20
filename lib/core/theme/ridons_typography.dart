import 'package:flutter/material.dart';

import 'ridons_colors.dart';

abstract final class RidonsSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const page = EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const pageHorizontal = EdgeInsets.symmetric(horizontal: md);
}

abstract final class RidonsRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const sheet = 24.0;
}

abstract final class RidonsTextStyles {
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: RidonsColors.text,
    height: 1.2,
  );

  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: RidonsColors.text,
    height: 1.25,
  );

  static const subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: RidonsColors.textSecondary,
    height: 1.4,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: RidonsColors.text,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: RidonsColors.text,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const price = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: RidonsColors.text,
    height: 1.1,
  );
}

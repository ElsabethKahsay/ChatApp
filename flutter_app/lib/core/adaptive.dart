import 'package:flutter/material.dart';

class Adaptive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static double messageMaxWidth(BuildContext context) =>
      isDesktop(context) ? 400 : 280;

  static EdgeInsets listPadding(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: isDesktop(context) ? 48 : 12,
        vertical: 8,
      );

  static double avatarRadius(BuildContext context) =>
      isTablet(context) ? 36 : 28;

  static double chatBubbleHorizontal(BuildContext context) =>
      isDesktop(context) ? 48 : 12;
}

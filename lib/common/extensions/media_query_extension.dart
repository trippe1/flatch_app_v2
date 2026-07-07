import 'package:flutter/material.dart';

extension ScreenSizeExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isSmall => screenWidth < 360;
  bool get isMedium => screenWidth >= 360 && screenWidth < 600;
  bool get isLarge => screenWidth >= 600;

  double scaled(double value) {
    return (screenWidth / 375.0) * value;
  }
}

import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';

class CustomTickMarkShape extends SliderTickMarkShape {
  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    bool? isEnabled,
  }) {
    return const Size(3, 30.0); // Width of 2 and Height of 15
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    Canvas canvas = context.canvas;
    final Paint paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill;

    // Draw a rectangle with width 2 and height 15
    Rect rect = Rect.fromCenter(center: center, width: 3.0, height: 25.0);
    canvas.drawRect(rect, paint);
  }
}

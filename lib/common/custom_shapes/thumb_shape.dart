import 'package:flutter/material.dart';

class CustomThumbShape extends SliderComponentShape {
  final double thumbRadius;

  CustomThumbShape({this.thumbRadius = 10.0}); // Default radius of 10

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint =
        Paint()
          ..color = sliderTheme.thumbColor!
          ..style = PaintingStyle.fill;

    // Draw a circle for the thumb
    canvas.drawCircle(center, thumbRadius, paint);
  }
}

class CustomThumbShapeWithText extends SliderComponentShape {
  final double thumbRadius;
  final String thumbText;

  CustomThumbShapeWithText({this.thumbRadius = 10.0, required this.thumbText});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint =
        Paint()
          ..color = sliderTheme.thumbColor!
          ..style = PaintingStyle.fill;

    // Draw a circle for the thumb
    canvas.drawCircle(center, thumbRadius, paint);

    // Create a TextPainter to paint the text
    final TextSpan textSpan = TextSpan(
      text: thumbText,
      style: TextStyle(
        color: Colors.white, // Text color
        fontSize: thumbRadius * .8, // Adjust the font size as needed
      ),
    );

    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
    );

    textPainter.layout();

    // Calculate the offset to center the text
    final Offset textOffset =
        center - Offset(textPainter.width / 2, textPainter.height / 2);

    // Paint the text
    textPainter.paint(canvas, textOffset);
  }
}

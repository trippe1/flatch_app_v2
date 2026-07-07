// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioWavePainter extends CustomPainter {
  final double level;

  AudioWavePainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    final barWidth = 4.0;
    final gap = 3.0;
    final bars = (size.width / (barWidth + gap)).floor();
    final center = size.height / 2;

    for (var i = 0; i < bars; i++) {
      // Create more dynamic wave pattern
      final normalizedIndex = i / bars;
      final waveHeight = math.sin(normalizedIndex * math.pi * 4) * 0.5 + 0.5;
      final height = (center * level * waveHeight * 0.8) + (center * 0.1);

      final left = i * (barWidth + gap);

      // Gradient effect based on height
      final intensity = height / center;
      paint.color =
          Color.lerp(Colors.blue.withOpacity(0.3), Colors.blue, intensity)!;

      canvas.drawLine(
        Offset(left, center - height),
        Offset(left, center + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

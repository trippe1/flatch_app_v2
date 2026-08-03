import 'package:flutter/material.dart';

/// Static waveform display — draws normalized amplitudes (0..1) as centered
/// vertical bars. Used above the trim/seek bar. Optionally highlights the
/// portion of the clip up to [progress] (0..1) in [activeColor].
class WaveformView extends StatelessWidget {
  final List<double> amplitudes;
  final double height;
  final Color color;
  final Color activeColor;
  final double progress;

  const WaveformView({
    super.key,
    required this.amplitudes,
    this.height = 48,
    this.color = const Color(0xFFBDBDBD),
    this.activeColor = const Color(0xFF00B140),
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(amplitudes, color, activeColor, progress),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> amps;
  final Color color;
  final Color activeColor;
  final double progress;

  _WavePainter(this.amps, this.color, this.activeColor, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (amps.isEmpty) return;
    final n = amps.length;
    const gap = 1.5;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(0.5, 8.0);
    final mid = size.height / 2;
    final progressX = size.width * progress.clamp(0.0, 1.0);

    final base = Paint()..color = color;
    final active = Paint()..color = activeColor;

    double x = 0;
    for (int i = 0; i < n; i++) {
      final h = (amps[i] * (size.height - 2)).clamp(2.0, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, mid - h / 2, barW, h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, x <= progressX ? active : base);
      x += barW + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.amps != amps || old.progress != progress || old.color != color;
}

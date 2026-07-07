import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class InputChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const InputChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w500,
      ),
      selectedColor: AppColors.primary,
    );
  }
}

class ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          color: color,
          iconSize: 36,
          onPressed: onPressed,
        ),
        const Gap(4),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class AudioWavePainter extends CustomPainter {
  final double level;

  AudioWavePainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final waveWidth = size.width / 20;
    final amplitude = size.height * 0.4 * level;

    for (var i = 0; i < 20; i++) {
      final x = i * waveWidth + waveWidth / 2;
      final height = amplitude * (0.5 + 0.5 * (i % 3) / 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, centerY),
            width: waveWidth * 0.8,
            height: height,
          ),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';

/// FLATCH wordmark — bold caps, wide tracking (brand brief §Visual identity).
class FlatchWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;
  const FlatchWordmark({super.key, this.fontSize = 40, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      'FLATCH',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: fontSize * 0.14, // wide tracking
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// The primary brand statement: "Flatulations are NOT funny."
/// Always a complete sentence with the period. Only "NOT" is emphasized
/// (brand green); nothing else. Never truncated, remixed, or exclaimed.
class FlatchSlogan extends StatelessWidget {
  final double fontSize;
  final Color? color;
  final TextAlign align;
  const FlatchSlogan({
    super.key,
    this.fontSize = 16,
    this.color,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
    return RichText(
      textAlign: align,
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Flatulations are '),
          TextSpan(
            text: 'NOT',
            style: base.copyWith(
              color: AppColors.signalGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          const TextSpan(text: ' funny.'),
        ],
      ),
    );
  }
}

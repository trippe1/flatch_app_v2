// ignore_for_file: deprecated_member_use

import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class KCircularPercentIndicator extends StatelessWidget {
  final double? radius;
  final double? lineWidth;
  final double? percent;
  final Widget? center;
  const KCircularPercentIndicator({
    super.key,
    this.radius,
    this.lineWidth,
    this.percent,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: radius ?? 15,
      lineWidth: lineWidth ?? 2,
      backgroundColor: Colors.black.withOpacity(.1),
      progressColor: AppColors.primary,
      circularStrokeCap: CircularStrokeCap.round,
      animation: true,
      percent: percent ?? 0.9,
      center: center,
    );
  }
}

class KLinearProgress extends StatelessWidget {
  const KLinearProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: LinearProgressIndicator(
        borderRadius: BorderRadius.circular(50),
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        minHeight: 3,
      ),
    );
  }
}

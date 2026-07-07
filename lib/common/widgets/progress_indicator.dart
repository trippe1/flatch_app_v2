import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';

class KProgressIndicator extends StatelessWidget {
  final Color? color;
  const KProgressIndicator({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      color: color ?? AppColors.primary,
      strokeCap: StrokeCap.round,
      strokeWidth: 2,
    );
  }
}

class KProgressLoader extends StatelessWidget {
  final Color? color;
  const KProgressLoader({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 200.0),
      child: Image.asset(
        'assets/animations/loader1.gif',
        height: 150,
        width: 150,
      ),
    );
  }
}

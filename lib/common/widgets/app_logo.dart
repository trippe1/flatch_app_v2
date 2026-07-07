import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? logoSize;
  final double? textSize;
  final MainAxisAlignment? alignment;
  final Color? colors;
  const AppLogo({
    super.key,
    this.logoSize,
    this.textSize,
    this.alignment,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        "assets/images/flatch_logo.png",
        height: logoSize ?? 40,
        width: logoSize ?? 40,
      ),
    );
  }
}

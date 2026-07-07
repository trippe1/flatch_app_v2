import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SocialButtons extends StatelessWidget {
  final VoidCallback? onFacebook;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  const SocialButtons({
    super.key,
    this.onFacebook,
    this.onGoogle,
    this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[800] : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;

    double height = MediaQuery.of(context).size.height;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        2,
        (i) => Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 20),
          child: OutlinedButton(
            onPressed: i == 0 ? onGoogle : onApple,
            style: OutlinedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              side: BorderSide(color: foregroundColor), 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: SvgPicture.asset(
              i == 0 ? "assets/svgs/google.svg" : "assets/svgs/apple.svg",
              height: height < 700 ? 14 : 20,
              width: 20,
              colorFilter: ColorFilter.mode(foregroundColor, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

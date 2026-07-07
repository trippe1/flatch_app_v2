import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';

class KTextButton extends StatelessWidget {
  final AlignmentGeometry? align;
  final String? text;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Size? size;
  final double? borderRadius;
  final BorderSide? side;
  final double? fontSize;
  const KTextButton({
    super.key,
    this.align,
    this.text,
    this.onPressed,
    this.foregroundColor,
    this.backgroundColor,
    this.size,
    this.borderRadius,
    this.side,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align ?? Alignment.centerRight,
      child: TextButton(
        onPressed: onPressed,
        style: const ButtonStyle().copyWith(
          backgroundColor: WidgetStatePropertyAll(backgroundColor),
          foregroundColor: WidgetStatePropertyAll(foregroundColor),
          minimumSize: WidgetStatePropertyAll(size ?? const Size(110, 30)),
          textStyle: WidgetStatePropertyAll(
            style(size: fontSize ?? 14, weight: FontWeight.bold),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? 6),
            ),
          ),
          side: WidgetStatePropertyAll(
            side ?? BorderSide(color: backgroundColor ?? AppColors.primary),
          ),
        ),
        child: Text(text ?? "Expand"),
      ),
    );
  }
}

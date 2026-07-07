// ignore_for_file: deprecated_member_use

import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';

class TextWidget extends StatelessWidget {
  final String text;
  final FontWeight? weight;
  final Color? color;
  final TextAlign? textAlign;
  final double? size;
  final double? padding;
  final TextDecoration? textDecoration;
  final int? maxLines;
  const TextWidget({
    super.key,
    required this.text,
    this.weight,
    this.color,
    this.textAlign,
    this.size,
    this.padding,
    this.textDecoration,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding ?? 0),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: "Lato",
          fontSize: size,
          fontWeight: weight,
          color: color,
          decoration: textDecoration,
        ),
        textAlign: textAlign,
        maxLines: maxLines,
      ),
    );
  }
}

TextStyle style({
  Color? color,
  FontWeight? weight,
  double? size,
  double? letterSpacing,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: "Lato",
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
}

class TextRichWidget extends StatelessWidget {
  final List<String> texts;
  final Color? color;
  final List<Color>? colors;
  final List<double>? fontSize;
  final bool? opacity;
  final FontWeight? weight;
  final List<FontWeight>? weights;
  final TextAlign? textAlign;
  final List<TextDecoration>? decoration;
  const TextRichWidget({
    super.key,
    required this.texts,
    this.color,
    this.fontSize,
    this.opacity,
    this.weight,
    this.colors,
    this.weights,
    this.textAlign,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: List.generate(
          texts.length,
          (index) => TextSpan(
            style: style(
              color:
                  colors == null
                      ? (color ??
                          (index == 0
                              ? AppColors.primary
                              : (opacity ?? false
                                  ? Colors.black.withOpacity(.5)
                                  : Colors.black)))
                      : colors![index],
              weight:
                  weights == null
                      ? (weight == null
                          ? (index == 0 ? FontWeight.bold : null)
                          : index == 0
                          ? weight
                          : null)
                      : weights![index],
              size: fontSize?[index],
              decoration: decoration != null ? decoration![index] : null,
            ),
            text: texts[index],
          ),
        ),
      ),
      textAlign: textAlign,
    );
  }
}

import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'text.dart';

class TextFormFieldWithText extends StatelessWidget {
  final String? heading;
  final String? hint;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final Widget? suffix;
  final bool? obsecure;
  final TextInputType? keyboardType;
  final int? maxLines;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? contentPadding;
  final int? maxLength;
  final bool? readOnly;
  final FocusNode? focusNode;
  final Color? headingColor;
  final int? minLines;
  final TextInputAction? textInputAction;
  final InputBorder? enabledBorder;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;
  final void Function(PointerDownEvent)? onTapOutside;
  final bool? showButtonAlso;
  final VoidCallback? onTapInfoButton;
  final Widget? prefixIcon;
  final String? textError;

  const TextFormFieldWithText({
    super.key,
    this.heading,
    this.hint,
    this.validator,
    this.controller,
    this.suffix,
    this.obsecure,
    this.keyboardType,
    this.maxLines,
    this.textStyle,
    this.contentPadding,
    this.maxLength,
    this.readOnly,
    this.focusNode,
    this.headingColor,
    this.minLines,
    this.textInputAction,
    this.enabledBorder,
    this.onChanged,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.onTap,
    this.onTapOutside,
    this.showButtonAlso,
    this.onTapInfoButton,
    this.prefixIcon,
    this.textError,
  });

  @override
  Widget build(BuildContext context) {
    double screenHeight = context.screenHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (showButtonAlso ?? false)
            ? Row(
              children: [
                Expanded(
                  child: TextWidget(
                    text: heading ?? "Full Name",
                    size: screenHeight < 700 ? 14 : 16,
                    weight: FontWeight.normal,
                    color: headingColor,
                  ),
                ),
                IconButton(
                  onPressed: onTapInfoButton,
                  icon: const Icon(CupertinoIcons.info_circle_fill),
                  style: const ButtonStyle().copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(30, 30)),
                    backgroundColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    foregroundColor: const WidgetStatePropertyAll(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            )
            : TextWidget(
              text: heading ?? "Full Name",
              size: screenHeight < 700 ? 14 : 16,
              weight: FontWeight.normal,
              color: headingColor,
            ),
        const Gap(5),
        TextFormField(
          onTap: onTap,
          inputFormatters: inputFormatters,
          focusNode: focusNode,
          readOnly: readOnly ?? false,
          maxLength: maxLength,
          minLines: minLines ?? (maxLines == null ? null : 1),
          maxLines: maxLines ?? 1,
          obscureText: obsecure ?? false,
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted:
              onFieldSubmitted ??
              (value) {
                FocusScope.of(context).unfocus();
              },
          onTapOutside:
              onTapOutside ??
              (event) {
                FocusScope.of(context).unfocus();
              },
          decoration: InputDecoration(
            errorMaxLines: 3,
            errorText: textError,
            prefixIcon:
                prefixIcon ??
                const Icon(CupertinoIcons.person, color: AppColors.primary),
            counterStyle: style(size: 14),
            contentPadding: contentPadding,
            hintText: hint ?? "Enter the full name",
            hintStyle:
                textStyle ??
                style(size: screenHeight < 700 ? 12 : 14, color: Colors.grey),
            suffixIcon: suffix,
            enabledBorder: enabledBorder,
          ),
          style: textStyle ?? style(size: 14),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class NonBorderTextFieldWithText extends StatelessWidget {
  final String? heading;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  const NonBorderTextFieldWithText({
    super.key,
    this.heading,
    this.controller,
    this.validator,
    this.onFieldSubmitted,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextWidget(text: heading ?? "Be: ", weight: FontWeight.bold, size: 15),
        const Gap(5),
        Expanded(
          child: TextFormField(
            onTapOutside: (event) {
              FocusScope.of(context).unfocus();
            },
            inputFormatters: inputFormatters,
            onFieldSubmitted: onFieldSubmitted,
            controller: controller,
            validator: validator,
            textInputAction: TextInputAction.done,
            style: style(),
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              filled: false,
              contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              border: UnderlineInputBorder(),
              errorBorder: UnderlineInputBorder(),
              enabledBorder: UnderlineInputBorder(),
              disabledBorder: UnderlineInputBorder(),
              focusedBorder: UnderlineInputBorder(),
              focusedErrorBorder: UnderlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class CustomInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any non-digit characters from the input
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Insert dashes at the correct positions
    if (newText.length >= 5 && newText.length <= 8) {
      newText = '${newText.substring(0, 4)}-${newText.substring(4)}';
    } else if (newText.length > 8) {
      newText =
          '${newText.substring(0, 4)}-${newText.substring(4, 8)}-${newText.substring(8)}';
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

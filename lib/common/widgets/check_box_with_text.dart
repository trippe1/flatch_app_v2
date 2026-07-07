// ignore_for_file: deprecated_member_use

import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/widgets/checkbox.dart';
import 'package:flatch/common/widgets/rounded_check_box.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class CheckBoxWithText extends StatelessWidget {
  final bool? isChecked;
  final String? text;
  final Widget? widget;
  final VoidCallback? onTap;
  final VoidCallback? onTextTap;
  final bool? useRounded;

  const CheckBoxWithText({
    super.key,
    this.text,
    this.isChecked,
    this.widget,
    this.onTap,
    this.onTextTap,
    this.useRounded,
  });

  @override
  Widget build(BuildContext context) {
    double screenHeight = context.screenHeight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap, // Toggle checkbox
          child:
              (useRounded ?? false)
                  ? RoundCheckBox(isChecked: isChecked ?? false)
                  : CCheckBox(isChecked: isChecked),
        ),
        const Gap(10),
        widget ??
            Expanded(
              child: GestureDetector(
                onTap: onTextTap, // Open URL when clicked
                child: TextWidget(
                  text: text ?? "",
                  size: screenHeight < 700 ? 14 : 16,
                  weight: FontWeight.w500,
                  color: Colors.black.withOpacity(.6),
                ),
              ),
            ),
      ],
    );
  }
}

// ignore_for_file: deprecated_member_use

import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';

class RoundCheckBox extends StatelessWidget {
  final bool isChecked;
  final double? size;
  final double? iconSize;
  final Color? fillColor;
  final Color? filledIconColor;
  final Color? borderColor;
  const RoundCheckBox({
    super.key,
    required this.isChecked,
    this.borderColor,
    this.iconSize,
    this.size,
    this.fillColor,
    this.filledIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      height: size ?? 22,
      width: size ?? 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
              isChecked
                  ? AppColors.backgroundWhite
                  : (borderColor ?? AppColors.goalsAppbar),
          width: isChecked ? 2 : 1,
        ),
        color:
            fillColor ?? (isChecked ? AppColors.primary : Colors.transparent),
      ),
      child:
      // child: isChecked ?
      // Container(
      //   margin: EdgeInsets.all(2),
      //   padding: EdgeInsets.all(3),
      //   decoration: BoxDecoration(
      //     border: Border.all(color: Colors.white),
      //     shape: BoxShape.circle
      //   ),
      //   child: Icon(Icons.check,
      //       size: iconSize ?? 14,
      //       color: filledIconColor ??
      //           (isChecked ? Colors.white : Colors.black.withOpacity(.2)))
      // ) :
      Icon(
        Icons.check,
        size: iconSize ?? 14,
        color:
            filledIconColor ??
            (isChecked ? Colors.white : Colors.black.withOpacity(.2)),
      ),
    );
  }
}

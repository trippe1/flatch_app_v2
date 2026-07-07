// ignore_for_file: deprecated_member_use

import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/custom_shapes/custom_ticker.dart';
import 'package:flatch/common/custom_shapes/thumb_shape.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';

class AppStyles {
  static ThemeData light = ThemeData.light().copyWith(
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.background,
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: Colors.white,
      elevation: 8,
    ),

    colorScheme: const ColorScheme.light().copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: const ButtonStyle().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(50, 50)),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        alignment: Alignment.center,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
    ),
    radioTheme: const RadioThemeData().copyWith(
      fillColor: const WidgetStatePropertyAll(AppColors.primary),
    ),
    tabBarTheme: const TabBarThemeData().copyWith(
      dividerColor: Colors.black.withOpacity(.2),
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: Colors.black.withOpacity(.5),
      labelStyle: style(weight: FontWeight.bold, size: 18),
      unselectedLabelStyle: style(weight: FontWeight.bold, size: 18),
    ),
    textButtonTheme: TextButtonThemeData(
      style: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
        minimumSize: const WidgetStatePropertyAll(Size(300, 45)),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.primary, width: 1),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        textStyle: WidgetStatePropertyAll(
          style(size: 18, weight: FontWeight.bold),
        ),
      ),
    ),
    sliderTheme: const SliderThemeData().copyWith(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.background,
      tickMarkShape: CustomTickMarkShape(),
      thumbShape: CustomThumbShape(thumbRadius: 20),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(AppColors.background),
      ),
    ),
    snackBarTheme: const SnackBarThemeData().copyWith(
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      dismissDirection: DismissDirection.endToStart,
      contentTextStyle: style(size: 14, color: Colors.white),
      insetPadding: const EdgeInsets.only(left: 50, right: 50, bottom: 50),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData().copyWith(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    popupMenuTheme: const PopupMenuThemeData().copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      labelTextStyle: WidgetStatePropertyAll(
        style(size: 14, color: Colors.black),
      ),
      enableFeedback: true,
      shadowColor: AppColors.background,
      surfaceTintColor: Colors.white,
      position: PopupMenuPosition.over,
      textStyle: style(size: 14),
    ),
    datePickerTheme: DatePickerThemeData().copyWith(
      cancelButtonStyle: ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        foregroundColor: MaterialStateProperty.all(AppColors.primary),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.primary),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(120, 45)),
        textStyle: WidgetStatePropertyAll(style(size: 14)),
      ),
      confirmButtonStyle: ButtonStyle().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(120, 45)),
        textStyle: WidgetStatePropertyAll(style(size: 14)),
      ),
    ),
    timePickerTheme: const TimePickerThemeData().copyWith(
      hourMinuteColor: AppColors.primary,
      hourMinuteTextColor: AppColors.backgroundWhite,
      dayPeriodColor: AppColors.primary,
      cancelButtonStyle: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        foregroundColor: MaterialStateProperty.all(AppColors.primary),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.primary),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(120, 45)),
        textStyle: WidgetStatePropertyAll(style(size: 14)),
      ),
      confirmButtonStyle: const ButtonStyle().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(120, 45)),
        textStyle: WidgetStatePropertyAll(style(size: 14)),
      ),
      dialTextStyle: style(size: 16),
      helpTextStyle: style(size: 16),
      dayPeriodTextStyle: style(size: 16),
      hourMinuteTextStyle: style(size: 22, weight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardColor: Colors.white,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      surfaceTintColor: AppColors.primary,
      shadowColor: AppColors.background,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(
          style(size: 16, color: AppColors.primary, weight: FontWeight.w700),
        ),
        iconSize: const WidgetStatePropertyAll(18),
        minimumSize: const WidgetStatePropertyAll(Size(60, 40)),
        foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
        side: const WidgetStatePropertyAll(BorderSide.none),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.0,
    ),
    bottomSheetTheme: const BottomSheetThemeData().copyWith(
      constraints: const BoxConstraints(minHeight: 400),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      modalElevation: 20,
      surfaceTintColor: AppColors.background,
      backgroundColor: AppColors.background,
    ),
    dialogTheme: const DialogThemeData().copyWith(
      titleTextStyle: style(size: 16, color: Colors.black),
      elevation: 20,
      surfaceTintColor: AppColors.background,
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.background,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.only(
        top: 12,
        bottom: 12,
        left: 16,
        right: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withOpacity(.09)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withOpacity(.09)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      hintStyle: style(
        size: 14,
        weight: FontWeight.w500,
        color: Colors.black.withOpacity(.5),
      ),
      helperStyle: style(
        size: 14,
        weight: FontWeight.w500,
        color: Colors.black.withOpacity(.5),
      ),
      filled: true,
      fillColor: Colors.white,
      labelStyle: style(
        size: 14,
        weight: FontWeight.w500,
        color: Colors.black.withOpacity(.5),
      ),
      errorStyle: style(size: 14, color: Colors.red, weight: FontWeight.w500),
    ),
  );
  static ThemeData dark = ThemeData.dark().copyWith(
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: Colors.black,
      elevation: 8,
    ),
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: const ButtonStyle().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(50, 50)),
        backgroundColor: const WidgetStatePropertyAll(Colors.black),
        alignment: Alignment.center,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: Colors.white.withOpacity(.05), width: 2),
        ),
      ),
    ),
    radioTheme: const RadioThemeData().copyWith(
      fillColor: const WidgetStatePropertyAll(AppColors.primary),
    ),
    tabBarTheme: const TabBarThemeData().copyWith(
      dividerColor: Colors.white.withOpacity(.2),
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: Colors.white.withOpacity(.5),
      labelStyle: style(weight: FontWeight.bold, size: 18),
      unselectedLabelStyle: style(weight: FontWeight.bold, size: 18),
    ),
    textButtonTheme: TextButtonThemeData(
      style: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
        minimumSize: const WidgetStatePropertyAll(Size(300, 45)),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.primary, width: 1),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        textStyle: WidgetStatePropertyAll(
          style(size: 18, weight: FontWeight.bold),
        ),
      ),
    ),
    sliderTheme: const SliderThemeData().copyWith(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.darkBackground,
      tickMarkShape: CustomTickMarkShape(),
      thumbShape: CustomThumbShape(thumbRadius: 20),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(AppColors.darkBackground),
      ),
    ),
    snackBarTheme: const SnackBarThemeData().copyWith(
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      dismissDirection: DismissDirection.endToStart,
      contentTextStyle: style(size: 14, color: Colors.white),
      insetPadding: const EdgeInsets.only(left: 50, right: 50, bottom: 50),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData().copyWith(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    popupMenuTheme: const PopupMenuThemeData().copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      labelTextStyle: WidgetStatePropertyAll(
        style(size: 14, color: Colors.white),
      ),
      enableFeedback: true,
      shadowColor: AppColors.darkBackground,
      surfaceTintColor: Colors.black,
      position: PopupMenuPosition.over,
      textStyle: style(size: 14),
    ),
    timePickerTheme: const TimePickerThemeData().copyWith(
      hourMinuteColor: AppColors.primary,
      hourMinuteTextColor: AppColors.backgroundWhite,
      dayPeriodColor: AppColors.primary,
      cancelButtonStyle: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.black),
        foregroundColor: MaterialStateProperty.all(AppColors.primary),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.primary),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(120, 45)),
        textStyle: WidgetStatePropertyAll(style(size: 14)),
      ),
      confirmButtonStyle: const ButtonStyle().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(120, 45)),
        textStyle: WidgetStatePropertyAll(style(size: 14)),
      ),
      dialTextStyle: style(size: 16),
      helpTextStyle: style(size: 16),
      dayPeriodTextStyle: style(size: 16),
      hourMinuteTextStyle: style(size: 22, weight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardColor: AppColors.darkBackground,
    cardTheme: CardThemeData(
      color: AppColors.darkBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      surfaceTintColor: AppColors.primary,
      shadowColor: AppColors.darkBackground,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: const ButtonStyle().copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(
          style(size: 16, color: AppColors.primary, weight: FontWeight.w700),
        ),
        iconSize: const WidgetStatePropertyAll(18),
        minimumSize: const WidgetStatePropertyAll(Size(60, 40)),
        foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
        side: const WidgetStatePropertyAll(BorderSide.none),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      scrolledUnderElevation: 0.0,
    ),
    bottomSheetTheme: const BottomSheetThemeData().copyWith(
      constraints: const BoxConstraints(minHeight: 400),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      modalElevation: 20,
      surfaceTintColor: AppColors.darkBackground,
      backgroundColor: AppColors.darkBackground,
    ),
    dialogTheme: const DialogThemeData().copyWith(
      titleTextStyle: style(size: 16, color: Colors.white),
      elevation: 20,
      surfaceTintColor: AppColors.darkBackground,
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.darkBackground,
    ),
  );
}

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(
    0xFF4ADE1A,
  ); // Bright neon green (text color)
  static const Color lightPrimary = Color.fromARGB(255, 171, 233, 149);

  static const Color secondary = Color(
    0xFF1E1E1E,
  ); // Deep charcoal black (background)
  static const Color upvote = primary;
  static const Color downvote = Colors.red;
  static const Color chipBackground = Color(0xFFEBFDF0);

  static const Color primary1 = Color(0xFFD81B60); // Deeper pink

  static const Color darkBackground = Color(0xFF121212);

  static const Color background = Colors.white; // Soft, warm tone

  static const Color backgroundWhite = Colors.white;
  static Color goalsAppbar = primary;
  static Color habitAppbar = Colors.lightGreen[600]!.withOpacity(0.9);
  static Color habitAppbar1 = Colors.lightGreen[600]!;
  static Color morning = const Color(0xFFFFD700);

  static Color journalsAppbar = Colors.purple[400]!.withOpacity(0.8);
  static Color journalsAppbar1 = Colors.purple[400]!;
  static Color actionsAppbar = Colors.orange[600]!.withOpacity(0.9);
  static Color analyticsAppbar = Colors.pink[600]!.withOpacity(0.9);
  static Color settingsAppbar = Colors.indigo[500]!.withOpacity(0.8);
  static Color howItWorksAppbar = Colors.cyan[600]!.withOpacity(0.9);
}

class AppBorderRadius {
  static const double borderRadius = 16.0;
}

class AppShadow {
  static const double appShadow = 0.4;
  static const double appGoalShadow = 0.4;
  static const double appHabitShadow = 0.4;
  static const double appJournalShadow = 0.4;
  static const double appAnalyticsShadow = 0.4;
  static const double appSettingsShadow = 0.4;
  static const double appToDosShadow = 0.2;
}

class AppFontSizes {
  static const double title = 28.0;
  static const double title1 = 24.0;
  static const double subtitle = 25.0;
  static const double subtitle1 = 19.0;
  static const double body = 16.0;
  static const double small = 12.0;
}

class AppConstants {
  static const String latoBlack = 'Lato';
  static const String latoBold = 'latoBold';
  static const String latoLight = 'latoLight';
  static const String latoRegular = "latoRegular";
}

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppColors {
  // ===== Flatch brand palette (see brand brief) =====
  // Signal Green — PANTONE 354 C. The button, the accent, CTAs, the "NOT".
  // Used sparingly against neutrals so it reads as an instrument light.
  static const Color signalGreen = Color(0xFF00B140);
  static const Color pressedGreen = Color(0xFF008F34); // pressed/hover
  // Signal Blue — the device/wireless accent, used ONLY for the connection
  // tab so "connected hardware" reads differently from "community". Chosen as
  // a sibling to Signal Green rather than an arbitrary blue: identical 100%
  // saturation, nearest lightness (42% vs the green's 35%), so it carries the
  // same instrument-light quality. Clears 3:1 against both nearBlack (4.4:1)
  // and labWhite (3.8:1).
  static const Color signalBlue = Color(0xFF007DD6);
  static const Color charcoal = Color(0xFF1A1A1A); // primary dark surface/type
  static const Color nearBlack = Color(0xFF121212); // deepest dark surface
  static const Color labWhite = Color(0xFFF4F2EE); // light surfaces
  static const Color warmGray = Color(0xFF8A857C); // supporting gray (light)
  static const Color darkGray = Color(0xFF8C8C8C); // supporting gray (dark)
  static Color disabledGreen = signalGreen.withOpacity(0.30);

  static const Color primary = signalGreen;
  static const Color lightPrimary = Color(0xFFB7E4C7); // tinted signal green

  static const Color secondary = charcoal;
  static const Color upvote = primary;
  static const Color downvote = Colors.red;
  static const Color chipBackground = Color(0xFFE6F6EC); // signal-green tint

  static const Color primary1 = charcoal;

  static const Color darkBackground = nearBlack;

  static const Color background = labWhite;

  static const Color backgroundWhite = labWhite;
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

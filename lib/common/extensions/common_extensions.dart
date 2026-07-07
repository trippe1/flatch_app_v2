import 'package:flutter/material.dart';

extension TimeToDateTime on TimeOfDay {
  DateTime toDateTime() {
    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}

extension TimeToDateTimeInt on TimeOfDay {
  int toDateTimeInt() {
    return DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    ).millisecondsSinceEpoch;
  }
}

extension ConvertIntTimeToDateTime on int {
  DateTime toDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(this);
  }
}

extension ConvetDateToISOString on String {
  DateTime fromISOString() {
    return DateTime.parse(this);
  }
}

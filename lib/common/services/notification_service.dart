import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flatch/common/services/app_logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'dart:io' show Platform;
import 'package:timezone/timezone.dart' as tz;

class NotificationServices {
  NotificationServices._();
  static final NotificationServices instance = NotificationServices._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  Future<int> setupGoalUploadNotification({String? body}) async {
    final int id = (DateTime.now().millisecondsSinceEpoch - 20000) % (1 << 31);
    if (Platform.isAndroid) {
      NotificationDetails notificationDetails = const NotificationDetails(
        android: AndroidNotificationDetails(
          "channelId",
          "channelName",
          category: AndroidNotificationCategory.message,
          enableVibration: true,
          importance: Importance.max,
          priority: Priority.high,
        ),
      );
      await plugin.show(
        id,
        "Abundant Visas ",
        body ?? "Your goal is being uploading",
        notificationDetails,
      );
      return id;
    } else {
      NotificationDetails notificationDetails = const NotificationDetails(
        iOS: DarwinNotificationDetails(),
      );
      await plugin.show(
        id,
        "Abundant Visas ",
        body ?? "Your goal is being uploading.",
        notificationDetails,
      );
      return id;
    }
  }

  Future<void> cancelNotification(int id) async {
    await plugin.cancel(id);
  }

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('logo');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestAlertPermission: true,
        );
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          linux: initializationSettingsLinux,
        );
    await plugin.initialize(initializationSettings);
  }

  Future<void> setupFutureNotification({
    final String? body,
    required DateTime time,
    required final String sound,
  }) async {
    try {
      // Logger logger = Logger();
      // logger.d('Incoming sound parameter: $sound');
      final bool isTaskSound = sound.contains("empty");
      final bool toing = sound.trim().toLowerCase() == "toing";
      final bool tingTongTing = sound.trim().toLowerCase() == "ting tong ting";
      final bool tingTong = sound.trim().toLowerCase() == "ting tong";
      final bool ding = sound.trim().toLowerCase() == "ding";
      final String androidAudio =
          toing
              ? "toing"
              : tingTong
              ? "ting_tong"
              : tingTongTing
              ? "ting_tong_ting"
              : ding
              ? "ding"
              : "no_sound";
      final String iosAudio =
          toing
              ? "toing.caf"
              : tingTong
              ? "ting_tong.caf"
              : tingTongTing
              ? "ting_tong_ting.caf"
              : ding
              ? "ding.caf"
              : "toing.caf";
      final int id =
          (DateTime.now().millisecondsSinceEpoch - 20000) % (1 << 31);
      NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          "notificationId",
          "notificationName",
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(
            isTaskSound ? "toing" : androidAudio,
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentSound: isTaskSound ? null : true,
          sound: isTaskSound ? "toing" : iosAudio,
        ),
      );
      if (time.isAfter(DateTime.now())) {
        await plugin.zonedSchedule(
          id,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          "Abundant Visas ",
          body ?? "Time up for",
          tz.TZDateTime.from(time, tz.local),
          details,
        );
      }
    } catch (e) {
      Logger logger = Logger();
      logger.e("Error - Setting Notification : $e");
    }
  }

  Future<void> setupFutureNotificationforHabit({
    final String? body,
    required DateTime time,
    required final String sound,
  }) async {
    try {
      // Logger logger = Logger();
      // logger.d('Incoming sound parameter: $sound');
      final bool isTaskSound = sound.contains("empty");
      final bool toing = sound.trim().toLowerCase() == "toing";
      final bool tingTongTing = sound.trim().toLowerCase() == "ting tong ting";
      final bool tingTong = sound.trim().toLowerCase() == "ting tong";
      final bool ding = sound.trim().toLowerCase() == "ding";
      final String androidAudio =
          toing
              ? "toing"
              : tingTong
              ? "ting_tong"
              : tingTongTing
              ? "ting_tong_ting"
              : ding
              ? "ding"
              : "no_sound";
      final String iosAudio =
          toing
              ? "toing.caf"
              : tingTong
              ? "ting_tong.caf"
              : tingTongTing
              ? "ting_tong_ting.caf"
              : ding
              ? "ding.caf"
              : "no_sound.caf";
      final int id =
          (DateTime.now().millisecondsSinceEpoch - 20000) % (1 << 31);
      NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          "habit_notifications",
          "Habit Reminders",
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(
            isTaskSound ? "toing" : androidAudio,
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentSound: isTaskSound ? null : true,
          sound: isTaskSound ? null : iosAudio,
        ),
      );
      if (time.isAfter(DateTime.now())) {
        await plugin.zonedSchedule(
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          id,
          "Abundant Visas ",
          body ?? "Time up for",
          tz.TZDateTime.from(time, tz.local),
          details,
        );
      }
    } catch (e) {
      Logger logger = Logger();
      logger.e("Error - Setting Notification : $e");
    }
  }

  // Future<void> setupHabitsNotifications(List<UserHabit> habits) async {
  //   await plugin.cancelAll();
  //   List<UserHabit> allowedNotifications =
  //       habits.where((element) => element.allowNotifications).toList();
  //   if (allowedNotifications.isNotEmpty) {
  //     for (UserHabit habit in allowedNotifications) {
  //       List<Map<String, dynamic>>? allTimes = habit.userNotificationTimes;
  //       if (allTimes != null) {
  //         List<DateTime> times = allTimes.map((e) {
  //           return DateTime.fromMillisecondsSinceEpoch(e["time"]);
  //         }).toList();
  //         if (habit.isSpecific) {
  //           List<DateTime> specificDates = habit.specificDates.map((e) {
  //             DateTime date = DateTime.fromMillisecondsSinceEpoch(e);
  //             return DateTime(date.year, date.month, date.day);
  //           }).toList();
  //           List<DateTime> allDates = getAllDateInMoreThan1Case(
  //               specificDates: specificDates, times: times);
  //           for (DateTime notiTime in allDates) {
  //             await setupFutureNotification(
  //               time: notiTime,
  //               body: habit.objective.toLowerCase().contains("make")
  //                   ? "Time to make a Habit : ${habit.title}"
  //                   : "Time to break a Habit : ${habit.title}",
  //               sound: habit.sound,
  //             );
  //           }
  //         } else {
  //           List<DateTime> dates = getDateRange(habit.startDate, habit.endDate);
  //           List<DateTime> allTimes =
  //               getAllDateInMoreThan1Case(specificDates: dates, times: times);
  //           for (DateTime date in allTimes) {
  //             await setupFutureNotification(
  //               time: date,
  //               body: habit.objective.toLowerCase().contains("make")
  //                   ? "Time to make a Habit : ${habit.title}"
  //                   : "Time to break a Habit : ${habit.title}",
  //               sound: habit.sound,
  //             );
  //           }
  //         }
  //       } else {
  //         final DateTime time =
  //             DateTime.fromMillisecondsSinceEpoch(habit.notificationTime);
  //         if (habit.isSpecific) {
  //           List<DateTime> specificDates = habit.specificDates.map((e) {
  //             DateTime date = DateTime.fromMillisecondsSinceEpoch(e);
  //             return DateTime(date.year, date.month, date.day, time.hour,
  //                 time.minute, time.second);
  //           }).toList();
  //           for (DateTime notiTime in specificDates) {
  //             await setupFutureNotification(
  //               time: notiTime,
  //               body: habit.objective.toLowerCase().contains("make")
  //                   ? "Time to make a Habit : ${habit.title}"
  //                   : "Time to break a Habit : ${habit.title}",
  //               sound: habit.sound,
  //             );
  //           }
  //         } else {
  //           List<DateTime> dates = getDateRange(habit.startDate, habit.endDate);
  //           for (DateTime d in dates) {
  //             DateTime notiTime = DateTime(
  //                 d.year, d.month, d.day, time.hour, time.minute, time.second);
  //             await setupFutureNotification(
  //                 time: notiTime,
  //                 body: habit.objective.toLowerCase().contains("make")
  //                     ? "Time to make a Habit : ${habit.title}"
  //                     : "Time to break a Habit : ${habit.title}",
  //                 sound: habit.sound);
  //           }
  //         }
  //       }
  //     }
  //   }
  // }

  List<DateTime> getDateRange(int s, int e) {
    List<DateTime> dateList = [];
    DateTime currentDate = DateTime.fromMillisecondsSinceEpoch(s);
    DateTime endDate = DateTime.fromMillisecondsSinceEpoch(e);
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      dateList.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return dateList;
  }

  Future<void> requestPermissions() async {
    final bool isAndroid = Platform.isAndroid;
    if (isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission()
          .then((value) async {
            if (value == false) {
              await plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestExactAlarmsPermission();
            }
          });
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestFullScreenIntentPermission()
          .then((value) async {
            if (value == false) {
              await plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestFullScreenIntentPermission();
            }
          });
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission()
          .then((value) async {
            if (value == false) {
              await plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestNotificationsPermission();
            }
          });
    } else {
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
            provisional: true,
          );
    }
  }

  Future<void> showCloudNotification({required RemoteMessage message}) async {
    RemoteNotification? notification = message.notification;

    // If notification is missing, log and return
    if (notification == null ||
        notification.title == null ||
        notification.body == null) {
      appLogger.d(
        "🚨 No valid title or body found in the notification. Skipping display.",
      );
      return;
    }

    // Trim and clean the title and body to remove extra spaces/newlines
    String title = notification.title!.trim();
    String body =
        notification.body!
            .replaceAll(
              RegExp(r'\s+'),
              ' ',
            ) // Replaces multiple spaces and line breaks with a single space
            .replaceAll(
              '\n',
              ' ',
            ) // Replaces newline characters with a single space
            .trim(); // Trims leading/trailing spaces

    // Define notification details
    AndroidNotificationDetails notificationDetails =
        const AndroidNotificationDetails(
          "high_importance_channel",
          "channelName",
          category: AndroidNotificationCategory.message,
          enableVibration: true,
          importance: Importance.max,
          priority: Priority.high,
        );

    // Use a unique ID to prevent duplicate notifications
    final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: notificationDetails,
        iOS: const DarwinNotificationDetails(),
      ),
    );

    appLogger.d("🔔 Notification displayed: Title: $title, Body: $body");
  }

  Future<void> createNotificationChannel() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    final androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    final existingChannels =
        await androidImplementation?.getNotificationChannels();
    final channelExists =
        existingChannels?.any(
          (channel) => channel.id == 'high_importance_channel',
        ) ??
        false;

    if (!channelExists) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'Chat Notifications',
        description: 'This channel is for chat notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation?.createNotificationChannel(channel);
    }

    // Future<void> createNotificationChannel() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'Chat Notifications',
        description: 'This channel is for chat notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Habit reminder notification channel

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      // Create the channels

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  List<DateTime> getAllDateInMoreThan1Case({
    required List<DateTime> specificDates,
    required List<DateTime> times,
  }) {
    List<DateTime> dates = [];
    for (DateTime specificDate in specificDates) {
      for (DateTime time in times) {
        DateTime d = DateTime(
          specificDate.year,
          specificDate.month,
          specificDate.day,
          time.hour,
          time.minute,
          time.second,
        );
        dates.add(d);
      }
    }

    return dates;
  }
}

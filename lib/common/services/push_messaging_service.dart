import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/firestore_services.dart';
import 'package:flatch/common/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Background isolate handler. Notification-type messages are shown by the OS
/// automatically, so there is nothing to do here — but a handler MUST be
/// registered for background delivery to work.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications: FCM permission, per-device token storage, and routing of
/// taps to the relevant fart. Display is delegated to [NotificationServices]
/// (which owns the local-notification channel).
class PushMessagingService {
  PushMessagingService._();
  static final PushMessagingService instance = PushMessagingService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _wired = false;

  /// One-time setup of channels + foreground/tap listeners. Safe to call again.
  Future<void> initListeners() async {
    if (_wired) return;
    _wired = true;

    await NotificationServices.instance.init();
    await NotificationServices.instance.createNotificationChannel();

    // Foreground messages aren't shown by the OS — display them ourselves.
    FirebaseMessaging.onMessage.listen((message) {
      NotificationServices.instance.showCloudNotification(message: message);
    });

    // Taps that opened / resumed the app.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // Persist a refreshed token for whoever is currently signed in.
    _fcm.onTokenRefresh.listen(_saveToken);
  }

  /// Request permission and store this device's token for the signed-in user.
  /// Call after auth (e.g. from an authStateChanges listener).
  Future<void> registerForUser() async {
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      if (Platform.isIOS) {
        // FCM needs the APNS token before it can mint an FCM token on iOS.
        await _fcm.getAPNSToken();
      }
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('push: registerForUser failed: $e');
    }
  }

  /// Remove this device's token (call on sign-out).
  Future<void> unregister() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final token = await _fcm.getToken();
      if (uid == null || token == null) return;
      await FirebaseFirestore.instance
          .collection('user_push_tokens')
          .doc(uid)
          .set({
            'tokens': FieldValue.arrayRemove([token]),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('push: unregister failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Owner-only collection (kept out of the world-readable app_users doc).
      await FirebaseFirestore.instance
          .collection('user_push_tokens')
          .doc(uid)
          .set({
            'tokens': FieldValue.arrayUnion([token]),
            'platform': Platform.isIOS ? 'ios' : 'android',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('push: _saveToken failed: $e');
    }
  }

  Future<void> _handleTap(RemoteMessage message) async {
    final fartId = message.data['fartId'];
    if (fartId == null || fartId.isEmpty) return;
    try {
      final fart = await FirestoreServices.instance.fetchFartById(fartId);
      final context = navigatorKey.currentContext;
      if (context == null) return;
      // context is the router's navigatorKey context (not a State), valid here.
      // ignore: use_build_context_synchronously
      context.pushNamed(AppRoute.commentFart.name, extra: fart);
    } catch (e) {
      debugPrint('push: tap navigation failed: $e');
    }
  }
}

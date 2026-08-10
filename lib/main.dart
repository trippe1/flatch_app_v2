import 'dart:io';
import 'dart:ui';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flatch/common/services/telemetry_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flatch/common/app_helpers/theme_helper.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/age_gate_service.dart';
import 'package:flatch/common/services/deep_link_service.dart';
import 'package:flatch/common/services/push_messaging_service.dart';
import 'package:flatch/core/app.dart';
import 'package:flatch/firebase_options.dart';
import 'package:flatch/common/services/device_key_service.dart';
import 'package:flatch/common/services/firestore_cached_key_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: attest that requests come from the genuine app. Deployed in
  // MONITORING mode (unenforced) first — this collects verdicts without
  // blocking anyone. Debug builds use the debug provider so local dev works.
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
  );

  // Device auth: fetch per-device keys from the server (App Check gated) and
  // cache them in secure storage. The bundled test provider stays the default
  // for unit tests; production swaps it here.
  DeviceKeyService.keyProvider = const FirestoreCachedKeyProvider();

  // Must be registered before runApp for background push delivery.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await ThemeController.init();

  // Load the COPPA age-gate flag before requesting any permissions so blocked
  // devices never trigger a microphone/permission prompt.
  await AgeGateService.instance.preload();

  // Crashlytics + Analytics — collection is disabled on age-blocked devices.
  await Telemetry.instance.applyConsent();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  Telemetry.instance.appOpen();

  tz.initializeTimeZones();

  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // NOTE: no permissions are requested at startup. Each is requested in-context
  // at the moment the feature is used:
  //   • Microphone → when recording (AudioService), signed-in + non-age-blocked
  //   • Bluetooth  → when connecting to the Flatch device (FlatchBleCubit)
  //   • Photos     → when picking a video to upload (VideoToAudioWidget)
  //   • Camera     → never (the app does not use the camera)

  runApp(const MyApp()
  );
   DeepLinkService().startListening(navigatorKey);

  // Push notifications: wire foreground/tap handling, and (re)register this
  // device's token whenever a user signs in.
  await PushMessagingService.instance.initListeners();
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      PushMessagingService.instance.registerForUser();
    }
  });
}


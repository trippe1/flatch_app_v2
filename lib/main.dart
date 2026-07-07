import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/deep_link_service.dart';
import 'package:flatch/core/app.dart';
import 'package:flatch/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  tz.initializeTimeZones();

  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  if (Platform.isAndroid) {
    await requestAllPermissions();
  } else if (Platform.isIOS) {
    await requestAllPermissionsIOS();
  }


  runApp(const MyApp()
  );
   DeepLinkService().startListening(navigatorKey);
 
}

Future<void> requestAllPermissions() async {
  await requestMicrophonePermission();
  await requestBluetoothPermissions();
  await requestStoragePermissions();
}

Future<void> requestAllPermissionsIOS() async {
  await requestBluetoothPermissionsIOS();
  await requestStoragePermissionsIOS();
}

Future<void> requestMicrophonePermission() async {
  final status = await Permission.microphone.request();

  if (status.isGranted) {
    debugPrint('🎤 Microphone permission granted');
  } else if (status.isDenied) {
    debugPrint('❌ Microphone permission denied');
  } else if (status.isPermanentlyDenied) {
    debugPrint('🔒 Microphone permanently denied. Redirecting to settings...');
  }
}

Future<void> requestBluetoothPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

Future<void> requestBluetoothPermissionsIOS() async {
  if (Platform.isIOS) {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }
}

Future<void> requestStoragePermissions() async {
  if (Platform.version.startsWith('13') || Platform.version.startsWith('14')) {
    await [Permission.photos, Permission.videos, Permission.audio].request();
  } else {
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      debugPrint('📂 Storage permission granted');
    } else if (storageStatus.isDenied) {
      debugPrint('❌ Storage permission denied');
    } else if (storageStatus.isPermanentlyDenied) {
      debugPrint(
        '🔒 Storage permission permanently denied. Redirecting to settings...',
      );
      await openAppSettings();
    }
  }
}

Future<void> requestStoragePermissionsIOS() async {
  if (Platform.isIOS) {
    await [
      Permission.photos,
      Permission.photosAddOnly,
      Permission.camera,
    ].request();
  }
}

// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class MicPermissionService {
  static Future<bool> requestMicPermission({BuildContext? context}) async {
    debugPrint('[MicPermission] Checking microphone permission...');
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      debugPrint('[MicPermission] Already granted.');
      return true;
    }

    final result = await Permission.microphone.request();

    if (result.isGranted) {
      debugPrint('[MicPermission] Granted after request.');
      return true;
    } else if (result.isDenied) {
      debugPrint('[MicPermission] Denied.');
    }

    if (result.isPermanentlyDenied && Platform.isAndroid && context != null) {
      debugPrint(
        '[MicPermission] Permanently denied on Android. Showing dialog...',
      );
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Microphone Permission Needed'),
              content: const Text(
                'You have permanently denied microphone access. Please enable it manually from app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
      );
    }

    return false;
  }
}

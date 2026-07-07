// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:toastification/toastification.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFartFileand(
  String url,
  String fileName,
  BuildContext context,
) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text("Downloading...")),
              ],
            ),
          ),
    );

    String localPath;

    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission permanently denied. Open settings'),
            ),
          );
          openAppSettings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
        return;
      }

      final downloadsDir = Directory("/storage/emulated/0/Download");
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      localPath = "${downloadsDir.path}/$fileName";
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      localPath = "${docsDir.path}/$fileName";
    }

    final response = await http.get(Uri.parse(url));

    if (Navigator.canPop(context)) Navigator.pop(context);

    if (response.statusCode == 200) {
      final outFile = File(localPath);
      await outFile.writeAsBytes(response.bodyBytes);

      if (Platform.isIOS) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("Download Complete"),
                content: const Text(
                  "The file has been saved in the app storage.\n"
                  "You can keep it or use Share to move it elsewhere.",
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ButtonStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              AppColors.primary,
                            ),
                            side: WidgetStatePropertyAll(
                              BorderSide(color: AppColors.primary),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("OK"),
                        ),
                      ),
                      Gap(10),
                      Expanded(
                        child: ElevatedButton(
                          style: ButtonStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(
                              AppColors.primary,
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              AppColors.backgroundWhite,
                            ),
                            side: WidgetStatePropertyAll(BorderSide.none),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            final xFile = XFile(
                              localPath,
                              mimeType: _guessMime(fileName),
                            );
                            final params = ShareParams(
                              subject: fileName,
                              title: 'Share or Save file',
                              files: [xFile],
                            );
                            await SharePlus.instance.share(params);
                          },
                          child: const Text("Share"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        );
      } else {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("Download Complete"),
                content: const Text(
                  "The file has been saved in your Downloads folder.",
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ButtonStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              AppColors.primary,
                            ),
                            side: WidgetStatePropertyAll(
                              BorderSide(color: AppColors.primary),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("OK"),
                        ),
                      ),
                      Gap(10),
                      Expanded(
                        child: ElevatedButton(
                          style: ButtonStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(
                              AppColors.primary,
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              AppColors.backgroundWhite,
                            ),
                            side: WidgetStatePropertyAll(BorderSide.none),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            final xFile = XFile(
                              localPath,
                              mimeType: _guessMime(fileName),
                            );
                            final params = ShareParams(
                              subject: fileName,
                              title: 'Share or Save file',
                              files: [xFile],
                            );
                            await SharePlus.instance.share(params);
                          },
                          child: const Text("Share"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        );
      }
    } else {
      showToast(
        context: context,
        message: 'HTTP Error: ${response.statusCode}',
        type: ToastificationType.error,
      );
    }
  } catch (e) {
    try {
      if (Navigator.canPop(context)) Navigator.pop(context);
    } catch (_) {}
    showToast(
      context: context,
      message: 'Download failed: $e',
      type: ToastificationType.error,
    );
  }
}

String _guessMime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.aac')) return 'audio/aac';
  return 'application/octet-stream';
}

import 'package:flatch/common/services/app_logger.dart';
import 'package:flutter/services.dart';

class AudioConverter {
  static const platform = MethodChannel('audio.converter');

  static Future<String?> convertToMp3(String inputPath) async {
    final outputPath = inputPath.replaceAll('.aac', '.mp3');
    try {
      final result = await platform.invokeMethod<String>('convertToMp3', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return result; 
    } catch (e) {
      appLogger.e("Conversion failed: $e");
      return null;
    }
  }
}

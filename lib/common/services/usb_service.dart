import 'dart:io';
import 'package:flutter/services.dart';

class UsbPlatformService {
  static const MethodChannel _channel = MethodChannel('flatch.ble.channel');
  static const MethodChannel _convertChannel = MethodChannel('audio.converter');

  static Future<bool> isConnected() async {
    return await _channel.invokeMethod('connectToDevice');
  }

  static Future<List<File>> listFiles() async {
    final Map<String, dynamic>? result = await _channel.invokeMethod(
      'startScan',
    );
    if (result == null) return [];
    final id = result['id']?.toString();
    if (id == null) return [];
    final success = await _channel.invokeMethod('connectToDevice', {
      'deviceId': id,
    });
    return success == true ? [] : [];
  }

  static Future<bool> uploadFile(File file) async {
    final success = await _channel.invokeMethod('sendCommand', {
      'command': 'UPLOAD',
    });
    return success == true;
  }

  static Future<bool> deleteFile(String fileName) async {
    final success = await _channel.invokeMethod('sendCommand', {
      'command': 'DELETE:$fileName',
    });
    return success == true;
  }

  static Future<bool> writeSequence(List<File> orderedFiles) async {
    final paths = orderedFiles.map((f) => f.path).toList();
    final command = 'SEQUENCE:${paths.join(",")}';
    final success = await _channel.invokeMethod('sendCommand', {
      'command': command,
    });
    return success == true;
  }

  static Future<String?> convertToMp3(
    String inputPath,
    String outputExt,
  ) async {
    final result = await _convertChannel.invokeMethod('convertAudio', {
      'inputPath': inputPath,
      'outputExt': outputExt,
    });
    return result?.toString();
  }

  static Future<String?> trimAudio(
    String inputPath,
    double start,
    double duration,
  ) async {
    final result = await _convertChannel.invokeMethod('trimAudio', {
      'inputPath': inputPath,
      'start': start,
      'duration': duration,
    });
    return result?.toString();
  }
}

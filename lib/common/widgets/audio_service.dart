// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/services/age_gate_service.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Live microphone level (0.0–1.0) emitted while recording, derived from the
  /// recorder's real decibel readings (flutter_sound `onProgress`). Returns an
  /// empty stream if the recorder hasn't started yet. `onProgress` is a
  /// broadcast stream, so it's safe to listen more than once.
  Stream<double> get recordingLevelStream {
    final progress = _recorder.onProgress;
    if (progress == null) return const Stream<double>.empty();
    return progress.map((e) {
      final db = e.decibels ?? 0.0;
      // flutter_sound reports dB where louder = higher; ~60 dB ≈ full scale
      // for close-mic speech, so normalize against that for a lively meter.
      return (db / 60.0).clamp(0.0, 1.0).toDouble();
    });
  }

  Duration? get duration => _player.duration;
  Duration? get position => _player.position;
  bool get isPlaying => _player.playing;

  Future<void> initialize() async {
    await _recorder.openRecorder();
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
    await session.setActive(true);
  }

  Future<bool> checkMicrophonePermission(BuildContext context) async {
    // COPPA: an age-blocked device must never see a microphone prompt.
    if (await AgeGateService.instance.isBlocked()) return false;
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text("Microphone Permission Required"),
              content: Text(
                "Please enable microphone access in Settings to record audio.",
              ),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text("Open Settings"),
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
      );
      return false;
    }

    return false;
  }

  Future<void> dispose() async {
    await _recorder.closeRecorder();
    await _player.dispose();
  }

  Future<bool> startRecording(BuildContext context) async {
    try {
      // COPPA: age-blocked devices can never record.
      if (await AgeGateService.instance.isBlocked()) return false;
      final status = await Permission.microphone.request();
      if (!status.isGranted) return false;

      if (!_recorder.isRecording) {
        await _recorder.openRecorder();
        debugPrint('🎤 Recorder opened');
      }
      final tempDir = await getTemporaryDirectory();
      final fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${tempDir.path}/$fileName';
      debugPrint('📝 Recording path: $path');

      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacMP4,
        sampleRate: 44100,
        bitRate: 128000,
      );
      // Emit progress (incl. decibels) ~10x/sec so the level meter is live.
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint('▶ Recording started');
      return true;
    } catch (e, s) {
      debugPrint('❌ Error starting recording: $e\n$s');
      return false;
    }
  }

  Future<Map<String, dynamic>?> stopRecording() async {
    try {
      debugPrint("🐛 FS:<--- stopRecorder");

      final rawPath = await _recorder.stopRecorder();
      if (rawPath == null) {
        debugPrint("❌ stopRecorder returned null");
        return null;
      }

      // Remove file:// prefix if present
      final tempPath =
          rawPath.startsWith('file://') ? rawPath.substring(7) : rawPath;
      final tempFile = File(tempPath);

      if (!await tempFile.exists()) {
        debugPrint("❌ Temp file does not exist yet: $tempPath");
        return null;
      }

      // Prepare stable storage directory
      final docs = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${docs.path}/Recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Detect file extension dynamically
      final ext = tempFile.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'rec_$timestamp.$ext';
      final stablePath = '${recordingsDir.path}/$fileName';

      // Copy file to stable location
      final stableFile = await tempFile.copy(stablePath);
      debugPrint("📂 Stable file: ${stableFile.path}");

      // Wait until file is fully written
      bool fileReady = false;
      int retries = 10;
      while (retries-- > 0) {
        if (await stableFile.exists()) {
          final length = await stableFile.length();
          if (length > 0) {
            fileReady = true;
            break;
          }
        }
        debugPrint("⏳ Waiting for $ext file to be flushed...");
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (!fileReady) {
        debugPrint("❌ Final $ext file not fully available");
        return null;
      }

      // Let AVFoundation sync on iOS
      await Future.delayed(const Duration(milliseconds: 300));

      // Load file into player
      debugPrint("📝 Loading audio file at path: ${stableFile.path}");
      await _player.setFilePath(stableFile.path);
      debugPrint("🎵 Loaded audio into player");

      final duration = _player.duration;

      return {
        'path': stableFile.path,
        'fileName': fileName,
        'fileType': ext,
        'duration': duration,
      };
    } catch (e, st) {
      debugPrint('❌ Exception in stopRecording: $e\n$st');
      return null;
    }
  }


  Future<void> pauseRecording() async {
    await _recorder.pauseRecorder();
  }

  Future<void> resumeRecording() async {
    await _recorder.resumeRecorder();
  }

  Future<void> loadAudio(String path) async {
    if (path.isEmpty) {
      await _player.stop();
      return;
    }

    try {
      await _player.setFilePath(path);
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  Future<void> play() async {
   
    await AudioRoute.toSpeakerUnlessHeadphones();
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    await _player.stop();
  }
}

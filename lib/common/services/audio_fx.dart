import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flatch/common/services/audio_dsp.dart';

/// Result of an effects render: the processed file [path] and its new duration.
class FxRenderResult {
  final String path;
  final int? durationMs;
  const FxRenderResult(this.path, this.durationMs);
}

/// Bridges the sound editor to the DSP engine and the native ffmpeg channel.
///
/// Effects are rendered non-destructively in pure Dart ([AudioDsp]) off the UI
/// thread: the source is decoded to PCM natively, processed in an isolate,
/// written back to a WAV, then re-encoded (with loudness normalization) through
/// the same native path used elsewhere. Waveform extraction still uses the
/// native decoder directly.
class AudioFx {
  static const MethodChannel _channel = MethodChannel('audio.converter');

  /// Render [settings] over the audio at [inputPath]. When nothing is enabled
  /// the input is returned unchanged. Returns null on failure.
  static Future<FxRenderResult?> render(
    String inputPath,
    FxSettings settings, {
    String outputExt = 'm4a',
    int sampleRate = 44100,
  }) async {
    if (!settings.anyOn) return FxRenderResult(inputPath, null);

    final samples = await _decodeToFloat(inputPath, sampleRate);
    if (samples == null || samples.isEmpty) return null;

    // Heavy DSP runs in a background isolate so the UI stays responsive.
    final processed = await compute(runFlatchDsp, {
      'samples': samples,
      'sampleRate': sampleRate,
      'settings': settings.toMap(),
    });

    final wavPath = await _writeWav(processed, sampleRate);
    final durationMs = (processed.length / sampleRate * 1000).round();

    // Re-encode to the compressed upload/playback format with loudnorm.
    final encoded = await _encode(wavPath, outputExt);
    try {
      await File(wavPath).delete();
    } catch (_) {}

    return FxRenderResult(encoded ?? wavPath, durationMs);
  }

  /// Decode any audio file to mono float samples in [-1, 1] at [sampleRate].
  static Future<Float32List?> _decodeToFloat(
    String inputPath,
    int sampleRate,
  ) async {
    String? pcmPath;
    try {
      pcmPath = await _channel.invokeMethod<String>('extractPcm', {
        'inputPath': inputPath,
        'sampleRate': sampleRate,
      });
    } catch (_) {
      return null;
    }
    if (pcmPath == null) return null;

    final file = File(pcmPath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}

    final count = bytes.length ~/ 2; // s16le mono
    final data = ByteData.sublistView(bytes);
    final out = Float32List(count);
    for (int i = 0; i < count; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// Write mono float samples to a 16-bit PCM WAV file, return its path.
  static Future<String> _writeWav(Float32List samples, int sampleRate) async {
    final dir = Directory.systemTemp;
    final path =
        '${dir.path}/fx_${DateTime.now().microsecondsSinceEpoch}.wav';
    final n = samples.length;
    const bitsPerSample = 16;
    const channels = 1;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final dataSize = n * 2;
    final buffer = BytesBuilder();

    void writeStr(String s) => buffer.add(s.codeUnits);
    void writeU32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      buffer.add(b.buffer.asUint8List());
    }

    void writeU16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      buffer.add(b.buffer.asUint8List());
    }

    writeStr('RIFF');
    writeU32(36 + dataSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16);
    writeU16(1); // PCM
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(channels * bitsPerSample ~/ 8); // block align
    writeU16(bitsPerSample);
    writeStr('data');
    writeU32(dataSize);

    final pcm = ByteData(dataSize);
    for (int i = 0; i < n; i++) {
      var v = (samples[i] * 32767.0).round();
      if (v > 32767) v = 32767;
      if (v < -32768) v = -32768;
      pcm.setInt16(i * 2, v, Endian.little);
    }
    buffer.add(pcm.buffer.asUint8List());

    final file = File(path);
    await file.writeAsBytes(buffer.takeBytes(), flush: true);
    return path;
  }

  /// Re-encode [wavPath] to [outputExt] with loudness normalization via the
  /// native converter (`anull` filter — the DSP already did the real work).
  static Future<String?> _encode(String wavPath, String outputExt) async {
    try {
      return await _channel.invokeMethod<String>('applyAudioFilter', {
        'inputPath': wavPath,
        'filter': 'anull',
        'outputExt': outputExt,
      });
    } catch (_) {
      return null;
    }
  }

  /// Extract a normalized waveform (values 0..1) with [buckets] bars from the
  /// audio at [inputPath], by decoding to low-rate mono PCM and peak-bucketing.
  static Future<List<double>> waveform(
    String inputPath, {
    int buckets = 120,
    int sampleRate = 8000,
  }) async {
    String? pcmPath;
    try {
      pcmPath = await _channel.invokeMethod<String>('extractPcm', {
        'inputPath': inputPath,
        'sampleRate': sampleRate,
      });
    } catch (_) {
      return const [];
    }
    if (pcmPath == null) return const [];

    final file = File(pcmPath);
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}

    final sampleCount = bytes.length ~/ 2; // s16le mono
    if (sampleCount == 0) return const [];
    final data = ByteData.sublistView(bytes);

    final peaks = List<double>.filled(buckets, 0);
    double globalMax = 1;
    for (int b = 0; b < buckets; b++) {
      final start = (b * sampleCount / buckets).floor();
      final end = ((b + 1) * sampleCount / buckets).floor();
      double peak = 0;
      for (int i = start; i < end && i < sampleCount; i++) {
        final s = data.getInt16(i * 2, Endian.little).abs().toDouble();
        if (s > peak) peak = s;
      }
      peaks[b] = peak;
      if (peak > globalMax) globalMax = peak;
    }
    return peaks.map((e) => (e / globalMax).clamp(0.0, 1.0)).toList();
  }
}

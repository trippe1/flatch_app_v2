import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flatch/common/services/audio_dsp.dart';
import 'package:flutter_test/flutter_test.dart';

const int _sr = 44100;

double _rms(Float32List x, [int? start, int? end]) {
  start ??= 0;
  end ??= x.length;
  double e = 0;
  for (int i = start; i < end; i++) {
    e += x[i] * x[i];
  }
  return math.sqrt(e / math.max(1, end - start));
}

double _peak(Float32List x) {
  double p = 0;
  for (final v in x) {
    if (v.abs() > p) p = v.abs();
  }
  return p;
}

/// A tone burst: silence, then a short loud sine (stands in for the "fart").
Float32List _burst({
  int leadSilenceMs = 500,
  int burstMs = 300,
  int trailMs = 200,
  double freq = 220,
  double amp = 0.7,
}) {
  final lead = _sr * leadSilenceMs ~/ 1000;
  final burst = _sr * burstMs ~/ 1000;
  final trail = _sr * trailMs ~/ 1000;
  final n = lead + burst + trail;
  final x = Float32List(n);
  for (int i = 0; i < burst; i++) {
    x[lead + i] = amp * math.sin(2 * math.pi * freq * i / _sr);
  }
  return x;
}

/// Deterministic pseudo-random noise in [-amp, amp] (no dart:math Random so the
/// test is fully repeatable).
Float32List _addHiss(Float32List x, double amp) {
  final out = Float32List.fromList(x);
  int seed = 12345;
  for (int i = 0; i < out.length; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final r = (seed / 0x7fffffff) * 2 - 1;
    out[i] = (out[i] + amp * r).clamp(-1.0, 1.0);
  }
  return out;
}

void main() {
  group('Echo (feedback delay)', () {
    test('dry signal is preserved unchanged in the original window', () {
      final x = _burst();
      final y = AudioDsp.echo(x, _sr, 200, 0.4, 0.35);
      // First delay-worth of samples has no echo yet → identical to dry.
      final d = 200 * _sr ~/ 1000;
      for (int i = 0; i < d; i++) {
        expect(y[i], closeTo(x[i], 1e-6));
      }
    });

    test('adds a decaying tail past the original length', () {
      final x = _burst(trailMs: 0);
      final y = AudioDsp.echo(x, _sr, 200, 0.5, 0.5);
      expect(y.length, greaterThan(x.length));
      // There is audible energy in the tail region (the repeats).
      final tail = _rms(y, x.length, y.length);
      expect(tail, greaterThan(1e-4));
    });

    test('repeats get quieter over time (energy decays)', () {
      // Single click so we can see discrete repeats.
      final x = Float32List(_sr); // 1s
      x[0] = 1.0;
      final d = (0.1 * _sr).round(); // 100ms
      final y = AudioDsp.echo(x, _sr, 100, 0.6, 1.0);
      final r1 = y[d].abs(); // first repeat
      final r2 = y[2 * d].abs(); // second repeat
      final r3 = y[3 * d].abs(); // third repeat
      expect(r1, greaterThan(r2));
      expect(r2, greaterThan(r3));
      // Ratio ~ feedback (0.6).
      expect(r2 / r1, closeTo(0.6, 0.05));
    });

    test('feedback is clamped below 1 (no runaway)', () {
      final x = Float32List(_sr);
      x[0] = 1.0;
      final y = AudioDsp.echo(x, _sr, 100, 0.95, 1.0);
      expect(_peak(y).isFinite, isTrue);
      expect(_peak(y), lessThanOrEqualTo(1.0));
    });
  });

  group('Reverb (Freeverb)', () {
    test('adds a smooth tail beyond the source', () {
      final x = _burst(trailMs: 0);
      final y = AudioDsp.reverb(x, _sr, 1.5, 0.5, 20, 0.5);
      expect(y.length, greaterThan(x.length));
      final tail = _rms(y, x.length, y.length);
      expect(tail, greaterThan(1e-4));
    });

    test('longer decay produces a longer, more energetic tail', () {
      final x = _burst(trailMs: 0);
      final small = AudioDsp.reverb(x, _sr, 0.4, 0.5, 0, 0.5);
      final hall = AudioDsp.reverb(x, _sr, 3.0, 0.5, 0, 0.5);
      expect(hall.length, greaterThan(small.length));
    });

    test('mix=0 leaves the dry signal essentially intact', () {
      final x = _burst();
      final y = AudioDsp.reverb(x, _sr, 1.2, 0.0, 0, 0.5);
      for (int i = 0; i < x.length; i++) {
        expect(y[i], closeTo(x[i], 1e-6));
      }
    });
  });

  group('Noise Reduction (spectral gating)', () {
    test('lowers the steady noise floor while preserving the transient', () {
      final clean = _burst(
        leadSilenceMs: 500,
        burstMs: 300,
        trailMs: 300,
        amp: 0.7,
      );
      final noisy = _addHiss(clean, 0.05);
      final out = AudioDsp.denoise(noisy, _sr, 15);

      // Noise floor measured in the lead-in silence (first 400ms).
      final win = (0.4 * _sr).round();
      final noiseBefore = _rms(noisy, 0, win);
      final noiseAfter = _rms(out, 0, win);
      expect(
        noiseAfter,
        lessThan(noiseBefore * 0.6),
        reason: 'background hiss should drop substantially',
      );

      // The loud burst must survive: its RMS stays close to the clean burst.
      final bStart = (0.5 * _sr).round();
      final bEnd = (0.8 * _sr).round();
      final burstClean = _rms(clean, bStart, bEnd);
      final burstOut = _rms(out, bStart, bEnd);
      expect(
        burstOut,
        greaterThan(burstClean * 0.7),
        reason: 'the fart transient must come through preserved',
      );
    });

    test('does not blow up on a clip shorter than the FFT window', () {
      final x = Float32List(256)..[10] = 0.5;
      final out = AudioDsp.denoise(x, _sr, 15);
      expect(out.length, x.length);
    });
  });

  group('FxSettings', () {
    test('round-trips through toMap/fromMap', () {
      const s = FxSettings(
        noiseReduce: true,
        nrAmount: 0.7,
        echoOn: true,
        echoDelayMs: 250,
        echoFeedback: 0.5,
        echoMix: 0.4,
        reverbOn: true,
        reverbDecayS: 2.0,
        reverbMix: 0.3,
        reverbPreDelayMs: 40,
        reverbDamping: 0.6,
      );
      expect(FxSettings.fromMap(s.toMap()), s);
    });

    test('anyOn reflects enabled effects; reduction maps to 12..20 dB', () {
      expect(const FxSettings().anyOn, isFalse);
      expect(const FxSettings(echoOn: true).anyOn, isTrue);
      expect(const FxSettings(nrAmount: 0).nrReductionDb, closeTo(12, 1e-9));
      expect(const FxSettings(nrAmount: 1).nrReductionDb, closeTo(20, 1e-9));
    });
  });

  group('Combined pipeline', () {
    test('stacked effects never clip and extend the clip', () {
      final x = _addHiss(_burst(trailMs: 0), 0.04);
      const s = FxSettings(
        noiseReduce: true,
        echoOn: true,
        reverbOn: true,
      );
      final y = AudioDsp.process(x, _sr, s);
      expect(_peak(y), lessThanOrEqualTo(0.999 + 1e-6));
      expect(y.length, greaterThan(x.length));
    });
  });
}

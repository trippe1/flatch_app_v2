/// Pure-Dart audio DSP for the sound editor's three effects: Noise Reduction
/// (STFT spectral gating with an auto-built noise profile), Echo (a feedback
/// delay line with a decaying tail), and Reverb (a Freeverb-style algorithmic
/// reverb). All routines operate on mono `Float32List` samples in [-1, 1] at a
/// known sample rate and are self-contained so they can run inside an isolate
/// (via `compute`) without touching Flutter/platform code.
///
/// Processing order when effects stack: Noise Reduction → Echo → Reverb.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// User-facing settings for the three effects. Ranges match the editor UI.
class FxSettings extends Equatable {
  // ---- Noise Reduction ----
  final bool noiseReduce;

  /// 0..1 slider → 12..20 dB of conservative spectral reduction.
  final double nrAmount;

  // ---- Echo (feedback delay) ----
  final bool echoOn;

  /// Gap between repeats, 50..800 ms.
  final double echoDelayMs;

  /// 0..0.9 — how much of each repeat feeds back (never ≥ 1: no runaway).
  final double echoFeedback;

  /// Wet/dry, 0..1.
  final double echoMix;

  // ---- Reverb (Freeverb) ----
  final bool reverbOn;

  /// Decay/room size as a tail length in seconds, 0.4 (small room) .. 3.0 (hall).
  final double reverbDecayS;

  /// Wet/dry, 0..1.
  final double reverbMix;

  /// Pre-delay before the reverb tail, 0..100 ms.
  final double reverbPreDelayMs;

  /// High-frequency damping of the tail, 0..1.
  final double reverbDamping;

  const FxSettings({
    this.noiseReduce = false,
    this.nrAmount = 0.5,
    this.echoOn = false,
    this.echoDelayMs = 300,
    this.echoFeedback = 0.4,
    this.echoMix = 0.35,
    this.reverbOn = false,
    this.reverbDecayS = 1.2,
    this.reverbMix = 0.25,
    this.reverbPreDelayMs = 20,
    this.reverbDamping = 0.5,
  });

  bool get anyOn => noiseReduce || echoOn || reverbOn;

  /// Conservative reduction floor in dB (12..20) from the amount slider.
  double get nrReductionDb => 12.0 + nrAmount.clamp(0.0, 1.0) * 8.0;

  FxSettings copyWith({
    bool? noiseReduce,
    double? nrAmount,
    bool? echoOn,
    double? echoDelayMs,
    double? echoFeedback,
    double? echoMix,
    bool? reverbOn,
    double? reverbDecayS,
    double? reverbMix,
    double? reverbPreDelayMs,
    double? reverbDamping,
  }) {
    return FxSettings(
      noiseReduce: noiseReduce ?? this.noiseReduce,
      nrAmount: nrAmount ?? this.nrAmount,
      echoOn: echoOn ?? this.echoOn,
      echoDelayMs: echoDelayMs ?? this.echoDelayMs,
      echoFeedback: echoFeedback ?? this.echoFeedback,
      echoMix: echoMix ?? this.echoMix,
      reverbOn: reverbOn ?? this.reverbOn,
      reverbDecayS: reverbDecayS ?? this.reverbDecayS,
      reverbMix: reverbMix ?? this.reverbMix,
      reverbPreDelayMs: reverbPreDelayMs ?? this.reverbPreDelayMs,
      reverbDamping: reverbDamping ?? this.reverbDamping,
    );
  }

  Map<String, dynamic> toMap() => {
    'noiseReduce': noiseReduce,
    'nrAmount': nrAmount,
    'echoOn': echoOn,
    'echoDelayMs': echoDelayMs,
    'echoFeedback': echoFeedback,
    'echoMix': echoMix,
    'reverbOn': reverbOn,
    'reverbDecayS': reverbDecayS,
    'reverbMix': reverbMix,
    'reverbPreDelayMs': reverbPreDelayMs,
    'reverbDamping': reverbDamping,
  };

  factory FxSettings.fromMap(Map<String, dynamic> m) => FxSettings(
    noiseReduce: m['noiseReduce'] ?? false,
    nrAmount: (m['nrAmount'] ?? 0.5).toDouble(),
    echoOn: m['echoOn'] ?? false,
    echoDelayMs: (m['echoDelayMs'] ?? 300).toDouble(),
    echoFeedback: (m['echoFeedback'] ?? 0.4).toDouble(),
    echoMix: (m['echoMix'] ?? 0.35).toDouble(),
    reverbOn: m['reverbOn'] ?? false,
    reverbDecayS: (m['reverbDecayS'] ?? 1.2).toDouble(),
    reverbMix: (m['reverbMix'] ?? 0.25).toDouble(),
    reverbPreDelayMs: (m['reverbPreDelayMs'] ?? 20).toDouble(),
    reverbDamping: (m['reverbDamping'] ?? 0.5).toDouble(),
  );

  @override
  List<Object?> get props => [
    noiseReduce,
    nrAmount,
    echoOn,
    echoDelayMs,
    echoFeedback,
    echoMix,
    reverbOn,
    reverbDecayS,
    reverbMix,
    reverbPreDelayMs,
    reverbDamping,
  ];
}

/// Isolate entry point (usable with `compute`). Expects `{'samples':Float32List,
/// 'sampleRate':int, 'settings':Map}` and returns the processed samples.
Float32List runFlatchDsp(Map<String, dynamic> args) {
  final samples = args['samples'] as Float32List;
  final sr = args['sampleRate'] as int;
  final s = FxSettings.fromMap(
    (args['settings'] as Map).cast<String, dynamic>(),
  );
  return AudioDsp.process(samples, sr, s);
}

/// Stateless DSP kernel. Everything here is deterministic and isolate-safe.
class AudioDsp {
  AudioDsp._();

  /// Apply the enabled effects in order (NR → Echo → Reverb) and guard the
  /// output against clipping. Returns a new buffer; [input] is not mutated.
  static Float32List process(Float32List input, int sr, FxSettings s) {
    Float32List y = input;
    if (s.noiseReduce) y = denoise(y, sr, s.nrReductionDb);
    if (s.echoOn) {
      y = echo(y, sr, s.echoDelayMs, s.echoFeedback.clamp(0.0, 0.9), s.echoMix);
    }
    if (s.reverbOn) {
      y = reverb(
        y,
        sr,
        s.reverbDecayS,
        s.reverbMix,
        s.reverbPreDelayMs,
        s.reverbDamping,
      );
    }
    return _peakGuard(y);
  }

  // ===================================================================
  //  Echo — classic feedback delay
  // ===================================================================
  /// The dry signal is passed through unchanged; delayed copies repeat every
  /// [delayMs], each [feedback]× quieter than the last, mixed in at [mix]. The
  /// output is extended so the decaying tail is not cut off.
  static Float32List echo(
    Float32List x,
    int sr,
    double delayMs,
    double feedback,
    double mix,
  ) {
    final n = x.length;
    if (n == 0) return x;
    final fb = feedback.clamp(0.0, 0.95);
    final d = math.max(1, (delayMs / 1000.0 * sr).round());

    // Number of audible repeats until the level drops below ~-60 dB, so the
    // rendered clip is long enough to hold the whole tail.
    final int repeats = fb <= 0.0
        ? 1
        : math.max(1, (math.log(0.001) / math.log(fb)).ceil());
    final tail = d * repeats;
    final outLen = n + tail;

    // u = feedback comb of the delayed dry signal (the "wet" echoes only).
    final u = Float64List(outLen);
    final out = Float32List(outLen);
    for (int i = 0; i < outLen; i++) {
      final dry = i < n ? x[i] : 0.0;
      final delayedX = (i - d >= 0 && i - d < n) ? x[i - d] : 0.0;
      final delayedU = (i - d >= 0) ? u[i - d] : 0.0;
      u[i] = fb * (delayedX + delayedU);
      out[i] = dry + mix * u[i];
    }
    return out;
  }

  // ===================================================================
  //  Reverb — Freeverb (8 combs + 4 allpass), auto-leveled wet
  // ===================================================================
  static const List<int> _combTuning = [
    1116,
    1188,
    1277,
    1356,
    1422,
    1491,
    1557,
    1617,
  ];
  static const List<int> _allpassTuning = [556, 441, 341, 225];

  /// Dense algorithmic reverb. [decayS] sets the tail length (0.4 s small room
  /// → 3.0 s hall), [damping] rolls off the high frequencies of the tail,
  /// [preDelayMs] delays the onset of the wash, and the wet signal is
  /// auto-leveled to the dry RMS so [mix] behaves predictably.
  static Float32List reverb(
    Float32List x,
    int sr,
    double decayS,
    double mix,
    double preDelayMs,
    double damping,
  ) {
    final n = x.length;
    if (n == 0) return x;

    final room = ((decayS - 0.4) / (3.0 - 0.4)).clamp(0.0, 1.0);
    final feedback = 0.7 + room * 0.28; // 0.70 .. 0.98
    final damp1 = damping.clamp(0.0, 1.0) * 0.4;
    final damp2 = 1.0 - damp1;
    final scale = sr / 44100.0;
    final preD = math.max(0, (preDelayMs / 1000.0 * sr).round());
    final tail = math.max(1, (decayS * sr).round());
    final outLen = n + tail;

    final combs = _combTuning
        .map((t) => _Comb(math.max(1, (t * scale).round()), feedback, damp1, damp2))
        .toList();
    final allpasses = _allpassTuning
        .map((t) => _Allpass(math.max(1, (t * scale).round()), 0.5))
        .toList();

    const inputGain = 0.015; // Freeverb "fixedgain"
    final wet = Float64List(outLen);
    for (int i = 0; i < outLen; i++) {
      final srcIndex = i - preD;
      final input = (srcIndex >= 0 && srcIndex < n) ? x[srcIndex] : 0.0;
      final gained = input * inputGain;
      double acc = 0.0;
      for (final c in combs) {
        acc += c.process(gained);
      }
      for (final a in allpasses) {
        acc = a.process(acc);
      }
      wet[i] = acc;
    }

    // Auto-level the wet signal to the dry RMS so `mix` reads as a true
    // wet/dry balance regardless of Freeverb's internal gain.
    double dryEnergy = 0, wetEnergy = 0;
    for (int i = 0; i < n; i++) {
      dryEnergy += x[i] * x[i];
      wetEnergy += wet[i] * wet[i];
    }
    final dryRms = math.sqrt(dryEnergy / n);
    final wetRms = math.sqrt(wetEnergy / math.max(1, n));
    final wetGain = wetRms > 1e-9 ? (dryRms / wetRms) : 0.0;

    final out = Float32List(outLen);
    final m = mix.clamp(0.0, 1.0);
    for (int i = 0; i < outLen; i++) {
      final dry = i < n ? x[i] : 0.0;
      out[i] = dry * (1.0 - m) + wet[i] * wetGain * m;
    }
    return out;
  }

  // ===================================================================
  //  Noise Reduction — STFT spectral gating with auto noise profile
  // ===================================================================
  /// Removes steady-state background noise while preserving the loud, broadband
  /// transient (the fart). A noise profile is built automatically from the
  /// quietest ~400 ms of the clip; frequency bins that stay near that profile
  /// are attenuated (down to [reductionDb]) and bins that exceed it pass
  /// through. Gains are smoothed across frequency and time to avoid musical
  /// noise.
  static Float32List denoise(Float32List x, int sr, double reductionDb) {
    final n = x.length;
    const fftSize = 1024;
    const hop = 256; // 75% overlap
    if (n < fftSize) return x; // too short to profile meaningfully

    final win = _hann(fftSize);
    final pad = fftSize;
    final total = pad + n + pad;
    final xp = Float64List(total);
    for (int i = 0; i < n; i++) {
      xp[pad + i] = x[i];
    }

    final numFrames = ((total - fftSize) ~/ hop) + 1;
    final half = fftSize ~/ 2;

    // Store the analysis STFT (flat) so we can profile then re-gate.
    final reAll = Float64List(numFrames * fftSize);
    final imAll = Float64List(numFrames * fftSize);
    final energy = Float64List(numFrames);

    final re = Float64List(fftSize);
    final im = Float64List(fftSize);
    for (int f = 0; f < numFrames; f++) {
      final start = f * hop;
      for (int k = 0; k < fftSize; k++) {
        re[k] = xp[start + k] * win[k];
        im[k] = 0.0;
      }
      _fft(re, im, false);
      double e = 0;
      final base = f * fftSize;
      for (int k = 0; k < fftSize; k++) {
        reAll[base + k] = re[k];
        imAll[base + k] = im[k];
      }
      for (int k = 0; k <= half; k++) {
        final mag = re[k] * re[k] + im[k] * im[k];
        e += mag;
      }
      energy[f] = e;
    }

    // Noise profile: the lowest-energy run of frames spanning ~400 ms.
    final profileFrames = math.max(
      1,
      math.min(numFrames, (0.4 * sr / hop).round()),
    );
    int bestStart = 0;
    double bestSum = double.infinity;
    double running = 0;
    for (int f = 0; f < numFrames; f++) {
      running += energy[f];
      if (f >= profileFrames) running -= energy[f - profileFrames];
      if (f >= profileFrames - 1) {
        if (running < bestSum) {
          bestSum = running;
          bestStart = f - profileFrames + 1;
        }
      }
    }
    final noiseMag = Float64List(half + 1);
    for (int f = bestStart; f < bestStart + profileFrames; f++) {
      final base = f * fftSize;
      for (int k = 0; k <= half; k++) {
        noiseMag[k] +=
            math.sqrt(reAll[base + k] * reAll[base + k] +
                imAll[base + k] * imAll[base + k]);
      }
    }
    for (int k = 0; k <= half; k++) {
      noiseMag[k] /= profileFrames;
    }

    final floor = math.pow(10.0, -reductionDb / 20.0).toDouble();
    const beta = 1.8; // over-subtraction factor
    final outBuf = Float64List(total);
    final norm = Float64List(total);
    final prevGain = Float64List(half + 1)..fillRange(0, half + 1, 1.0);
    final gain = Float64List(half + 1);
    final smoothed = Float64List(half + 1);

    for (int f = 0; f < numFrames; f++) {
      final base = f * fftSize;
      // Per-bin spectral-subtraction gain.
      for (int k = 0; k <= half; k++) {
        final mag = math.sqrt(
          reAll[base + k] * reAll[base + k] + imAll[base + k] * imAll[base + k],
        );
        double g = mag <= 1e-12 ? floor : (mag - beta * noiseMag[k]) / mag;
        if (g < floor) g = floor;
        if (g > 1.0) g = 1.0;
        gain[k] = g;
      }
      // Smooth across frequency (3-bin moving average) to reduce musical noise.
      for (int k = 0; k <= half; k++) {
        final a = k > 0 ? gain[k - 1] : gain[k];
        final b = gain[k];
        final c = k < half ? gain[k + 1] : gain[k];
        smoothed[k] = (a + b + c) / 3.0;
      }
      // Smooth across time (attack/release toward the new gain).
      for (int k = 0; k <= half; k++) {
        final target = smoothed[k];
        final g = target > prevGain[k]
            ? prevGain[k] + 0.5 * (target - prevGain[k]) // faster to open
            : prevGain[k] + 0.3 * (target - prevGain[k]); // slower to close
        prevGain[k] = g;
        re[k] = reAll[base + k] * g;
        im[k] = imAll[base + k] * g;
      }
      // Mirror to the negative frequencies (conjugate symmetry).
      for (int k = 1; k < half; k++) {
        re[fftSize - k] = re[k];
        im[fftSize - k] = -im[k];
      }
      re[half] = reAll[base + half] * prevGain[half];
      im[half] = imAll[base + half] * prevGain[half];

      _fft(re, im, true); // inverse

      final start = f * hop;
      for (int k = 0; k < fftSize; k++) {
        // Synthesis window (Hann) → COLA; normalize by accumulated window^2.
        final w = win[k];
        outBuf[start + k] += re[k] * w;
        norm[start + k] += w * w;
      }
    }

    final out = Float32List(n);
    for (int i = 0; i < n; i++) {
      final idx = pad + i;
      final den = norm[idx];
      out[i] = den > 1e-9 ? (outBuf[idx] / den) : 0.0;
    }
    return out;
  }

  // ---- helpers ------------------------------------------------------
  static Float32List _peakGuard(Float32List x) {
    double peak = 0;
    for (final v in x) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    if (peak <= 0.999) return x;
    final g = 0.999 / peak;
    final out = Float32List(x.length);
    for (int i = 0; i < x.length; i++) {
      out[i] = x[i] * g;
    }
    return out;
  }

  static Float64List _hann(int n) {
    final w = Float64List(n);
    for (int i = 0; i < n; i++) {
      w[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
    }
    return w;
  }

  /// In-place iterative radix-2 Cooley–Tukey FFT. [re]/[im] length must be a
  /// power of two. [inverse] does the IFFT (scaled by 1/N).
  static void _fft(Float64List re, Float64List im, bool inverse) {
    final n = re.length;
    // Bit-reversal permutation.
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (int len = 2; len <= n; len <<= 1) {
      final ang = 2 * math.pi / len * (inverse ? 1 : -1);
      final wr = math.cos(ang);
      final wi = math.sin(ang);
      final halfLen = len >> 1;
      for (int i = 0; i < n; i += len) {
        double cwr = 1.0, cwi = 0.0;
        for (int k = 0; k < halfLen; k++) {
          final a = i + k;
          final b = a + halfLen;
          final vr = re[b] * cwr - im[b] * cwi;
          final vi = re[b] * cwi + im[b] * cwr;
          re[b] = re[a] - vr;
          im[b] = im[a] - vi;
          re[a] += vr;
          im[a] += vi;
          final ncwr = cwr * wr - cwi * wi;
          cwi = cwr * wi + cwi * wr;
          cwr = ncwr;
        }
      }
    }
    if (inverse) {
      for (int i = 0; i < n; i++) {
        re[i] /= n;
        im[i] /= n;
      }
    }
  }
}

/// Freeverb lowpass-feedback comb filter.
class _Comb {
  final Float64List _buf;
  int _idx = 0;
  double _store = 0.0;
  final double _feedback;
  final double _damp1;
  final double _damp2;

  _Comb(int size, this._feedback, this._damp1, this._damp2)
    : _buf = Float64List(size);

  double process(double input) {
    final output = _buf[_idx];
    _store = output * _damp2 + _store * _damp1;
    _buf[_idx] = input + _store * _feedback;
    if (++_idx >= _buf.length) _idx = 0;
    return output;
  }
}

/// Freeverb allpass filter.
class _Allpass {
  final Float64List _buf;
  int _idx = 0;
  final double _feedback;

  _Allpass(int size, this._feedback) : _buf = Float64List(size);

  double process(double input) {
    final bufout = _buf[_idx];
    final output = -input + bufout;
    _buf[_idx] = input + bufout * _feedback;
    if (++_idx >= _buf.length) _idx = 0;
    return output;
  }
}

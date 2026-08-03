import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/services/audio_dsp.dart';
import 'package:flutter/material.dart';

/// Sound-editor effects: Noise Reduction, Echo, and Reverb, each an on/off
/// section that reveals its parameter sliders when enabled.
///
/// The parent owns the [FxSettings]. [onChanged] fires on every change with a
/// `commit` flag: `false` while a slider is being dragged (update the UI only)
/// and `true` when a toggle flips or a drag ends (re-render the audio). This
/// avoids re-processing on every pixel of a drag.
class AudioEffectsPanel extends StatelessWidget {
  final FxSettings settings;
  final bool processing;
  final void Function(FxSettings next, {required bool commit}) onChanged;

  const AudioEffectsPanel({
    super.key,
    required this.settings,
    required this.processing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Effects',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            if (processing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AbsorbPointer(
          absorbing: processing,
          child: Column(
            children: [
              _NoiseReductionCard(settings: settings, onChanged: onChanged),
              const SizedBox(height: 8),
              _EchoCard(settings: settings, onChanged: onChanged),
              const SizedBox(height: 8),
              _ReverbCard(settings: settings, onChanged: onChanged),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared card chrome: a header with a title + on/off switch, and a body that
/// appears when the effect is enabled.
class _EffectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool on;
  final ValueChanged<bool> onToggle;
  final Widget body;

  const _EffectCard({
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onToggle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.primary : Colors.grey;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: on
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Colors.grey,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                activeThumbColor: AppColors.primary,
                onChanged: onToggle,
              ),
            ],
          ),
          if (on) ...[const SizedBox(height: 4), body],
        ],
      ),
    );
  }
}

/// A labeled slider that reports live drags (commit:false) and drag-end
/// (commit:true) separately.
class _FxSlider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _FxSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text(
                valueLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.primary,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}

class _NoiseReductionCard extends StatelessWidget {
  final FxSettings settings;
  final void Function(FxSettings next, {required bool commit}) onChanged;

  const _NoiseReductionCard({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _EffectCard(
      title: 'Noise Reduction',
      subtitle: 'Remove steady background hiss & hum',
      on: settings.noiseReduce,
      onToggle: (v) =>
          onChanged(settings.copyWith(noiseReduce: v), commit: true),
      body: _FxSlider(
        label: 'Amount',
        valueLabel: '${settings.nrReductionDb.round()} dB',
        value: settings.nrAmount,
        min: 0,
        max: 1,
        onChanged: (v) =>
            onChanged(settings.copyWith(nrAmount: v), commit: false),
        onChangeEnd: (v) =>
            onChanged(settings.copyWith(nrAmount: v), commit: true),
      ),
    );
  }
}

class _EchoCard extends StatelessWidget {
  final FxSettings settings;
  final void Function(FxSettings next, {required bool commit}) onChanged;

  const _EchoCard({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _EffectCard(
      title: 'Echo',
      subtitle: 'Repeating delay, each repeat quieter',
      on: settings.echoOn,
      onToggle: (v) => onChanged(settings.copyWith(echoOn: v), commit: true),
      body: Column(
        children: [
          _FxSlider(
            label: 'Delay',
            valueLabel: '${settings.echoDelayMs.round()} ms',
            value: settings.echoDelayMs,
            min: 50,
            max: 800,
            onChanged: (v) =>
                onChanged(settings.copyWith(echoDelayMs: v), commit: false),
            onChangeEnd: (v) =>
                onChanged(settings.copyWith(echoDelayMs: v), commit: true),
          ),
          _FxSlider(
            label: 'Feedback',
            valueLabel: '${(settings.echoFeedback * 100).round()}%',
            value: settings.echoFeedback,
            min: 0,
            max: 0.9,
            onChanged: (v) =>
                onChanged(settings.copyWith(echoFeedback: v), commit: false),
            onChangeEnd: (v) =>
                onChanged(settings.copyWith(echoFeedback: v), commit: true),
          ),
          _FxSlider(
            label: 'Mix',
            valueLabel: '${(settings.echoMix * 100).round()}%',
            value: settings.echoMix,
            min: 0,
            max: 1,
            onChanged: (v) =>
                onChanged(settings.copyWith(echoMix: v), commit: false),
            onChangeEnd: (v) =>
                onChanged(settings.copyWith(echoMix: v), commit: true),
          ),
        ],
      ),
    );
  }
}

class _ReverbCard extends StatelessWidget {
  final FxSettings settings;
  final void Function(FxSettings next, {required bool commit}) onChanged;

  const _ReverbCard({required this.settings, required this.onChanged});

  String _roomLabel(double s) {
    if (s < 0.8) return 'Small room';
    if (s < 1.6) return 'Medium room';
    if (s < 2.3) return 'Large room';
    return 'Hall';
  }

  @override
  Widget build(BuildContext context) {
    return _EffectCard(
      title: 'Reverb',
      subtitle: 'Sense of a physical space',
      on: settings.reverbOn,
      onToggle: (v) => onChanged(settings.copyWith(reverbOn: v), commit: true),
      body: Column(
        children: [
          _FxSlider(
            label: 'Room size',
            valueLabel:
                '${_roomLabel(settings.reverbDecayS)} · ${settings.reverbDecayS.toStringAsFixed(1)}s',
            value: settings.reverbDecayS,
            min: 0.4,
            max: 3.0,
            onChanged: (v) =>
                onChanged(settings.copyWith(reverbDecayS: v), commit: false),
            onChangeEnd: (v) =>
                onChanged(settings.copyWith(reverbDecayS: v), commit: true),
          ),
          _FxSlider(
            label: 'Mix',
            valueLabel: '${(settings.reverbMix * 100).round()}%',
            value: settings.reverbMix,
            min: 0,
            max: 1,
            onChanged: (v) =>
                onChanged(settings.copyWith(reverbMix: v), commit: false),
            onChangeEnd: (v) =>
                onChanged(settings.copyWith(reverbMix: v), commit: true),
          ),
          _FxSlider(
            label: 'Pre-delay',
            valueLabel: '${settings.reverbPreDelayMs.round()} ms',
            value: settings.reverbPreDelayMs,
            min: 0,
            max: 100,
            onChanged: (v) => onChanged(
              settings.copyWith(reverbPreDelayMs: v),
              commit: false,
            ),
            onChangeEnd: (v) =>
                onChanged(settings.copyWith(reverbPreDelayMs: v), commit: true),
          ),
          _FxSlider(
            label: 'Damping',
            valueLabel: '${(settings.reverbDamping * 100).round()}%',
            value: settings.reverbDamping,
            min: 0,
            max: 1,
            onChanged: (v) =>
                onChanged(settings.copyWith(reverbDamping: v), commit: false),
            onChangeEnd: (v) =>
                onChanged(settings.copyWith(reverbDamping: v), commit: true),
          ),
        ],
      ),
    );
  }
}

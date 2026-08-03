// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flatch/common/services/audio_fx.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/waveform_view.dart';
import 'package:flatch/cubits/audio_trim/audio_trim_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/widgets/audio_service.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toastification/toastification.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final String fileName;
  final AudioService audioService;
  final void Function(String newPath, Duration newDuration) onTrimmed;

  /// Called after an effect is baked into the clip, with the new file path.
  final void Function(String newPath)? onProcessed;

  /// Initial crop selection (seconds) to restore. When null (or end <= 0) the
  /// clip opens un-cropped (0..min(15, total)). Used to preserve the user's
  /// crop across effect changes and navigation.
  final double? initialTrimStart;
  final double? initialTrimEnd;

  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.audioService,
    required this.onTrimmed,
    this.onProcessed,
    this.initialTrimStart,
    this.initialTrimEnd,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Duration? _duration;
  Duration? _position;
  bool _isPlaying = false;
  List<double> _wave = const [];

  @override
  void initState() {
    super.initState();
    _initAudio();
    _setupListeners();
    _loadWaveform();
  }

  Future<void> _loadWaveform() async {
    final w = await AudioFx.waveform(widget.filePath);
    if (mounted) setState(() => _wave = w);
  }

  Future<void> _initAudio() async {
    await widget.audioService.loadAudio(widget.filePath);
    final d = widget.audioService.duration;
    if (d == null || d.inMilliseconds <= 0) {
      showToast(
        context: context,
        message: "Error: Could not load audio duration.",
        type: ToastificationType.error,
      );
      return;
    }
    final total = d.inMilliseconds / 1000.0;
    final defaultEnd = total > 15.0 ? 15.0 : total;
    // Restore a saved crop if one was passed in; otherwise open un-cropped.
    final start = (widget.initialTrimStart ?? 0.0).clamp(0.0, total);
    final rawEnd =
        (widget.initialTrimEnd != null && widget.initialTrimEnd! > 0)
            ? widget.initialTrimEnd!
            : defaultEnd;
    final end = rawEnd.clamp(start, total);
    context.read<AudioTrimCubit>().initialize(
      originalPath: widget.filePath,
      trimStart: start,
      trimEnd: end,
    );
    setState(() {
      _duration = d;
      _position = Duration.zero;
      _isPlaying = false;
    });
  }

  void _setupListeners() {
    widget.audioService.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);

      final trimEnd = context.read<AudioTrimCubit>().state.trimEnd;
      if (_duration != null &&
          position.inMilliseconds >= (trimEnd * 1000).toInt() - 100) {
        _onPlaybackComplete();
      }
    });
    widget.audioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    widget.audioService.playingStream.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });
  }

  void _onPlaybackComplete() async {
    await widget.audioService.seek(Duration.zero);
    await widget.audioService.pause();

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioTrimCubit, AudioTrimState>(
      builder: (context, state) {
        final duration = _duration;

        final totalSecs = (duration?.inMilliseconds ?? 1000) / 1000.0;
        final trimStart = state.trimStart.clamp(0.0, totalSecs);
        final trimEnd = state.trimEnd.clamp(0.0, totalSecs);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.audiotrack_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sound Clip',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Audio File',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Waveform of the clip, above the trim/seek bar.
                if (_wave.isNotEmpty &&
                    duration != null &&
                    totalSecs > 0.0) ...[
                  WaveformView(
                    amplitudes: _wave,
                    height: 46,
                    progress:
                        (_position?.inMilliseconds ?? 0) / (totalSecs * 1000),
                  ),
                  const SizedBox(height: 8),
                ],

                // One combined track: crop handles on each side + a live
                // playback cursor showing where we are in the clip.
                if (duration != null && totalSecs > 0.0)
                  _TrimSeekBar(
                    totalSecs: totalSecs,
                    trimStart: trimStart,
                    trimEnd: trimEnd,
                    positionSecs: (_position?.inMilliseconds ?? 0) / 1000.0,
                    onScrubStart: () {
                      if (_isPlaying) {
                        widget.audioService.pause();
                        setState(() => _isPlaying = false);
                      }
                    },
                    onCropChanged: (start, end) {
                      context.read<AudioTrimCubit>().updateTrim(start, end);
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          style: ButtonStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                          ),
                          iconSize: 32,
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                          ),
                          onPressed: () async {
                            if (_isPlaying) {
                              widget.audioService.pause();
                            } else {
                              final trimStart =
                                  context
                                      .read<AudioTrimCubit>()
                                      .state
                                      .trimStart;
                              await widget.audioService.seek(
                                Duration(
                                  milliseconds: (trimStart * 1000).toInt(),
                                ),
                              );
                              widget.audioService.play();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (state.error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One combined track: a grey clip track with a green selected region between
/// two draggable crop handles, plus a live playback cursor showing where we are
/// in the clip. Crop is committed on drag-end (via [onCropChanged]); the 15s
/// max window and a small minimum window are enforced while dragging.
class _TrimSeekBar extends StatefulWidget {
  final double totalSecs;
  final double trimStart;
  final double trimEnd;
  final double positionSecs;
  final VoidCallback onScrubStart;
  final void Function(double start, double end) onCropChanged;

  const _TrimSeekBar({
    required this.totalSecs,
    required this.trimStart,
    required this.trimEnd,
    required this.positionSecs,
    required this.onScrubStart,
    required this.onCropChanged,
  });

  @override
  State<_TrimSeekBar> createState() => _TrimSeekBarState();
}

class _TrimSeekBarState extends State<_TrimSeekBar> {
  static const double _handleW = 14;
  static const double _touchW = 36;
  static const double _handleH = 30;
  static const double _trackH = 6;
  static const double _activeH = 10;
  static const double _cursorW = 3;
  static const double _cursorH = 34;
  static const double _rowH = 40;
  static const double _maxWindow = 15.0;
  static const double _minWindow = 0.15;

  // Live values while a handle is being dragged (committed on drag end).
  double? _dragStart;
  double? _dragEnd;

  double get _effStart => _dragStart ?? widget.trimStart;
  double get _effEnd => _dragEnd ?? widget.trimEnd;

  String _fmt(double secs) {
    final d = Duration(milliseconds: (secs * 1000).round());
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  TextStyle get _lbl => TextStyle(
    color: Colors.grey[600],
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  Widget _handle() => Center(
    child: Container(
      width: _handleW,
      height: _handleH,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final total = widget.totalSecs <= 0 ? 1.0 : widget.totalSecs;
    final cursorColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final usable = (w - _handleW) <= 0 ? 1.0 : (w - _handleW);
            double xCenter(double v) =>
                (v / total).clamp(0.0, 1.0) * usable + _handleW / 2;

            final startX = xCenter(_effStart);
            final endX = xCenter(_effEnd);
            final posX = xCenter(widget.positionSecs.clamp(0.0, total));
            final mid = _rowH / 2;

            void onLeftDrag(DragUpdateDetails d) {
              final deltaV = (d.delta.dx / usable) * total;
              var s = _effStart + deltaV;
              s = s.clamp(0.0, _effEnd - _minWindow);
              if (_effEnd - s > _maxWindow) s = _effEnd - _maxWindow;
              setState(() => _dragStart = s.clamp(0.0, total));
            }

            void onRightDrag(DragUpdateDetails d) {
              final deltaV = (d.delta.dx / usable) * total;
              var e = _effEnd + deltaV;
              e = e.clamp(_effStart + _minWindow, total);
              if (e - _effStart > _maxWindow) e = _effStart + _maxWindow;
              setState(() => _dragEnd = e.clamp(0.0, total));
            }

            return SizedBox(
              height: _rowH,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // base (inactive) track
                  Positioned(
                    left: _handleW / 2,
                    right: _handleW / 2,
                    top: mid - _trackH / 2,
                    child: Container(
                      height: _trackH,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // selected (crop) region
                  Positioned(
                    left: startX,
                    width: (endX - startX) <= 0 ? 0.0 : (endX - startX),
                    top: mid - _activeH / 2,
                    child: Container(
                      height: _activeH,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // playback cursor
                  Positioned(
                    left: posX - _cursorW / 2,
                    top: mid - _cursorH / 2,
                    child: Container(
                      width: _cursorW,
                      height: _cursorH,
                      decoration: BoxDecoration(
                        color: cursorColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // left crop handle
                  Positioned(
                    left: startX - _touchW / 2,
                    top: mid - _handleH / 2,
                    width: _touchW,
                    height: _handleH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) => widget.onScrubStart(),
                      onHorizontalDragUpdate: onLeftDrag,
                      onHorizontalDragEnd: (_) {
                        widget.onCropChanged(_effStart, _effEnd);
                        setState(() => _dragStart = null);
                      },
                      child: _handle(),
                    ),
                  ),
                  // right crop handle
                  Positioned(
                    left: endX - _touchW / 2,
                    top: mid - _handleH / 2,
                    width: _touchW,
                    height: _handleH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) => widget.onScrubStart(),
                      onHorizontalDragUpdate: onRightDrag,
                      onHorizontalDragEnd: (_) {
                        widget.onCropChanged(_effStart, _effEnd);
                        setState(() => _dragEnd = null);
                      },
                      child: _handle(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_effStart), style: _lbl),
              Text(
                '${_fmt(widget.positionSecs.clamp(0.0, total))} / ${_fmt(total)}',
                style: _lbl,
              ),
              Text(_fmt(_effEnd), style: _lbl),
            ],
          ),
        ),
      ],
    );
  }
}

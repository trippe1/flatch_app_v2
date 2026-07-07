// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/cubits/audio_trim/audio_trim_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:flatch/common/widgets/audio_service.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toastification/toastification.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final String fileName;
  final AudioService audioService;
  final void Function(String newPath, Duration newDuration) onTrimmed;

  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.audioService,
    required this.onTrimmed,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Duration? _duration;
  Duration? _position;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _setupListeners();
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
    context.read<AudioTrimCubit>().initialize(
      originalPath: widget.filePath,
      trimStart: 0.0,
      trimEnd: total > 15.0 ? 15.0 : total,
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

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioTrimCubit, AudioTrimState>(
      builder: (context, state) {
        final duration = _duration;

        final totalSecs = (duration?.inMilliseconds ?? 1000) / 1000.0;
        final trimStart = state.trimStart.clamp(0.0, totalSecs);
        final trimEnd = state.trimEnd.clamp(0.0, totalSecs);
        final selectedStart = Duration(
          milliseconds: (trimStart * 1000).toInt(),
        );
        final selectedEnd = Duration(milliseconds: (trimEnd * 1000).toInt());

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

                if (duration != null && totalSecs > 0.0) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).cardColor,
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: FlutterSlider(
                            values: [trimStart, trimEnd],
                            min: 0,
                            max: totalSecs,
                            rangeSlider: true,
                            step: const FlutterSliderStep(step: 0.1),
                            trackBar: FlutterSliderTrackBar(
                              inactiveTrackBar: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              activeTrackBar: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              inactiveTrackBarHeight: 6,
                              activeTrackBarHeight: 14,
                            ),
                            handler: FlutterSliderHandler(
                              decoration: const BoxDecoration(),
                              child: Container(
                                width: 10,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            rightHandler: FlutterSliderHandler(
                              decoration: const BoxDecoration(),
                              child: Container(
                                width: 10,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            onDragging: (handlerIndex, lowerValue, upperValue) {
                              if (_isPlaying) {
                                widget.audioService.pause();
                                setState(() {
                                  _isPlaying = false;
                                });
                              }
                            },
                            onDragCompleted: (
                              handlerIndex,
                              lowerValue,
                              upperValue,
                            ) {
                              final maxDuration = 15.0;
                              final total = totalSecs;
                              double start = lowerValue.clamp(0.0, total);
                              double end = upperValue.clamp(0.0, total);

                              // Limit selection to maxDuration
                              if ((end - start) > maxDuration) {
                                if (handlerIndex == 0) {
                                  end = start + maxDuration;
                                } else {
                                  start = end - maxDuration;
                                }
                              }

                              // Ensure minimum selection window
                              if ((end - start) < 0.15) {
                                end = start + 0.15;
                              }

                              // Final clamp to avoid exceeding max
                              start = start.clamp(0.0, total);
                              end = end.clamp(0.0, total);

                              context.read<AudioTrimCubit>().updateTrim(
                                start,
                                end,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(selectedStart),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDuration(selectedEnd),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
                const SizedBox(height: 24),

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

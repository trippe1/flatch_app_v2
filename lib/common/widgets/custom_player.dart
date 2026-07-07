import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';

class AudioTrimSlider extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function() onPlayPause;
  final Function(Duration) onSeek;
  final Function(double start, double end) onTrimChanged;

  const AudioTrimSlider({
    super.key,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    required this.onTrimChanged,
  });

  @override
  State<AudioTrimSlider> createState() => _AudioTrimSliderState();
}

class _AudioTrimSliderState extends State<AudioTrimSlider> {
  late double _rangeStart;
  late double _rangeEnd;

  @override
  void initState() {
    super.initState();
    final totalSec = widget.duration.inSeconds.toDouble();
    _rangeStart = 0.0;
    _rangeEnd = totalSec > 0 ? totalSec : 1.0; // avoid NaN
  }

  @override
  Widget build(BuildContext context) {
    final totalSec = widget.duration.inSeconds.toDouble();
    final clampedTotal = totalSec > 0 ? totalSec : 1.0; // fallback

    return Column(
      children: [
        // --- Player controls ---
        Row(
          children: [
            IconButton(
              icon: Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.teal,
              ),
              onPressed: widget.onPlayPause,
            ),
            Text(
              "${_formatDuration(widget.position)} / ${_formatDuration(widget.duration)}",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // --- Trim & Seek Slider ---
        FlutterSlider(
          values: [_rangeStart, _rangeEnd],
          rangeSlider: true,
          min: 0,
          max: clampedTotal,
          step: const FlutterSliderStep(step: 1),

          // Track styling
          trackBar: FlutterSliderTrackBar(
            inactiveTrackBar: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            activeTrackBar: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            inactiveTrackBarHeight: 6,
            activeTrackBarHeight: 16,
          ),

          // Left handle
          handler: FlutterSliderHandler(
            decoration: const BoxDecoration(),
            child: Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Right handle
          rightHandler: FlutterSliderHandler(
            decoration: const BoxDecoration(),
            child: Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // --- User dragging ---
          onDragging: (handlerIndex, lowerValue, upperValue) {
            setState(() {
              if (handlerIndex == 0) {
                _rangeStart = lowerValue;
              } else if (handlerIndex == 1) {
                _rangeEnd = upperValue;
              }
            });
          },

          // --- Drag complete (trim update + seek) ---
          onDragCompleted: (handlerIndex, lowerValue, upperValue) {
            setState(() {
              _rangeStart = lowerValue;
              _rangeEnd = upperValue;
            });

            // If user drags inside trim area, seek playback
            if (handlerIndex == 0 || handlerIndex == 1) {
              widget.onTrimChanged(_rangeStart, _rangeEnd);
            } else {
              widget.onSeek(Duration(seconds: lowerValue.toInt()));
            }
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}

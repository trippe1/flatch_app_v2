import 'dart:math';
import 'package:flutter/material.dart';

class TrimSlider extends StatefulWidget {
  final Duration total;
  final ValueChanged<DurationRange> onChanged;

  const TrimSlider({super.key, required this.total, required this.onChanged});

  @override
  State<TrimSlider> createState() => _TrimSliderState();
}

class _TrimSliderState extends State<TrimSlider> {
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    final totalMs = widget.total.inMilliseconds;
    final defaultStart = 0.0;
    final defaultEnd = min(5000.0, totalMs.toDouble());

    _range = RangeValues(defaultStart, defaultEnd);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.total.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select clip range', style: TextStyle(fontSize: 14)),
        RangeSlider(
          values: _range,
          min: 0,
          max: totalMs.toDouble(),
          divisions: totalMs ~/ 100,
          labels: RangeLabels(
            '${Duration(milliseconds: _range.start.round()).inSeconds}s',
            '${Duration(milliseconds: _range.end.round()).inSeconds}s',
          ),
          onChanged: (v) {
            setState(() => _range = v);
            widget.onChanged(
              DurationRange(
                start: Duration(milliseconds: _range.start.round()),
                end: Duration(milliseconds: _range.end.round()),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Custom class to represent duration range
class DurationRange {
  final Duration start;
  final Duration end;

  DurationRange({required this.start, required this.end});
}

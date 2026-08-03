// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/services/age_gate_service.dart';
import 'package:flatch/common/widgets/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderWidget extends StatefulWidget {
  final AudioService audioService;
  final Function(String path, String fileName, String fileType, Duration?)
  onRecordingComplete;

  const AudioRecorderWidget({
    super.key,
    required this.audioService,
    required this.onRecordingComplete,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with TickerProviderStateMixin {
  // Timing
  static const int kMaxCentis = 1500;
  static const Duration kTick = Duration(milliseconds: 100);

  // State
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordCentis = 0;
  int? _segmentStartCentis;
  final List<_Clip> _clips = [];

  late final AnimationController _growCtrl;
  late final Animation<double> _growAnim;

  Timer? _timer;
  double _level = 0.0;
  StreamSubscription<double>? _levelSub;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  static const MethodChannel _recorderChannel = MethodChannel('audio.recorder');

  @override
  void initState() {
    super.initState();
    _growCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _growAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _growCtrl, curve: Curves.easeOutCubic));
    _initRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levelSub?.cancel();
    _growCtrl.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    // COPPA: never request the mic on an age-blocked device.
    if (await AgeGateService.instance.isBlocked()) return;
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      await _recorder.openRecorder();
      debugPrint('🎤 Microphone session initialized');
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  void _startTicker({bool reset = false}) {
    if (reset) _recordCentis = 0;
    _timer?.cancel();
    _timer = Timer.periodic(kTick, (_) {
      if (!mounted || !_isRecording || _isPaused) return;
      setState(() {
        _recordCentis = (_recordCentis + 10).clamp(0, kMaxCentis);
        // _level is driven by the real mic amplitude stream (see _start).
      });

      if (_recordCentis >= kMaxCentis) {
        _autoCloseClipAndPause();
      }
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  String _fmt(int centis) {
    final seconds = centis / 100.0;
    return seconds.toStringAsFixed(1);
  }

  Future<void> _start() async {
    if (!_isRecording && !_isPaused) {
      _growCtrl.forward();
    }

    await _initRecorder();
    final success = await widget.audioService.startRecording(context);
    if (success) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _segmentStartCentis = _recordCentis;
      });
      _startTicker();
      // Drive the wheel pulse from the real microphone level.
      _levelSub?.cancel();
      _levelSub = widget.audioService.recordingLevelStream.listen((lvl) {
        if (mounted && _isRecording && !_isPaused) {
          setState(() => _level = lvl);
        }
      });
    }
  }

  Future<void> _pause() async {
    await widget.audioService.pauseRecording();
    _closeClipAtCurrent();
    setState(() {
      _isPaused = true;
      _level = 0.0;
    });
    _stopTicker();
  }

  Future<void> _resume() async {
    await widget.audioService.resumeRecording();
    setState(() {
      _isPaused = false;
      _segmentStartCentis = _recordCentis;
    });
    _startTicker();
  }

  Future<void> _finalize() async {
    final result = await widget.audioService.stopRecording();

    _stopTicker();
    _levelSub?.cancel();
    _levelSub = null;
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _level = 0.0;
    });

    if (result != null) {
      var duration = result['duration'] as Duration?;
      duration ??= await _getDuration(result['path'] as String);

      widget.onRecordingComplete(
        result['path'] as String,
        result['fileName'] as String,
        result['fileType'] as String,
        duration,
      );
    }

    // Reset UI
    setState(() {
      _clips.clear();
      _recordCentis = 0;
      _segmentStartCentis = null;
      _growCtrl.reset();
    });
  }

  Future<void> _discardLastClip() async {
    if (_clips.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Clip'),
            content: const Text(
              'Are you sure you want to delete the last recorded clip?',
            ),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _recorderChannel.invokeMethod<void>('discardLastClip');
    } catch (_) {}

    final last = _clips.removeLast();
    setState(() {
      _recordCentis = last.start;
      _segmentStartCentis = _isPaused ? null : _recordCentis;
    });
  }

  Future<void> _discardAll() async {
    if (_recordCentis == 0 && _clips.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Discard All?'),
            content: const Text(
              'Are you sure you want to delete all recordings and clips?',
            ),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _recorderChannel.invokeMethod<void>('discardAllClips');
    } catch (_) {}

    _levelSub?.cancel();
    _levelSub = null;
    setState(() {
      _clips.clear();
      _recordCentis = 0;
      _segmentStartCentis = null;
      _isPaused = false;
      _isRecording = false;
      _level = 0.0;
      _growCtrl.reset();
    });

    await widget.audioService.stopRecording();
  }

  void _closeClipAtCurrent() {
    if (_segmentStartCentis == null) return;
    final start = _segmentStartCentis!;
    final end = _recordCentis;
    if (end > start) {
      _clips.add(_Clip(start: start, end: end));
    }
    _segmentStartCentis = null;
  }

  void _autoCloseClipAndPause() {
    _closeClipAtCurrent();
    setState(() => _isPaused = true);
    _stopTicker();
  }

  Future<Duration?> _getDuration(String path) async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(path);
      final d = player.duration;
      await player.dispose();
      return d;
    } catch (e) {
      debugPrint('⛔ Error getting duration: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIdle = !_isRecording && !_isPaused && _recordCentis == 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isPaused
                      ? Icons.pause_circle_filled
                      : (_isRecording
                          ? Icons.fiber_manual_record
                          : Icons.mic_none_rounded),
                  color:
                      _isPaused
                          ? Colors.amber
                          : (_isRecording
                              ? Colors.red
                              : theme.colorScheme.primary),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isPaused ? 'Paused' : (_isRecording ? 'Recording' : 'Ready'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        _isPaused
                            ? Colors.amber[800]
                            : (_isRecording
                                ? Colors.red[800]
                                : theme.colorScheme.primary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_recordCentis != 0.0)
              Text(
                _fmt(_recordCentis),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.5,
                ),
              ),

            const SizedBox(height: 12),

            Center(
              child: AnimatedBuilder(
                animation: _growAnim,
                builder: (context, child) {
                  return Transform.scale(
                    scale: (isIdle ? 1.0 : _growAnim.value),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () async {
                    if (!_isRecording && !_isPaused) {
                      await _start();
                    } else if (_isRecording && !_isPaused) {
                      await _pause();
                    } else if (_isPaused && _recordCentis < kMaxCentis) {
                      await _resume();
                    }
                  },

                  child: CustomPaint(
                    painter: _WheelerPainter(
                      progress: _recordCentis / kMaxCentis,
                      clips: _clips,
                      maxCentis: kMaxCentis,
                      isRecording: _isRecording && !_isPaused,
                      level: _level,
                    ),
                    child: Container(
                      width: 200,
                      height: 200,
                      alignment: Alignment.center,
                      child: _CenterButton(
                        isRecording: _isRecording,
                        isPaused: _isPaused,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: [
                if (_clips.isNotEmpty)
                  _ActionButton(
                    icon: Icons.undo_rounded,
                    label: 'Discard Last',
                    color: Colors.orange,
                    onTap: _discardLastClip,
                  ),
                if (_clips.isNotEmpty || _recordCentis > 0)
                  _ActionButton(
                    icon: Icons.delete_forever_rounded,
                    label: 'Discard All',
                    color: Colors.red,
                    onTap: _discardAll,
                  ),
                if (_recordCentis > 0)
                  _ActionButton(
                    icon: Icons.check_rounded,
                    label: 'Finalize',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: _finalize,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helpers / UI parts ---
class _CenterButton extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;

  const _CenterButton({required this.isRecording, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    Widget inner;

    if (!isRecording && !isPaused) {
      // Idle → big outlined circle
      inner = Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primary, width: 6),
        ),
      );
    } else if (isRecording && !isPaused) {
      // Recording → small solid circle
      inner = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
      );
    } else {
      // Paused → big solid circle
      inner = Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
      );
    }

    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withOpacity(0.08),
        border: Border.all(color: primary.withOpacity(0.25)),
      ),
      child: inner,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withOpacity(0.08),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 28, color: color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Clip {
  final int start;
  final int end;

  _Clip({required this.start, required this.end});
}

class _WheelerPainter extends CustomPainter {
  final double progress;
  final List<_Clip> clips;
  final int maxCentis;
  final bool isRecording;
  final double level;

  _WheelerPainter({
    required this.progress,
    required this.clips,
    required this.maxCentis,
    required this.isRecording,
    required this.level,
  });

  // Convert centiseconds to radians
  double _toRad(int centis) => -pi / 2 + 2 * pi * (centis / maxCentis);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final progressStroke = 9.0;

    // Adjust radius to center strokes properly
    final radius = min(size.width, size.height) / 2 - progressStroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Paints
    final basePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0x22000000);

    final clipPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = progressStroke
          ..color = AppColors.primary;

    final progressPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = progressStroke
          ..color = AppColors.primary;

    final markerPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFFFFF);

    // 1️⃣ Base grey ring
    canvas.drawCircle(center, radius, basePaint);

    // 2️⃣ Green clip arcs + markers
    for (final c in clips) {
      final start = _toRad(c.start);
      final sweep = _toRad(c.end) - start;
      if (sweep > 0) {
        canvas.drawArc(rect, start, sweep, false, clipPaint);
      }

      // Draw white markers as small circles
      _drawMarker(canvas, center, radius, start, markerPaint);
      _drawMarker(canvas, center, radius, _toRad(c.end), markerPaint);
    }

    // 3️⃣ Blue progress arc
    final endProgress = (progress * maxCentis).round();
    if (endProgress > 0) {
      canvas.drawArc(
        rect,
        _toRad(0),
        _toRad(endProgress) - _toRad(0),
        false,
        progressPaint,
      );
    }
  }

  void _drawMarker(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Paint paint,
  ) {
    final markerRadius = 5.0;
    final offset = 3.0;
    final x = center.dx + (radius + offset) * cos(angle);
    final y = center.dy + (radius + offset) * sin(angle);
    canvas.drawCircle(Offset(x, y), markerRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _WheelerPainter old) =>
      progress != old.progress ||
      clips.length != old.clips.length ||
      isRecording != old.isRecording ||
      level != old.level;
}

class VideoToAudioWidget extends StatefulWidget {
  final void Function(String path, String name, String type, Duration? duration)
  onAudioExtracted;

  /// When true, the Photos picker opens automatically on mount (i.e. as soon as
  /// the user selects the "Upload from Photos" tile).
  final bool autoStart;

  const VideoToAudioWidget({
    super.key,
    required this.onAudioExtracted,
    this.autoStart = false,
  });

  @override
  State<VideoToAudioWidget> createState() => _VideoToAudioWidgetState();
}

class _VideoToAudioWidgetState extends State<VideoToAudioWidget> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickVideoAndExtractAudio();
      });
    }
  }

  Future<void> _pickVideoAndExtractAudio() async {
    try {
      // Ask for Photos access ONLY here — when the user is actually picking a
      // video to upload from their library (never at app startup).
      if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted && !status.isLimited) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photos access is needed to pick a video.'),
              ),
            );
          }
          return;
        }
      }
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      if (result != null && result.files.single.path != null) {
        setState(() => _isProcessing = true);

        const channel = MethodChannel("audio.converter");
        final inputPath = result.files.single.path!;

        final tempDir = await getTemporaryDirectory();
        final outputPath = p.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.mp3',
        );

        final String? mp3Path = await channel.invokeMethod("convertToMp3", {
          "inputPath": inputPath,
          "outputPath": outputPath,
        });

        if (mp3Path != null && File(mp3Path).existsSync()) {
          final fileName = mp3Path.split('/').last;
          final duration = await _getDuration(mp3Path);

          widget.onAudioExtracted(mp3Path, fileName, "mp3", duration);
        }
      }
    } catch (e) {
      debugPrint("Error extracting audio: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<Duration?> _getDuration(String path) async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(path);
      final duration = player.duration;
      await player.dispose();
      return duration;
    } catch (e) {
      debugPrint("Error getting duration: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.video_file),
      label: Text(_isProcessing ? "Processing..." : "Convert Video to Audio"),
      onPressed: _isProcessing ? null : _pickVideoAndExtractAudio,
    );
  }
}

class AudioPickerWidget extends StatefulWidget {
  final void Function(String path, String name, String type, Duration? duration)
  onAudioSelected;

  /// When true, the Files picker opens automatically on mount (i.e. as soon as
  /// the user selects the "Upload from Files" tile).
  final bool autoStart;

  const AudioPickerWidget({
    super.key,
    required this.onAudioSelected,
    this.autoStart = false,
  });

  @override
  State<AudioPickerWidget> createState() => _AudioPickerWidgetState();
}

class _AudioPickerWidgetState extends State<AudioPickerWidget> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickAudio();
      });
    }
  }

  Future<void> _pickAudio() async {
    try {
      setState(() => _isLoading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final fileName = result.files.single.name;
        final fileType = fileName.split('.').last;

        final duration = await _getDuration(path);
        widget.onAudioSelected(path, fileName, fileType, duration);
      }
    } catch (e) {
      debugPrint("Audio pick error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Duration?> _getDuration(String path) async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(path);
      final duration = player.duration;
      await player.dispose();
      return duration;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.library_music),
      label: Text(_isLoading ? "Loading..." : "Pick Audio File"),
      onPressed: _isLoading ? null : _pickAudio,
    );
  }
}

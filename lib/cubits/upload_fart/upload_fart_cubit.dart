import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_audio_output/flutter_audio_output.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

part 'upload_fart_state.dart';

class UploadFartCubit extends Cubit<UploadFartState> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;

  UploadFartCubit() : super(const UploadFartState()) {
    _player.playerStateStream.listen((ps) {
      emit(state.copyWith(isPlaying: ps.playing));
    });
    _player.positionStream.listen((pos) {
      emit(state.copyWith(currentPosition: pos));
    });
    _player.durationStream.listen((dur) {
      emit(state.copyWith(audioDuration: dur));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _player.dispose();
    _recorder.closeRecorder();
    return super.close();
  }

  Future<String> _getTempPath(String filename) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$filename';
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final newDuration = state.recordDuration + 1;
      final level = 0.2 + 0.8 * (DateTime.now().millisecond % 100) / 100;
      emit(state.copyWith(recordDuration: newDuration, recordingLevel: level));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  Future<void> selectChoice(String choice) async {
    emit(state.copyWith(uploadChoice: choice, filePath: null));
    if (choice == 'record') {
      await startRecording();
    } else {
      await pickFile(choice == 'audio' ? FileType.audio : FileType.video);
    }
  }

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final path = await _getTempPath(
      'record_${DateTime.now().millisecondsSinceEpoch}.aac',
    );
    await _recorder.openRecorder();
    await _recorder.startRecorder(toFile: path);

    _startTimer();
    emit(
      state.copyWith(
        isRecording: true,
        isPaused: false,
        filePath: null,
        recordDuration: 0,
      ),
    );
  }

  Future<void> pauseRecording() async {
    await _recorder.pauseRecorder();
    _stopTimer();
    emit(state.copyWith(isPaused: true, isRecording: false));
  }

  Future<void> resumeRecording() async {
    await _recorder.resumeRecorder();
    _startTimer();
    emit(state.copyWith(isPaused: false, isRecording: true));
  }

  Future<void> stopRecording() async {
    final path = await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    _stopTimer();
    emit(
      state.copyWith(
        isRecording: false,
        isPaused: false,
        filePath: path,
        recordDuration: state.recordDuration,
      ),
    );
  }

  Future<void> cancelRecording() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    _stopTimer();
    emit(
      state.copyWith(
        isRecording: false,
        isPaused: false,
        filePath: null,
        recordDuration: 0,
      ),
    );
  }

  Future<void> pickFile(FileType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      emit(state.copyWith(filePath: result.files.single.path));
    }
  }

  Future<void> playPause() async {
    final path = state.filePath;
    if (path == null) return;

    if (state.isPlaying) {
      await _player.pause();
    } else {
       await FlutterAudioOutput.changeToSpeaker();
      await _player.setFilePath(path);
      await _player.play();
    }
  }

  void seek(int milliseconds) {
    _player.seek(Duration(milliseconds: milliseconds));
  }
}

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

part 'audio_trim_state.dart';

class AudioTrimCubit extends Cubit<AudioTrimState> {
  AudioTrimCubit() : super(const AudioTrimState());

  void initialize({
    required String originalPath,
    required double trimStart,
    required double trimEnd,
  }) {
    emit(
      state.copyWith(
        originalPath: originalPath,
        trimStart: trimStart,
        trimEnd: trimEnd,
        trimmedPath: null,
        trimmedDuration: null,
        trimming: false,
        error: null,
      ),
    );
  }

  Future<void> updateTrim(double start, double end) async {
    emit(state.copyWith(trimStart: start, trimEnd: end, trimming: true));
    await _trimAudio(start, end);
  }

  Future<void> _trimAudio(double start, double end) async {
    try {
      const channel = MethodChannel('audio.converter');
      final duration = end - start;
      if (duration <= 0.0) throw Exception('Invalid trim range');

      final maxDuration = 15.0;

      final trimmedPath = await channel.invokeMethod<String>('trimAudio', {
        'inputPath': state.originalPath,
        'start': start,
        'duration': duration > maxDuration ? maxDuration : duration,
      });

      if (trimmedPath != null) {
        emit(
          state.copyWith(
            trimmedPath: trimmedPath,
            trimmedDuration: Duration(
              milliseconds:
                  ((duration > maxDuration ? maxDuration : duration) * 1000)
                      .toInt(),
            ),
            trimming: false,
            error: null,
          ),
        );
      } else {
        emit(state.copyWith(trimming: false, error: 'Trim failed'));
      }
    } catch (e) {
      emit(state.copyWith(trimming: false, error: e.toString()));
    }
  }

  void clear() {
    print('Clearing is happening');
    emit(const AudioTrimState());
  }
}

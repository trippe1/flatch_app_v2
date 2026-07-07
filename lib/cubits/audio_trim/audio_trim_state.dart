part of 'audio_trim_cubit.dart';

class AudioTrimState extends Equatable {
  final String originalPath;
  final double trimStart;
  final double trimEnd;
  final String? trimmedPath;
  final Duration? trimmedDuration;
  final bool trimming;
  final String? error;

  const AudioTrimState({
    this.originalPath = '',
    this.trimStart = 0.0,
    this.trimEnd = 0.0,
    this.trimmedPath,
    this.trimmedDuration,
    this.trimming = false,
    this.error,
  });

  AudioTrimState copyWith({
    String? originalPath,
    double? trimStart,
    double? trimEnd,
    String? trimmedPath,
    Duration? trimmedDuration,
    bool? trimming,
    String? error,
  }) {
    return AudioTrimState(
      originalPath: originalPath ?? this.originalPath,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      trimmedPath: trimmedPath ?? this.trimmedPath,
      trimmedDuration: trimmedDuration ?? this.trimmedDuration,
      trimming: trimming ?? this.trimming,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        originalPath,
        trimStart,
        trimEnd,
        trimmedPath,
        trimmedDuration,
        trimming,
        error,
      ];
}

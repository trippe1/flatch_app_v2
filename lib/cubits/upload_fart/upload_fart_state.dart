part of 'upload_fart_cubit.dart';

class UploadFartState extends Equatable {
  final bool isRecording;
  final bool isPaused;
  final String? filePath;
  final String? uploadChoice;
  final int recordDuration;
  final double recordingLevel;
  final bool isPlaying;
  final Duration? audioDuration;
  final Duration? currentPosition;

  const UploadFartState({
    this.isRecording = false,
    this.isPaused = false,
    this.filePath,
    this.uploadChoice,
    this.recordDuration = 0,
    this.recordingLevel = 0.0,
    this.isPlaying = false,
    this.audioDuration,
    this.currentPosition,
  });

  UploadFartState copyWith({
    bool? isRecording,
    bool? isPaused,
    String? filePath,
    String? uploadChoice,
    int? recordDuration,
    double? recordingLevel,
    bool? isPlaying,
    Duration? audioDuration,
    Duration? currentPosition,
  }) {
    return UploadFartState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      filePath: filePath ?? this.filePath,
      uploadChoice: uploadChoice ?? this.uploadChoice,
      recordDuration: recordDuration ?? this.recordDuration,
      recordingLevel: recordingLevel ?? this.recordingLevel,
      isPlaying: isPlaying ?? this.isPlaying,
      audioDuration: audioDuration ?? this.audioDuration,
      currentPosition: currentPosition ?? this.currentPosition,
    );
  }

  @override
  List<Object?> get props => [
    isRecording,
    isPaused,
    filePath,
    uploadChoice,
    recordDuration,
    recordingLevel,
    isPlaying,
    audioDuration,
    currentPosition,
  ];
}

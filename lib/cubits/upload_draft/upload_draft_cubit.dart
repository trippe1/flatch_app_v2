import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flatch/common/services/audio_dsp.dart';

/// The in-progress upload/recording ("draft"). App-scoped so it survives moving
/// between screens without saving. Cleared only on a successful upload or when
/// the user explicitly deletes the draft.
class UploadDraftState extends Equatable {
  final String?
  originalPath; // raw recorded/picked file (effects applied from here)
  final String? workingPath; // original + effects; what plays / uploads
  final String? fileName;
  final int? durationMs;
  final String? uploadChoice; // 'record' | 'audio' | 'video'
  final String title;
  final bool isPublic;

  // Crop selection (seconds). trimEnd <= 0 means "unset" (use the full clip).
  final double trimStart;
  final double trimEnd;

  // Sound-editor effect settings (noise reduction, echo, reverb).
  final FxSettings fx;

  const UploadDraftState({
    this.originalPath,
    this.workingPath,
    this.fileName,
    this.durationMs,
    this.uploadChoice,
    this.title = '',
    this.isPublic = true,
    this.trimStart = 0.0,
    this.trimEnd = 0.0,
    this.fx = const FxSettings(),
  });

  bool get hasDraft => originalPath != null;

  UploadDraftState copyWith({
    String? originalPath,
    String? workingPath,
    String? fileName,
    int? durationMs,
    String? uploadChoice,
    String? title,
    bool? isPublic,
    double? trimStart,
    double? trimEnd,
    FxSettings? fx,
  }) {
    return UploadDraftState(
      originalPath: originalPath ?? this.originalPath,
      workingPath: workingPath ?? this.workingPath,
      fileName: fileName ?? this.fileName,
      durationMs: durationMs ?? this.durationMs,
      uploadChoice: uploadChoice ?? this.uploadChoice,
      title: title ?? this.title,
      isPublic: isPublic ?? this.isPublic,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      fx: fx ?? this.fx,
    );
  }

  @override
  List<Object?> get props => [
    originalPath,
    workingPath,
    fileName,
    durationMs,
    uploadChoice,
    title,
    isPublic,
    trimStart,
    trimEnd,
    fx,
  ];
}

class UploadDraftCubit extends Cubit<UploadDraftState> {
  UploadDraftCubit() : super(const UploadDraftState());

  void setFile({
    required String original,
    required String working,
    String? name,
    int? durationMs,
    String? choice,
  }) {
    emit(
      state.copyWith(
        originalPath: original,
        workingPath: working,
        fileName: name,
        durationMs: durationMs,
        uploadChoice: choice,
      ),
    );
  }

  void setWorking(String path, {int? durationMs}) =>
      emit(state.copyWith(workingPath: path, durationMs: durationMs));

  void setTitle(String t) => emit(state.copyWith(title: t));
  void setPublic(bool p) => emit(state.copyWith(isPublic: p));
  void setTrim(double start, double end) =>
      emit(state.copyWith(trimStart: start, trimEnd: end));

  void setEffects(FxSettings fx) => emit(state.copyWith(fx: fx));

  void clear() => emit(const UploadDraftState());
}

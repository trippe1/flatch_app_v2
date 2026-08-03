part of 'upload_fart_bloc.dart';

final class UploadFartEvent extends Equatable {
  const UploadFartEvent();

  @override
  List<Object> get props => [];
}

final class UploadUserFart extends UploadFartEvent {
  final String title;
  final String fileType;
  final int duration;
  final String filePath;
  final bool isPublic;

  const UploadUserFart({
    required this.title,
    required this.fileType,
    required this.duration,
    required this.filePath,
    required this.isPublic,
  });
}

final class ResetUploadState extends UploadFartEvent {}

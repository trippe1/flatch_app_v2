part of 'upload_fart_bloc.dart';

sealed class UploadFartState extends Equatable {
  const UploadFartState();

  @override
  List<Object> get props => [];
}

final class UploadFartInitial extends UploadFartState {}

final class UploadFartLoading extends UploadFartState {}

final class UploadFartSuccess extends UploadFartState {}

final class UploadFartFailure extends UploadFartState {
  final String error;

  const UploadFartFailure({required this.error});

  @override
  List<Object> get props => [error];
}

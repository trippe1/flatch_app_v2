part of 'updateusername_bloc.dart';

sealed class UpdateusernameState extends Equatable {
  const UpdateusernameState();

  @override
  List<Object> get props => [];
}

final class UpdateusernameInitial extends UpdateusernameState {}

final class UpdateusernameLoading extends UpdateusernameState {}

final class UpdateusernameError extends UpdateusernameState {
  final String error;
  const UpdateusernameError({required this.error});
}

final class UpdateusernameSuccess extends UpdateusernameState {}

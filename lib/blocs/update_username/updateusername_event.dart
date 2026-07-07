part of 'updateusername_bloc.dart';

final class UpdateusernameEvent extends Equatable {
  const UpdateusernameEvent();

  @override
  List<Object> get props => [];
}

final class UpdateUserNameEventPressed extends UpdateusernameEvent {
  final String username;

  const UpdateUserNameEventPressed({required this.username});

  @override
  List<Object> get props => [username];
}

final class RetryEventPressed extends UpdateusernameEvent {}

final class ResetUpdateUserNameState extends UpdateusernameEvent {}

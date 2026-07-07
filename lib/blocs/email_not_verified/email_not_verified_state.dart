part of 'email_not_verified_bloc.dart';

sealed class EmailNotVerifiedState extends Equatable {
  const EmailNotVerifiedState();

  @override
  List<Object> get props => [];
}

final class EmailNotVerifiedInitialState extends EmailNotVerifiedState {}

final class EmailNotVerifiedLoadingState extends EmailNotVerifiedState {}

final class EmailNotVerifiedSuccessState extends EmailNotVerifiedState {}

final class EmailNotVerifiedErrorState extends EmailNotVerifiedState {
  final FirebaseAuthException e;

  const EmailNotVerifiedErrorState({required this.e});

  @override
  List<Object> get props => [e];
}

final class EmailNotVerifiedInvalidEmailState extends EmailNotVerifiedState {}

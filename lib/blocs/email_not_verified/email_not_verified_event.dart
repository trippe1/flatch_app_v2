part of 'email_not_verified_bloc.dart';

sealed class EmailNotVerifiedEvent extends Equatable {
  const EmailNotVerifiedEvent();

  @override
  List<Object> get props => [];
}

final class EmailNotVerifiedVeifyEvent extends EmailNotVerifiedEvent {}

final class EmailNotVerifiedVeifyRetryEvent extends EmailNotVerifiedEvent {
  final String email;

  const EmailNotVerifiedVeifyRetryEvent(this.email);

  @override
  List<Object> get props => [email];
}

final class ResetStateEvent extends EmailNotVerifiedEvent {}

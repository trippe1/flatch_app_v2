part of 'forgot_password_bloc.dart';

sealed class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object> get props => [];
}

final class ForgotPasswordInitial extends ForgotPasswordState {}

final class ForgotPasswordLoading extends ForgotPasswordState {}

/// A real failure (network, rate limit, bad address). [message] is already
/// user-facing — not a raw exception dump.
final class ForgotPasswordError extends ForgotPasswordState {
  final String message;

  const ForgotPasswordError({required this.message});

  @override
  List<Object> get props => [message];
}

/// No Flatch account exists for [email], so no reset email was sent.
final class ForgotPasswordAccountNotFound extends ForgotPasswordState {
  final String email;

  const ForgotPasswordAccountNotFound({required this.email});

  @override
  List<Object> get props => [email];
}

final class ForgotPasswordSuccess extends ForgotPasswordState {}

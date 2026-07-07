part of 'forgot_password_bloc.dart';

sealed class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object> get props => [];
}

final class ForgotPasswordInitial extends ForgotPasswordState {}

final class ForgotPasswordLoading extends ForgotPasswordState {}

final class ForgotPasswordError extends ForgotPasswordState {
  final Object e;

  const ForgotPasswordError({required this.e});
}

final class ForgotPasswordSuccess extends ForgotPasswordState {}

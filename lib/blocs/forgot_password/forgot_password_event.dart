part of 'forgot_password_bloc.dart';

sealed class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();

  @override
  List<Object> get props => [];
}

final class SendCodeEvent extends ForgotPasswordEvent {
  final String email;

  const SendCodeEvent({required this.email});
}

final class ResetStateEvent extends ForgotPasswordEvent {}

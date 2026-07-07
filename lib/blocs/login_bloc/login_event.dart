part of 'login_bloc.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

final class DoLoginEvent extends LoginEvent {
  final String email;
  final String password;
  const DoLoginEvent({required this.email, required this.password});
}

final class DoRetyLoginEvent extends LoginEvent {}

final class ResetStateEvent extends LoginEvent {
  @override
  List<Object> get props => [];
}

class CheckIfAlreadyLoggedInEvent extends LoginEvent {}

final class GoogleLoginEvent extends LoginEvent {
  final String? role;
  const GoogleLoginEvent({this.role});
}

final class AppleLoginEvent extends LoginEvent {
  final String? role;
  const AppleLoginEvent({this.role});
}

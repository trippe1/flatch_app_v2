part of 'login_bloc.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object> get props => [];
}

final class LoginInitialState extends LoginState {}

final class LoginLoadingState extends LoginState {}

final class LoginSuccessState extends LoginState {
  final CustomClaims claims;
  final User user;
  final bool trialExpired;

  const LoginSuccessState({
    required this.claims,
    required this.user,
    required this.trialExpired,
  });
}

final class LoginFailureState extends LoginState {
  final Object error;
  const LoginFailureState(this.error);
   String get message {
    if (error is FirebaseAuthException) {
      return (error as FirebaseAuthException).message ?? error.toString();
    }
    if (error is Exception) {
      return error.toString();
    }
    if (error is String) {
      return error as String;
    }
    return 'An error occurred. Please try again.';
  }
}


final class LoginEmailNotVerifiedState extends LoginState {}

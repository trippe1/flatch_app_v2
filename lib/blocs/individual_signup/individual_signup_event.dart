part of 'individual_signup_bloc.dart';

sealed class IndividualSignupEvent extends Equatable {
  const IndividualSignupEvent();

  @override
  List<Object> get props => [];
}

class IndividualSignupStartedEvent extends IndividualSignupEvent {
  final String email;
  final String password;
  final String name;
  final String role;
  final String? referralCode;
  final String? description;
  final String? state;
  final String? country;

  const IndividualSignupStartedEvent({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.referralCode,
    this.description,
    this.state,
    this.country,
  });
}

class IndividualSignupRetry extends IndividualSignupEvent {}

final class OnUserEnterPasswordEvent extends IndividualSignupEvent {
  final String password;
  const OnUserEnterPasswordEvent({required this.password});
}

final class GoogleLogin extends IndividualSignupEvent {
  final String? role;
  const GoogleLogin({this.role});
}

final class AppleLogin extends IndividualSignupEvent {
  final String? role;
  const AppleLogin({this.role});
}

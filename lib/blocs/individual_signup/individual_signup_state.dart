part of 'individual_signup_bloc.dart';

sealed class IndividualSignupState extends Equatable {
  const IndividualSignupState();

  @override
  List<Object> get props => [];
}

final class IndividualSignupInitial extends IndividualSignupState {
  final bool usedCapitalLetter;
  final bool usedLowerCase;
  final bool eightOfLenght;
  final bool usedNumber;
  final bool usedSpecialCharacter;

  const IndividualSignupInitial({
    this.usedCapitalLetter = false,
    this.usedLowerCase = false,
    this.eightOfLenght = false,
    this.usedNumber = false,
    this.usedSpecialCharacter = false,
  });

  @override
  List<Object> get props => [
    usedCapitalLetter,
    usedLowerCase,
    eightOfLenght,
    usedNumber,
    usedSpecialCharacter,
  ];

  IndividualSignupInitial copyWith({
    bool? usedCapitalLetter,
    bool? usedLowerCase,
    bool? eightOfLenght,
    bool? usedNumber,
    bool? usedSpecialCharacter,
  }) {
    return IndividualSignupInitial(
      usedCapitalLetter: usedCapitalLetter ?? this.usedCapitalLetter,
      usedLowerCase: usedLowerCase ?? this.usedLowerCase,
      eightOfLenght: eightOfLenght ?? this.eightOfLenght,
      usedNumber: usedNumber ?? this.usedNumber,
      usedSpecialCharacter: usedSpecialCharacter ?? this.usedSpecialCharacter,
    );
  }
}

final class IndividualSignupLoading extends IndividualSignupState {}

final class IndividualSignupSuccess extends IndividualSignupState {
  final User user;

  const IndividualSignupSuccess({required this.user});
}

final class IndividualSignupFailure extends IndividualSignupState {
  final FirebaseAuthException exception;
  const IndividualSignupFailure(this.exception);
}

final class IndividualSignupRetryState extends IndividualSignupState {}

final class DashboardSuccessState extends IndividualSignupState {
  final CustomClaims claims;
  final User user;
  final bool trialExpired;

  const DashboardSuccessState({
    required this.claims,
    required this.trialExpired,
    required this.user,
  });
}

final class DashboardErrorState extends IndividualSignupState {
  final String errorMessage;
  const DashboardErrorState({required this.errorMessage});
}

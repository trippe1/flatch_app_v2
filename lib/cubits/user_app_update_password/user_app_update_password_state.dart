part of 'user_app_update_password_cubit.dart';

class UserAppUpdatePasswordState extends Equatable {
  final bool obsecureCurrentPassword;
  final bool obsecureNewPassword;

  const UserAppUpdatePasswordState({
    this.obsecureCurrentPassword = true,
    this.obsecureNewPassword = true,
  });

  @override
  List<Object> get props => [obsecureCurrentPassword, obsecureNewPassword];

  UserAppUpdatePasswordState copyWith({
    bool? obsecureCurrentPassword,
    bool? obsecureNewPassword,
  }) {
    return UserAppUpdatePasswordState(
      obsecureCurrentPassword:
          obsecureCurrentPassword ?? this.obsecureCurrentPassword,
      obsecureNewPassword: obsecureNewPassword ?? this.obsecureNewPassword,
    );
  }
}

class UserAppUpdatePasswordInitial extends PasswordValidationState {
  const UserAppUpdatePasswordInitial()
      : super(
          usedCapitalLetter: false,
          usedLowerCase: false,
          eightOfLength: false,
          usedNumber: false,
          usedSpecialCharacter: false,
          obsecureCurrentPassword: true,
          obsecureNewPassword: true,
        );
}

class UpdateUserAppPasswordErrorState extends UserAppUpdatePasswordState {
  final FirebaseAuthException error;

  const UpdateUserAppPasswordErrorState({
    required this.error,
    super.obsecureCurrentPassword,
    super.obsecureNewPassword,
  });

  @override
  List<Object> get props =>
      [error, obsecureCurrentPassword, obsecureNewPassword];
}

class UpdateUserAppPasswordLoadingState extends UserAppUpdatePasswordState {}

class UpdateUserAppPasswordSuccessState extends UserAppUpdatePasswordState {}

class PasswordValidationState extends UserAppUpdatePasswordState {
  final bool usedCapitalLetter;
  final bool usedLowerCase;
  final bool eightOfLength;
  final bool usedNumber;
  final bool usedSpecialCharacter;

  const PasswordValidationState({
    required this.usedCapitalLetter,
    required this.usedLowerCase,
    required this.eightOfLength,
    required this.usedNumber,
    required this.usedSpecialCharacter,
    super.obsecureCurrentPassword,
    super.obsecureNewPassword,
  });

  @override
  List<Object> get props => [
        usedCapitalLetter,
        usedLowerCase,
        eightOfLength,
        usedNumber,
        usedSpecialCharacter,
        obsecureCurrentPassword,
        obsecureNewPassword,
      ];

  @override
  PasswordValidationState copyWith({
    bool? usedCapitalLetter,
    bool? usedLowerCase,
    bool? eightOfLength,
    bool? usedNumber,
    bool? usedSpecialCharacter,
    bool? obsecureCurrentPassword,
    bool? obsecureNewPassword,
  }) {
    return PasswordValidationState(
      usedCapitalLetter: usedCapitalLetter ?? this.usedCapitalLetter,
      usedLowerCase: usedLowerCase ?? this.usedLowerCase,
      eightOfLength: eightOfLength ?? this.eightOfLength,
      usedNumber: usedNumber ?? this.usedNumber,
      usedSpecialCharacter: usedSpecialCharacter ?? this.usedSpecialCharacter,
      obsecureCurrentPassword:
          obsecureCurrentPassword ?? this.obsecureCurrentPassword,
      obsecureNewPassword: obsecureNewPassword ?? this.obsecureNewPassword,
    );
  }
}

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'user_app_update_password_state.dart';

class UserAppUpdatePasswordCubit extends Cubit<UserAppUpdatePasswordState> {
  UserAppUpdatePasswordCubit() : super(const UserAppUpdatePasswordInitial());

  void unObsecureCurrent(bool value) {
    emit(state.copyWith(obsecureCurrentPassword: value));
  }

  void unObsecureNew(bool value) {
    emit(state.copyWith(obsecureNewPassword: value));
  }

  void onUpdatePassword(String currentPassword, String newPassword) async {
    try {
      emit(UpdateUserAppPasswordLoadingState());
      FirebaseAuth auth = FirebaseAuth.instance;

      await auth.signInWithEmailAndPassword(
        email: auth.currentUser!.email!,
        password: currentPassword,
      );

      await auth.currentUser!.updatePassword(newPassword);
      emit(UpdateUserAppPasswordSuccessState());
    } catch (e) {
      emit(
        UpdateUserAppPasswordErrorState(
          error:
              e is FirebaseAuthException
                  ? e
                  : FirebaseAuthException(code: "unknown_error"),
        ),
      );
    }
  }

  void validatePassword(String password) {
    bool usedCapitalLetter = password.contains(RegExp(r'[A-Z]'));
    bool usedLowerCase = password.contains(RegExp(r'[a-z]'));
    bool eightOfLength = password.length >= 8 && password.length <= 20;
    bool usedNumber = password.contains(RegExp(r'[0-9]'));
    bool usedSpecialCharacter = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    emit(
      PasswordValidationState(
        usedCapitalLetter: usedCapitalLetter,
        usedLowerCase: usedLowerCase,
        eightOfLength: eightOfLength,
        usedNumber: usedNumber,
        usedSpecialCharacter: usedSpecialCharacter,
        obsecureCurrentPassword: state.obsecureCurrentPassword,
        obsecureNewPassword: state.obsecureNewPassword,
      ),
    );
  }

  void onRetry() {
    emit(const UserAppUpdatePasswordInitial()); // Emit the proper initial state
  }
}

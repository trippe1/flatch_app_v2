import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'individual_signup_state.dart';

class IndividualSignupCubit extends Cubit<KIndividualSignupState> {
  IndividualSignupCubit() : super(const KIndividualSignupState());

  void setAgreeToTerms(bool isAgreed) {
    emit(state.copyWith(agreeToTerms: isAgreed));
  }

  void sendMarketingContent(bool allowMarketing) {
    emit(state.copyWith(sendMarketingContent: allowMarketing));
  }

  void haveCompanyCode(bool hasCode) {
    emit(state.copyWith(haveCompanyCode: hasCode));
  }

  void onUnobsecure(bool obsecure) =>
      emit(state.copyWith(obsecurePassword: obsecure));

  void showInsightsToCompany(bool showInsights) {
    emit(state.copyWith(showInsightsToCompany: showInsights));
  }

  void togglePasswordVisibility(bool isVisible) {
    emit(state.copyWith(obsecurePassword: isVisible));
  }

  void onUserEnterPassword(String password) {
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasMinLength = password.length >= 8 && password.length <= 20;
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    emit(
      state.copyWith(
        usedCapitalLetter: hasUppercase,
        eightOfLenght: hasMinLength,
        usedLowerCase: hasLowercase,
        usedNumber: hasNumber,
        usedSpecialCharacter: hasSymbol,
      ),
    );
  }
}

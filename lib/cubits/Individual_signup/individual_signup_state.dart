part of 'individual_signup_cubit.dart';

@immutable
final class KIndividualSignupState extends Equatable {
  final bool agreeToTerms;
  final bool sendMarketingContent;
  final bool haveCompanyCode;
  final bool showInsightsToCompany;
  final bool obsecurePassword;
  final bool usedCapitalLetter;
  final bool usedLowerCase;
  final bool eightOfLenght;
  final bool usedNumber;
  final bool usedSpecialCharacter;

  const KIndividualSignupState({
    this.agreeToTerms = false,
    this.sendMarketingContent = false,
    this.haveCompanyCode = false,
    this.showInsightsToCompany = false,
    this.obsecurePassword = true,
    this.eightOfLenght = false,
    this.usedCapitalLetter = false,
    this.usedLowerCase = false,
    this.usedNumber = false,
    this.usedSpecialCharacter = false,
  });

  KIndividualSignupState copyWith({
    bool? agreeToTerms,
    bool? sendMarketingContent,
    bool? haveCompanyCode,
    bool? showInsightsToCompany,
    bool? obsecurePassword,
    bool? usedCapitalLetter,
    bool? usedLowerCase,
    bool? usedNumber,
    bool? usedSpecialCharacter,
    bool? eightOfLenght,
  }) {
    return KIndividualSignupState(
      agreeToTerms: agreeToTerms ?? this.agreeToTerms,
      sendMarketingContent: sendMarketingContent ?? this.sendMarketingContent,
      haveCompanyCode: haveCompanyCode ?? this.haveCompanyCode,
      showInsightsToCompany:
          showInsightsToCompany ?? this.showInsightsToCompany,
      obsecurePassword: obsecurePassword ?? this.obsecurePassword,
      usedCapitalLetter: usedCapitalLetter ?? this.usedCapitalLetter,
      usedLowerCase: usedLowerCase ?? this.usedLowerCase,
      usedNumber: usedNumber ?? this.usedNumber,
      usedSpecialCharacter: usedSpecialCharacter ?? this.usedSpecialCharacter,
      eightOfLenght: eightOfLenght ?? this.eightOfLenght,
    );
  }

  @override
  List<Object?> get props => [
        agreeToTerms,
        sendMarketingContent,
        haveCompanyCode,
        showInsightsToCompany,
        obsecurePassword,
        usedCapitalLetter,
        usedLowerCase,
        eightOfLenght,
        usedNumber,
        usedSpecialCharacter,
      ];
}

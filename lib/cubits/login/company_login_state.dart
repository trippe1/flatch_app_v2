part of 'company_login_cubit.dart';

final class LoginCubitState extends Equatable {
  final bool isObsecure;
  const LoginCubitState({this.isObsecure = true});

  @override
  List<Object> get props => [isObsecure];

  LoginCubitState copyWith({
    bool? isObsecure,
  }) {
    return LoginCubitState(isObsecure: isObsecure ?? this.isObsecure);
  }
}

final class CompanyLoginCubitInitial extends LoginCubitState {}

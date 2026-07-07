import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'company_login_state.dart';

class LoginCubit extends Cubit<LoginCubitState> {
  LoginCubit() : super(CompanyLoginCubitInitial());

  void onUnobsecure(bool obsecure) =>
      emit(state.copyWith(isObsecure: obsecure));
}

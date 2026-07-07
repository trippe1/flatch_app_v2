import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'forgot_password_event.dart';
part 'forgot_password_state.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  ForgotPasswordBloc() : super(ForgotPasswordInitial()) {
    on<ForgotPasswordEvent>((event, emit) {});

    on<SendCodeEvent>((event, emit) async {
      try {
        emit(ForgotPasswordLoading());
        await FirebaseAuth.instance
            .sendPasswordResetEmail(email: event.email.trim());
        emit(ForgotPasswordSuccess());
      } catch (e) {
        emit(ForgotPasswordError(e: e));
      }
    });
    on<ResetStateEvent>((event, emit) => emit(ForgotPasswordInitial()));
  }
}

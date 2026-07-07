import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'email_not_verified_event.dart';
part 'email_not_verified_state.dart';

class EmailNotVerifiedBloc
    extends Bloc<EmailNotVerifiedEvent, EmailNotVerifiedState> {
  EmailNotVerifiedBloc() : super(EmailNotVerifiedInitialState()) {
    /// Sends the verification email to the currently signed-in user
    on<EmailNotVerifiedVeifyEvent>((event, emit) async {
      try {
        emit(EmailNotVerifiedLoadingState());
        FirebaseAuth auth = FirebaseAuth.instance;
        User? user = auth.currentUser;

        if (user != null) {
          await user.sendEmailVerification();
          emit(EmailNotVerifiedSuccessState());
        } else {
          emit(EmailNotVerifiedInvalidEmailState());
        }
      } catch (e) {
        if (e is FirebaseAuthException) {
          if (e.code == 'too-many-requests') {
            emit(EmailNotVerifiedInvalidEmailState());
          } else {
            emit(EmailNotVerifiedErrorState(e: e));
          }
        } else {
          emit(
            EmailNotVerifiedErrorState(
              e: FirebaseAuthException(code: "unknown-error"),
            ),
          );
        }
      }
    });

    /// Allows the user to update their email and request a new verification email
    on<EmailNotVerifiedVeifyRetryEvent>((event, emit) async {
      try {
        emit(EmailNotVerifiedLoadingState());
        FirebaseAuth auth = FirebaseAuth.instance;
        User? user = auth.currentUser;

        if (user != null) {
          // ignore: deprecated_member_use
          await user.updateEmail(event.email);
          await user.sendEmailVerification();
          emit(EmailNotVerifiedSuccessState());
        } else {
          emit(EmailNotVerifiedInvalidEmailState());
        }
      } catch (e) {
        if (e is FirebaseAuthException) {
          if (e.code == 'too-many-requests') {
            emit(EmailNotVerifiedInvalidEmailState());
          } else {
            emit(EmailNotVerifiedErrorState(e: e));
          }
        } else {
          emit(
            EmailNotVerifiedErrorState(
              e: FirebaseAuthException(code: "unknown-error"),
            ),
          );
        }
      }
    });

    /// Resets the state to the initial state
    on<ResetStateEvent>((event, emit) => emit(EmailNotVerifiedInitialState()));
  }
}

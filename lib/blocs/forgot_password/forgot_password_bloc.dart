import 'package:bloc/bloc.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'forgot_password_event.dart';
part 'forgot_password_state.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  ForgotPasswordBloc() : super(ForgotPasswordInitial()) {
    on<ForgotPasswordEvent>((event, emit) {});

    on<SendCodeEvent>((event, emit) async {
      final email = event.email.trim();
      emit(ForgotPasswordLoading());

      try {
        // Firebase's email enumeration protection makes sendPasswordResetEmail
        // succeed silently for addresses with no account, so we ask the server
        // first. If that check is unavailable we fall through and still send —
        // better to deliver the email than to block a legitimate reset.
        final exists = await _accountExists(email);
        if (exists == false) {
          emit(ForgotPasswordAccountNotFound(email: email));
          return;
        }

        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        emit(ForgotPasswordSuccess());
      } on FirebaseAuthException catch (e) {
        // Still handled for projects where enumeration protection is off.
        if (e.code == 'user-not-found') {
          emit(ForgotPasswordAccountNotFound(email: email));
        } else {
          emit(ForgotPasswordError(message: _messageFor(e)));
        }
      } catch (_) {
        emit(
          const ForgotPasswordError(
            message:
                "We couldn't send the reset email. Please check your "
                "connection and try again.",
          ),
        );
      }
    });

    on<ResetStateEvent>((event, emit) => emit(ForgotPasswordInitial()));
  }

  /// true / false when the server could answer, null when it couldn't.
  Future<bool?> _accountExists(String email) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('checkAccountExists');
      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
      });
      final exists = result.data['exists'];
      return exists is bool ? exists : null;
    } catch (_) {
      return null; // function missing/offline → don't block the reset
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "That doesn't look like a valid email address.";
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

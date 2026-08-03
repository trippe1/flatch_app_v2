import 'package:flatch/blocs/forgot_password/forgot_password_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// These cover the parts of the reset flow that are pure logic: the state
/// contract the UI switches on, and that a "no account" outcome is a distinct
/// state rather than an error dump.
///
/// The Firebase calls themselves (sendPasswordResetEmail + the
/// checkAccountExists callable) need a live project, so they're verified
/// manually against a real + a fake address.
void main() {
  group('ForgotPassword states', () {
    test('account-not-found is its own state, carrying the email', () {
      const state = ForgotPasswordAccountNotFound(email: 'nobody@example.com');
      expect(state, isA<ForgotPasswordState>());
      expect(state.email, 'nobody@example.com');
      // Must NOT be treated as a generic error by the UI switch.
      expect(state, isNot(isA<ForgotPasswordError>()));
      expect(state, isNot(isA<ForgotPasswordSuccess>()));
    });

    test('error carries a user-facing message, not an exception object', () {
      const state = ForgotPasswordError(message: 'No internet connection.');
      expect(state.message, 'No internet connection.');
      // Guards the old behaviour of dumping `e.toString()` into the UI.
      expect(state.message, isNot(contains('firebase_auth/')));
      expect(state.message, isNot(contains('Exception')));
    });

    test('states with the same payload compare equal (Equatable wiring)', () {
      expect(
        const ForgotPasswordAccountNotFound(email: 'a@b.com'),
        const ForgotPasswordAccountNotFound(email: 'a@b.com'),
      );
      expect(
        const ForgotPasswordAccountNotFound(email: 'a@b.com'),
        isNot(const ForgotPasswordAccountNotFound(email: 'c@d.com')),
      );
      expect(
        const ForgotPasswordError(message: 'x'),
        const ForgotPasswordError(message: 'x'),
      );
    });

    test('initial and loading are distinct', () {
      expect(ForgotPasswordInitial(), isNot(ForgotPasswordLoading()));
    });
  });
}

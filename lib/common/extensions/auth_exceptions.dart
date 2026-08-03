import 'package:firebase_auth/firebase_auth.dart';

extension AuthExceptionsHandler on FirebaseAuthException {
  String authError() {
    switch (code) {
      case 'email-already-in-use':
        return "That email is already registered.";
      case 'invalid-email':
        return "That email address is not valid.";
      case 'operation-not-allowed':
        return "Email and password sign-in is not enabled.";
      case 'weak-password':
        return "That password does not meet requirements.";
      case 'user-not-found':
        return "No account exists for that email.";
      case 'wrong-password':
        return "Incorrect email or password.";
      case 'user-disabled':
        return "This account has been disabled. Contact support.";
      case 'too-many-requests':
        return "Too many attempts. Try again later.";
      case 'invalid-verification-code':
        return "The verification code is invalid.";
      case 'invalid-verification-id':
        return "The verification ID is invalid.";
      case 'invalid-credential':
        return "Incorrect email or password.";
      case "network-request-failed":
        return "Network error. Check your connection and retry.";
      case "not-a-company-account":
        return "This is not a company account. Verify the email address.";
      case "user-is-company-admin":
        return "This is a company admin account. Verify the email address, "
            "or continue with individual login.";
      case "company-code-not-found":
        return "Invalid company code. Verify it and try again.";
      default:
        // Surface the real code/message so failures (e.g. Play Integrity /
        // reCAPTCHA attestation on devices without Google Play, or a blocked
        // Firestore/Auth endpoint) are diagnosable instead of hidden.
        return "The request could not be completed."
            "\n(code: $code${message != null ? " — $message" : ""})";
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';

extension AuthExceptionsHandler on FirebaseAuthException {
  String authError() {
    switch (code) {
      case 'email-already-in-use':
        return "📧 This email is already taken. Try another one!";
      case 'invalid-email':
        return "❌ That email doesn't look right. Double-check it!";
      case 'operation-not-allowed':
        return "🚫 Email/password sign-in isn't enabled. Turn it on!";
      case 'weak-password':
        return "🛡️ Your password needs to be stronger!";
      case 'user-not-found':
        return "🔍 No account found for that email. Try signing up!";
      case 'wrong-password':
        return "🔐 Oops! Wrong password or user not exists. Try again!";
      case 'user-disabled':
        return "🚫 This account has been disabled. Contact support.";
      case 'too-many-requests':
        return "🕒 Too many attempts. Take a breather and try later!";
      case 'invalid-verification-code':
        return "📲 Invalid verification code. Check your messages!";
      case 'invalid-verification-id':
        return "🆔 Invalid verification ID. Try again!";
      case 'invalid-credential':
        return "🆔 Invalid email ID or password. Try again!";
      case "network-request-failed":
        return "📶 Network request failed, or network error occured.";
      case "not-a-company-account":
        return "🚫 This account is not a company account. Please recheck your email address";
      case "user-is-company-admin":
        return "🚫 This account is a company admin account. Please recheck your email address or continue with individual login";
      case "company-code-not-found":
        return "❌ Invalid company code. Please check your company code and try again!";
      default:
        // Surface the real code/message so failures (e.g. Play Integrity /
        // reCAPTCHA attestation on devices without Google Play, or a blocked
        // Firestore/Auth endpoint) are diagnosable instead of hidden.
        return "⚠️ Something went wrong. Please try again!"
            "\n(code: $code${message != null ? " — $message" : ""})";
    }
  }
}

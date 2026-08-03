// ignore_for_file: avoid_print

import 'package:flatch/common/models/app_user.dart';
import 'package:flatch/common/models/custom_claims.dart';
import 'package:flatch/common/services/cloud_functions.dart';
import 'package:flatch/common/services/firestore_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

part 'individual_signup_event.dart';
part 'individual_signup_state.dart';

class IndividualSignupBloc
    extends Bloc<IndividualSignupEvent, IndividualSignupState> {
  IndividualSignupBloc() : super(const IndividualSignupInitial()) {
    on<IndividualSignupEvent>((event, emit) {});
    on<IndividualSignupRetry>(
      (event, emit) => emit(const IndividualSignupInitial()),
    );
    on<IndividualSignupStartedEvent>((event, emit) async {
      try {
        emit(IndividualSignupLoading());

        FirebaseAuth auth = FirebaseAuth.instance;
        UserCredential cred = await auth.createUserWithEmailAndPassword(
          email: event.email,
          password: event.password,
        );

        User? user = cred.user;
        if (user != null) {
          bool isSaved = await FirestoreServices.instance.addUserToFirestore(
            user,
            name: event.name,
            role: event.role,
            description: event.description,
            state: event.state,
            country: event.country,
          );

          if (!isSaved) {
            await auth.signOut();
            await user.delete();
            emit(
              IndividualSignupFailure(
                FirebaseAuthException(code: 'user-save-failed'),
              ),
            );
          } else {
            await user.sendEmailVerification();

            emit(IndividualSignupSuccess(user: user));
          }
        }
      } catch (e) {
        emit(
          IndividualSignupFailure(
            e is FirebaseAuthException
                ? e
                : FirebaseAuthException(
                  code: 'unknown-error',
                  message: e.toString(),
                ),
          ),
        );
      }
    });

    on<OnUserEnterPasswordEvent>((event, emit) {
      String password = event.password;
      bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
      bool hasLowercase = password.contains(RegExp(r'[a-z]'));
      bool hasMinLength = password.length >= 8 && password.length <= 20;
      bool hasNumber = password.contains(RegExp(r'[0-9]'));
      bool hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      final s = state as IndividualSignupInitial;
      emit(
        s.copyWith(
          usedCapitalLetter: hasUppercase,
          eightOfLenght: hasMinLength,
          usedLowerCase: hasLowercase,
          usedNumber: hasNumber,
          usedSpecialCharacter: hasSymbol,
        ),
      );
    });
    on<GoogleLogin>((event, emit) async {
      print("🚀 GoogleLogin event triggered");
      emit(IndividualSignupLoading());

      try {
        print("🟡 Initiating Google sign-in...");
        GoogleSignInAccount? account = await GoogleSignIn().signIn();

        if (account == null) {
          print("❌ User cancelled Google sign-in or no account selected.");
          emit(
            const DashboardErrorState(
              errorMessage: 'Google sign-in cancelled.',
            ),
          );
          return;
        }

        print("✅ Google account selected: ${account.email}");

        // NOTE: no "email already exists" gate — Google is sign-in OR sign-up.
        // The Firestore create-if-absent block below handles new vs. returning.
        final GoogleSignInAuthentication authenticate =
            await account.authentication;
        print("🟢 Retrieved authentication tokens.");

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authenticate.accessToken,
          idToken: authenticate.idToken,
        );

        print("🟢 Auth credential created. Signing in with Firebase...");

        UserCredential cred = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final User? user = cred.user;

        if (user == null) {
          print("❌ Firebase returned null user.");
          emit(
            const DashboardErrorState(
              errorMessage: 'Firebase returned no user.',
            ),
          );
          return;
        }

        print("✅ Firebase sign-in successful. UID: ${user.uid}");

        QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection("app_users")
                .where("uid", isEqualTo: user.uid)
                .get();

        print("🔍 Checking Firestore for existing user entry...");

        if (snapshot.docs.isEmpty) {
          print("🆕 User not found in Firestore. Adding new user...");
          await FirestoreServices.instance.addUserToFirestore(
            user,
            role: event.role ?? "Student",
            name: user.displayName ?? "",
          );

          // Fetch user again after adding
          snapshot =
              await FirebaseFirestore.instance
                  .collection("app_users")
                  .where("uid", isEqualTo: user.uid)
                  .get();
        } else {
          print("🟢 User already exists in Firestore.");
        }

        final userDoc = snapshot.docs.first;
        AppUser appUser = AppUser.fromMap(userDoc.data());

        final claims = CustomClaims(role: appUser.role);

        print("✅ Emitting success state with user.");

        emit(
          DashboardSuccessState(
            user: user,
            claims: claims,
            trialExpired: false,
          ),
        );
      } catch (e) {
        print("❌ Exception during Google sign-in: $e");
        emit(DashboardErrorState(errorMessage: e.toString()));
      }
    });

    on<AppleLogin>((event, emit) async {
      try {
        emit(IndividualSignupLoading());
        // Step 1: Trigger Apple sign-in
        final AuthorizationCredentialAppleID appleCredential =
            await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
            );

        // Step 2: Extract email and full name
        final String? email = appleCredential.email?.trim();
        final String? givenName = appleCredential.givenName;
        final String? familyName = appleCredential.familyName;

        // Step 3: Check if the email already exists
        bool isAlreadyExist = false;
        if (email != null && email.isNotEmpty) {
          try {
            isAlreadyExist = await CloudFunctionsService.instance
                .checkEmailExists(email);
            print("✅ Email exists: $isAlreadyExist");
          } catch (e) {
            print("❌ Error checking email existence: $e");
            emit(
              const DashboardErrorState(
                errorMessage: "Failed to check if the email already exists.",
              ),
            );
            return;
          }
        } else {
          print(
            "⚠️ Email is null or empty. Possibly a second-time Apple login.",
          );
        }

        // Step 4: Create Firebase OAuth credential
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        // Step 5: Sign in with Firebase
        final UserCredential cred = await FirebaseAuth.instance
            .signInWithCredential(oauthCredential);
        final User? user = cred.user;

        if (user == null) {
          emit(
            const DashboardErrorState(
              errorMessage: "User info not returned from Firebase.",
            ),
          );
          return;
        }

        // Step 6: Check if user already exists in Firestore
        QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection("app_users")
                .where("uid", isEqualTo: user.uid)
                .get();

        if (snapshot.docs.isEmpty) {
          print("🆕 New Apple user. Saving to Firestore...");

          final String name = [
            givenName?.trim(),
            familyName?.trim(),
          ].where((e) => e != null && e.isNotEmpty).join(" ");

          final String finalName =
              name.isNotEmpty ? name : user.displayName ?? "";

          print("👤 Final name to save: $finalName");

          await FirestoreServices.instance.addUserToFirestore(
            user,
            role: event.role ?? "Student",
            name: finalName,
          );

          // Re-fetch user after saving
          snapshot =
              await FirebaseFirestore.instance
                  .collection("app_users")
                  .where("uid", isEqualTo: user.uid)
                  .get();
        } else {
          print("📄 User already exists in Firestore.");
        }

        final userDoc = snapshot.docs.first;
        final appUser = AppUser.fromMap(userDoc.data());

        final claims = CustomClaims(role: appUser.role);
        final trialExpired = false;

        print("✅ Apple sign-in completed successfully.");

        emit(
          DashboardSuccessState(
            user: user,
            claims: claims,
            trialExpired: trialExpired,
          ),
        );
      } catch (e) {
        if (e is SignInWithAppleAuthorizationException &&
            e.code == AuthorizationErrorCode.canceled) {
          emit(
            const DashboardErrorState(
              errorMessage: "Sign in was canceled by the user.",
            ),
          );
        } else {
          print("❗ Unexpected error during Apple login: $e");
          emit(DashboardErrorState(errorMessage: e.toString()));
        }
      }
    });
  }
}

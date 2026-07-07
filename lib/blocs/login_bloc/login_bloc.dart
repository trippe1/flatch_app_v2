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
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(LoginInitialState()) {
    on<LoginEvent>((event, emit) {});
    on<DoLoginEvent>((event, emit) async {
      try {
        emit(LoginLoadingState());
        FirebaseAuth auth = FirebaseAuth.instance;
        await auth.signInWithEmailAndPassword(
          email: event.email,
          password: event.password,
        );
        User? user = auth.currentUser;

        if (user != null) {
          // Fetch user details from Firestore using custom userId field
          QuerySnapshot userDocs =
              await FirebaseFirestore.instance
                  .collection("app_users")
                  .where("uid", isEqualTo: user.uid)
                  .get();

          if (userDocs.docs.isNotEmpty) {
            DocumentSnapshot userDoc = userDocs.docs.first;

            AppUser appUser = AppUser.fromMap(
              userDoc.data() as Map<String, dynamic>,
            );
            CustomClaims claims = CustomClaims(role: appUser.role);
            // final bool trialExpired = await SubscService.instance
            //     .subscriptionExpired(claims);
            final bool trialExpired = false;

            emit(
              LoginSuccessState(
                claims: claims,
                user: user,
                trialExpired: trialExpired,
              ),
            );
          } else {
            emit(LoginFailureState("User data not found in Firestore"));
          }
        }
      } on FirebaseAuthException catch (e) {
        emit(LoginFailureState(e));
      } catch (e) {
        emit(LoginFailureState(e.toString()));
      }
    });
    on<CheckIfAlreadyLoggedInEvent>((event, emit) async {
      emit(LoginLoadingState());
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        print("User is $user");
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser != null && refreshedUser.emailVerified) {
          QuerySnapshot userDocs =
              await FirebaseFirestore.instance
                  .collection("app_users")
                  .where("uid", isEqualTo: refreshedUser.uid)
                  .get();

          if (userDocs.docs.isNotEmpty) {
            final userDoc = userDocs.docs.first;

            AppUser appUser = AppUser.fromMap(
              userDoc.data() as Map<String, dynamic>,
            );

            final claims = CustomClaims(role: appUser.role);

            // final bool trialExpired = await SubscService.instance
            //     .subscriptionExpired(claims);
            final bool trialExpired = false;

            emit(
              LoginSuccessState(
                user: refreshedUser,
                claims: claims,
                trialExpired: trialExpired,
              ),
            );
          } else {
            emit(LoginFailureState("User info not found in Firestore"));
          }
        } else {
          await FirebaseAuth.instance.signOut();
          emit(LoginEmailNotVerifiedState());
        }
      } else {
        emit(LoginInitialState());
      }
    });
    on<GoogleLoginEvent>((event, emit) async {
      print("🚀 GoogleLoginEvent event triggered");
      emit(LoginLoadingState());

      try {
        print("🟡 Initiating Google sign-in...");
        GoogleSignInAccount? account = await GoogleSignIn().signIn();

        if (account == null) {
          print("❌ User cancelled Google sign-in or no account selected.");
          emit(const LoginFailureState('Google sign-in cancelled.'));
          return;
        }

        print("✅ Google account selected: ${account.email}");

        final bool isAlreadyExist = await CloudFunctionsService.instance
            .checkEmailExists(account.email.trim());

        print("🟡 Checking if email already exists: $isAlreadyExist");

        if (isAlreadyExist) {
          print("⚠️ Email already exists in system. Aborting sign-in.");
          emit(const LoginFailureState('User already signed in or exists.'));
          return;
        }

        print("🟢 Email does not exist. Continuing authentication...");

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
          emit(const LoginFailureState('Firebase returned no user.'));
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
          LoginSuccessState(user: user, claims: claims, trialExpired: false),
        );
      } catch (e) {
        print("❌ Exception during Google sign-in: $e");
        emit(LoginFailureState(e.toString()));
      }
    });

    on<AppleLoginEvent>((event, emit) async {
      try {
        emit(LoginLoadingState());
        final AuthorizationCredentialAppleID appleCredential =
            await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
            );

        final String? email = appleCredential.email?.trim();
        final String? givenName = appleCredential.givenName;
        final String? familyName = appleCredential.familyName;

        print("🧾 Apple Sign-In Info:");
        print("📧 Email: $email");
        print("🧍‍♂️ Given Name: $givenName");
        print("🧍‍♀️ Family Name: $familyName");

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
              const LoginFailureState(
                "Failed to check if the email already exists.",
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
            const LoginFailureState("User info not returned from Firebase."),
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
          LoginSuccessState(
            user: user,
            claims: claims,
            trialExpired: trialExpired,
          ),
        );
      } catch (e) {
        if (e is SignInWithAppleAuthorizationException &&
            e.code == AuthorizationErrorCode.canceled) {
          emit(const LoginFailureState("Sign in was canceled by the user."));
        } else {
          print("❗ Unexpected error during Apple login: $e");
          emit(LoginFailureState(e.toString()));
        }
      }
    });

    on<ResetStateEvent>((event, emit) => emit(LoginInitialState()));
  }
}

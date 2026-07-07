import 'package:flatch/common/services/cloud_functions.dart';
import 'package:flatch/common/services/firestore_services.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:google_sign_in/google_sign_in.dart';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';
part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardEvent>((event, emit) {});
    on<GoogleLogin>((event, emit) async {
      try {
        GoogleSignInAccount? account = await GoogleSignIn().signIn();

        if (account == null) {
          emit(
            const DashboardErrorState(
              errorMessage: 'Google sign-in cancelled.',
            ),
          );
          return;
        }

        final bool isAlreadyExist = await CloudFunctionsService.instance
            .checkEmailExists(account.email.trim());

        if (isAlreadyExist) {
          emit(
            const DashboardErrorState(
              errorMessage: 'User already signed in or exists.',
            ),
          );
          return;
        }

        final GoogleSignInAuthentication authenticate =
            await account.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authenticate.accessToken,
          idToken: authenticate.idToken,
        );

        UserCredential cred = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final User? user = cred.user;

        if (user == null) {
          emit(
            const DashboardErrorState(
              errorMessage: 'Firebase returned no user.',
            ),
          );
          return;
        }

        QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection("app_users")
                .where("uid", isEqualTo: user.uid)
                .get();

        if (snapshot.docs.isEmpty) {
          await FirestoreServices.instance.addUserToFirestore(
            user,
            role: event.role ?? "Student",
            name: user.displayName ?? "",
          );
        } else {}

        emit(DashboardSuccessState(user: user));
      } catch (e) {
        emit(DashboardErrorState(errorMessage: e.toString()));
      }
    });

    on<AppleLogin>((event, emit) async {
      try {
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

        bool isAlreadyExist = false;
        if (email != null && email.isNotEmpty) {
          try {
            isAlreadyExist = await CloudFunctionsService.instance
                .checkEmailExists(email);
          } catch (e) {
            emit(
              const DashboardErrorState(
                errorMessage: "Failed to check if the email already exists.",
              ),
            );
            return;
          }
        } else {}

        // Step 4: Create Firebase OAuth credential
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        if (!isAlreadyExist) {
          // Step 5: Sign in with Firebase
          final UserCredential cred = await FirebaseAuth.instance
              .signInWithCredential(oauthCredential);
          final User? user = cred.user;

          if (user != null) {
            // Step 6: Check if the user already exists in Firestore
            final snapshot =
                await FirebaseFirestore.instance
                    .collection("app_users")
                    .where("uid", isEqualTo: user.uid)
                    .get();

            if (snapshot.docs.isEmpty) {
              // Step 7: Construct name using Apple data if first-time login
              final String name = [
                givenName?.trim(),
                familyName?.trim(),
              ].where((e) => e != null && e.isNotEmpty).join(" ");

              final String finalName =
                  name.isNotEmpty ? name : user.displayName ?? "";

              // Step 8: Save new user to Firestore
              await FirestoreServices.instance.addUserToFirestore(
                user,
                role: event.role ?? "User",
                name: finalName,
              );
            } else {}

            emit(DashboardSuccessState(user: user));
          } else {
            emit(
              const DashboardErrorState(
                errorMessage: "User info not returned from Firebase.",
              ),
            );
          }
        } else {
          emit(
            const DashboardErrorState(
              errorMessage: "User already signed in with the same account.",
            ),
          );
        }
      } catch (e) {
        if (e is SignInWithAppleAuthorizationException &&
            e.code == AuthorizationErrorCode.canceled) {
          emit(
            const DashboardErrorState(
              errorMessage: "Sign in was canceled by the user.",
            ),
          );
        } else {
          emit(DashboardErrorState(errorMessage: e.toString()));
        }
      }
    });

    on<EmitInitialState>((event, emit) => emit(DashboardInitial()));
  }
}

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flatch/common/models/custom_claims.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/services/firestore_services.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/widgets/fart_preview.dart';
import 'package:flatch/views/admin_app/assign_users.dart';
import 'package:flatch/views/admin_app/fetch_all_sounds.dart';
import 'package:flatch/views/admin_app/selection_page.dart';
import 'package:flatch/views/dashboard/view.dart';
import 'package:flatch/views/delete_account/delete_account.dart';
import 'package:flatch/views/email_not_verified/email_verification.dart';
import 'package:flatch/views/email_not_verified/view.dart';
import 'package:flatch/views/forgot_password/view.dart';
import 'package:flatch/views/home/banned_view.dart';
import 'package:flatch/views/home/buy_device.dart';
import 'package:flatch/views/home/comment_fart.dart';
import 'package:flatch/views/home/home_view.dart';

import 'package:flatch/views/login/view.dart';
import 'package:flatch/views/profile/contact_us.dart';
import 'package:flatch/views/profile/my_uploads.dart';
import 'package:flatch/views/profile/user_details.dart';
import 'package:flatch/views/sign_up/view.dart';
import 'package:flatch/views/splash/splash_view.dart';
import 'package:flatch/views/update_profile/password_update.dart';
import 'package:flatch/views/update_profile/update_account.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

enum AppRoute {
  splash,
  emailNotVerified,
  userSubscriptionEnded,
  chooseDestination,
  userAppDashboard,
  forgotPasswordView,
  choosetheRole,
  visaEligibilityCheck,
  visaEligibilityResult,
  searchaConsultant,
  chatScreen,
  consultantChat,
  home,
  consultantHome,
  intro,
  login,
  signup,
  forgotPassword,
  dashboard,
  profile,
  settings,
  notifications,
  consultantNotification,
  aboutUs,
  contactUs,
  termsAndConditions,
  privacyPolicy,
  consultantDetailsScreen,
  bookinNowScreen,
  updateProfile,
  updatePassword,
  consultantProfile,
  consultantGigs,
  buildRoadmap,
  customBooking,
  allSuccessStories,
  whenRoadmapSave,
  assessment,
  assessmentView,
  testingChat,
  deleteAccount,
  buildActualRoadmap,
  whenActualRoadmapSaved,
  webview,
  documentView,
  emailVerificationScreen,
  myUploads,
  buyDevice,
  commentFart,
  userProfileScreen,
  selectionPage,
  adminPanel,
  assignUserRole,
  bannedWall,
}

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String intro = '/intro';
  static const String login = '/login';
  static const String signup = '/signIn';
  static const String forgotPasswordView = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String aboutUs = '/about-us';
  static const String contactUs = '/contact-us';
  static const String termsAndConditions = '/terms-and-conditions';
  static const String privacyPolicy = '/privacy-policy';
  static const String emailNotVerified = '/email-not-verified';
  static const String choosetheRole = '/choosethe-role';
  static const String consultantHome = '/consultant-home';
  static const String visaEligibiltyCheck = '/visa-eligibility-check';
  static const String visaEligibilityResult = '/visa-eligibility-result';
  static const String searchaConsultant = '/search-a-consultant';
  static const String consultantDetailsScreen = '/consultant-details-screen';
  static const String chatScreen = '/chat-screen';
  static const String bookinNowScreen = '/book-now-screen';
  static const String updateProfile = '/update-profile';
  static const String updatePassword = '/update-password';
  static const String consultantChat = '/consultant-chat';
  static const String consultantNotification = '/consultant-notification';
  static const String consultantProfile = '/consultant-profile';
  static const String consultantGigs = '/consultant-gigs';
  static const String buildRoadmap = '/build-roadmap';
  static const String customBooking = '/custom-booking';
  static const String allSuccessStories = '/all-success-stories';
  static const String whenRoadmapSave = '/when-roadmap-saved';
  static const String assessment = '/assessment';
  static const String assessmentView = '/assessment-view';
  static const String testingChat = '/testing-chat';
  static const String deleteAccount = '/delete-account';
  static const String buildActualRoadmap = '/build-actual-roadmap';
  static const String whenActualRoadmapSaved = '/when-actual-roadmap-saved';
  static const String webview = '/webview';
  static const String documentView = '/document-view';
  static const String emailVerificationScreen = '/email-verification-screen';
  static const String myUploads = '/my-uploads';
  static const String buyDevice = '/buy-device';
  static const String commentFart = '/comment-fart';
  static const String userProfileScreen = '/user-profile-screen';
  static const String selectionPage = '/selection-page';
  static const String adminPanel = '/admin-panel';
  static const String assignUserRole = '/assign-user-role';
  static const String bannedWall = '/banned-wall';

  static FutureOr<String?> guard(
    BuildContext context,
    GoRouterState state,
  ) async {
    if (state.uri.path == '/google/link' &&
        state.uri.queryParameters.containsKey('request_ip_version')) {
      return AppRoute.intro.name;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    print("user: $user");

    if (user != null) {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('app_users')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        print("No user found with uid ${user.uid}");
        return router.namedLocation(AppRoute.intro.name);
      }

      final userData = querySnapshot.docs.first.data();
      final String? role = userData['role'];
      final supportSnap =
          await FirebaseFirestore.instance
              .collection('contact_support')
              .limit(1)
              .get();

      String supportEmail = "";

      if (supportSnap.docs.isNotEmpty) {
        supportEmail =
            supportSnap.docs.first.data()['supportEmail'] ?? supportEmail;
      }

      final bool isBan = userData['isBan'] == true;
      final int? bannedAt = userData['bannedAt'];
      final String banReason = userData['banReason'] ?? "No reason provided";

      if (isBan) {
        return "/banned?"
            "bannedAt=$bannedAt"
            "&banReason=${Uri.encodeComponent(banReason)}"
            "&supportEmail=${Uri.encodeComponent(supportEmail)}";
      }

      if (role == null) {
        print("User role not found");
        return router.namedLocation(AppRoute.intro.name);
      }

      final claims = CustomClaims(role: role);
      print("User role: $role");
      print("User claims: ${claims.isAdmin}");

      if (!user.emailVerified) {
        return router.namedLocation(AppRoute.emailVerificationScreen.name);
      } else if (claims.isAdmin) {
        return router.namedLocation(AppRoute.selectionPage.name);
      } else if (claims.isConsultant) {
        return router.namedLocation(AppRoute.consultantHome.name);
      } else {
        return router.namedLocation(AppRoute.home.name);
      }
    }

    return null;
  }

  static GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    routes: [
      GoRoute(
        path: selectionPage,
        name: AppRoute.selectionPage.name,
        builder: (context, state) => SelectionScreen(),
      ),
      GoRoute(
        path: assignUserRole,
        name: AppRoute.assignUserRole.name,
        pageBuilder: (context, state) {
          return CupertinoPage(key: state.pageKey, child: AdminUsersPage());
        },
      ),
      GoRoute(
        path: '/banned',
        name: AppRoute.bannedWall.name,
        builder: (context, state) {
          final bannedAt =
              int.tryParse(state.uri.queryParameters['bannedAt'] ?? "0") ?? 0;
          final banReason =
              state.uri.queryParameters['banReason'] ?? "No reason provided";
          final supportEmail =
              state.uri.queryParameters['supportEmail'] ??
              "evan.k.tripp@gmail.com";

          return BannedWall(
            isBan: true,
            banReason: banReason,
            bannedAt: bannedAt,
            supportEmail: supportEmail,
          );
        },
      ),

      GoRoute(
        path: adminPanel,
        name: AppRoute.adminPanel.name,
        builder: (context, state) => AdminFetchFarts(),
      ),

      GoRoute(
        path: splash,
        name: AppRoute.splash.name,
        builder: (context, state) => SplashView(),
      ),
      GoRoute(
        path: buyDevice,
        name: AppRoute.buyDevice.name,
        builder: (context, state) => FlatchPurchasePage(),
      ),
      GoRoute(
        path: userProfileScreen,
        name: AppRoute.userProfileScreen.name,
        builder: (context, state) {
          final userId = state.extra as String;
          final isAdmin =
              state.uri.queryParameters['isAdmin']?.toLowerCase() == 'true';
          return UsersDetailsScreen(userId: userId, isAdmin: isAdmin);
        },
      ),
      GoRoute(
        path: myUploads,
        name: AppRoute.myUploads.name,
        pageBuilder:
            (context, state) => const CupertinoPage(child: MyUploadsScreen()),
      ),

      GoRoute(
        path: contactUs,
        name: AppRoute.contactUs.name,
        pageBuilder:
            (context, state) => const CupertinoPage(child: ContactUsScreen()),
      ),

      GoRoute(
        path: commentFart,
        name: AppRoute.commentFart.name,
        pageBuilder: (context, state) {
          final fart = state.extra as FartModel;

          final isAdmin =
              state.uri.queryParameters['isAdmin']?.toLowerCase() == 'true';

          return CupertinoPage(
            key: state.pageKey,
            child: FartDetailScreen(fart: fart, isAdmin: isAdmin),
          );
        },
      ),
      GoRoute(
        path: '/fart/:id',
        builder: (context, state) {
          final fartId = state.pathParameters['id']!;
          final fartdecodedId = ShareService.instance.decodeFartId(fartId);

          return FutureBuilder<FartModel>(
            future: FirestoreServices.instance.fetchFartById(fartdecodedId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text("Error: ${snapshot.error}")),
                );
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: Text("Fart not found")),
                );
              }

              return FartPreviewScreen(fart: snapshot.data!);
            },
          );
        },
      ),

      GoRoute(
        path: home,
        name: AppRoute.home.name,
        builder: (context, state) => const UserAppDashboardView(),
      ),
      GoRoute(
        path: dashboard,
        name: AppRoute.dashboard.name,
        builder: (context, state) => const DashboardView(),
        redirect: guard,
      ),
      GoRoute(
        path: emailVerificationScreen,
        name: AppRoute.emailVerificationScreen.name,
        builder: (context, state) => const EmailVerificationScreen(),
        redirect: guard,
      ),

      GoRoute(
        path: login,
        name: AppRoute.login.name,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: signup,
        name: AppRoute.signup.name,
        builder: (context, state) => IndividualSignup(),
      ),
      GoRoute(
        path: forgotPasswordView,
        name: AppRoute.forgotPasswordView.name,
        builder: (context, state) => const ForgotPasswordView(),
      ),

      GoRoute(
        path: emailNotVerified,
        name: AppRoute.emailNotVerified.name,
        builder: (context, state) => const EmailNotVerifiedView(),
      ),

      GoRoute(
        path: updateProfile,
        name: AppRoute.updateProfile.name,
        builder: (context, state) => const UpdateUsernameView(),
      ),
      GoRoute(
        path: updatePassword,
        name: AppRoute.updatePassword.name,
        builder: (context, state) => const UserAppUpdatePasswordView(),
      ),

      GoRoute(
        path: deleteAccount,
        name: AppRoute.deleteAccount.name,
        builder: (context, state) => DeleteUserAccountView(),
      ),
    ],
  );
}

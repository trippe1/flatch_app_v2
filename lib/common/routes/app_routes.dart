// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flatch/common/models/custom_claims.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/services/firestore_services.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/widgets/fart_preview.dart';
import 'package:flatch/blocs/moderation_queue/moderation_queue_bloc.dart';
import 'package:flatch/views/about/about_screen.dart';
import 'package:flatch/views/age_gate/age_gate_screen.dart';
import 'package:flatch/views/home/stock_sounds_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flatch/views/admin_app/assign_users.dart';
import 'package:flatch/views/admin_app/fetch_all_sounds.dart';
import 'package:flatch/views/admin_app/moderation_queue.dart';
import 'package:flatch/views/admin_app/selection_page.dart';
import 'package:flatch/views/dashboard/view.dart';
import 'package:flatch/views/delete_account/delete_account.dart';
import 'package:flatch/views/email_not_verified/email_verification.dart';
import 'package:flatch/views/email_not_verified/view.dart';
import 'package:flatch/views/forgot_password/view.dart';
import 'package:flatch/views/home/banned_view.dart';
import 'package:flatch/views/home/buy_device.dart';
import 'package:flatch/views/home/comment_fart.dart';
import 'package:flatch/views/home/edit_fart.dart';
import 'package:flatch/views/home/home_view.dart';
import 'package:flatch/views/fwb/fwb_home_screen.dart';
import 'package:flatch/views/fwb/fwb_create_screen.dart';
import 'package:flatch/views/fwb/fwb_chat_screen.dart';
import 'package:flatch/views/fwb/fwb_join_screen.dart';

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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

enum AppRoute {
  splash,
  emailNotVerified,
  userSubscriptionEnded,
  forgotPasswordView,
  home,
  intro,
  login,
  signup,
  dashboard,
  contactUs,
  updateProfile,
  updatePassword,
  deleteAccount,
  emailVerificationScreen,
  myUploads,
  buyDevice,
  commentFart,
  editFart,
  userProfileScreen,
  selectionPage,
  adminPanel,
  assignUserRole,
  bannedWall,
  moderationQueue,
  ageGate,
  stockSounds,
  about,
  fwbHome,
  fwbCreate,
  fwbChat,
  fwbJoin,
}

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String intro = '/intro';
  static const String login = '/login';
  static const String signup = '/signIn';
  static const String forgotPasswordView = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String contactUs = '/contact-us';
  static const String emailNotVerified = '/email-not-verified';
  static const String updateProfile = '/update-profile';
  static const String updatePassword = '/update-password';
  static const String deleteAccount = '/delete-account';
  static const String emailVerificationScreen = '/email-verification-screen';
  static const String myUploads = '/my-uploads';
  static const String buyDevice = '/buy-device';
  static const String commentFart = '/comment-fart';
  static const String editFart = '/edit-fart';
  static const String userProfileScreen = '/user-profile-screen';
  static const String selectionPage = '/selection-page';
  static const String adminPanel = '/admin-panel';
  static const String assignUserRole = '/assign-user-role';
  static const String bannedWall = '/banned-wall';
  static const String moderationQueue = '/moderation-queue';
  static const String ageGate = '/age-gate';
  static const String stockSounds = '/stock-sounds';
  static const String about = '/about';
  static const String fwbHome = '/fwb';
  static const String fwbCreate = '/fwb/create';
  static const String fwbChat = '/fwb/chat';
  static const String fwbJoin = '/fwb/:groupId';

  static FutureOr<String?> guard(
    BuildContext context,
    GoRouterState state,
  ) async {
    if (state.uri.path == '/google/link' &&
        state.uri.queryParameters.containsKey('request_ip_version')) {
      return AppRoute.intro.name;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    try {
      // Time-box the profile lookups. This redirect runs while the splash is on
      // screen; a pending async redirect keeps the *current* page visible, so a
      // stalled Firestore call (offline, App Check latency, transient error)
      // would trap the user on the splash forever. Never let that happen.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('app_users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (querySnapshot.docs.isEmpty) {
        return router.namedLocation(AppRoute.intro.name);
      }

      final userData = querySnapshot.docs.first.data();
      final String? role = userData['role'];

      final bool isBan = userData['isBan'] == true;
      final int? bannedAt = userData['bannedAt'];
      final String banReason = userData['banReason'] ?? "No reason provided";

      if (isBan) {
        // The support email is a nicety on the ban wall — best-effort, and it
        // must not gate the redirect if that read is slow.
        String supportEmail = "";
        try {
          final supportSnap = await FirebaseFirestore.instance
              .collection('contact_support')
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));
          if (supportSnap.docs.isNotEmpty) {
            supportEmail =
                supportSnap.docs.first.data()['supportEmail'] ?? supportEmail;
          }
        } catch (_) {}

        return "/banned?"
            "bannedAt=$bannedAt"
            "&banReason=${Uri.encodeComponent(banReason)}"
            "&supportEmail=${Uri.encodeComponent(supportEmail)}";
      }

      if (role == null) {
        return router.namedLocation(AppRoute.intro.name);
      }

      final claims = CustomClaims(role: role);

      // Email verification is enforced at the point of POSTING (see
      // EmailVerificationGate), not here — an unverified user may browse,
      // listen, and use their Flatch device.
      if (claims.isAdmin) {
        return router.namedLocation(AppRoute.selectionPage.name);
      } else {
        return router.namedLocation(AppRoute.home.name);
      }
    } catch (e, st) {
      // Profile lookup stalled or failed. Don't strand the user on the splash —
      // let them into the app (ban/role checks re-run on the next guarded
      // navigation). Record it so we can see if this fires in the wild.
      debugPrint("Router guard fallback → home: $e");
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'router guard fallback',
        fatal: false,
      );
      return router.namedLocation(AppRoute.home.name);
    }
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
        path: ageGate,
        name: AppRoute.ageGate.name,
        builder: (context, state) => const AgeGateScreen(),
      ),

      GoRoute(
        path: stockSounds,
        name: AppRoute.stockSounds.name,
        builder: (context, state) => const StockSoundsScreen(),
      ),

      GoRoute(
        path: about,
        name: AppRoute.about.name,
        builder: (context, state) => const AboutScreen(),
      ),

      // Farts with Buddies. Declare the static sub-paths before the
      // `/fwb/:groupId` invite route so they aren't swallowed as a groupId.
      GoRoute(
        path: fwbHome,
        name: AppRoute.fwbHome.name,
        builder: (context, state) => const FwbHomeScreen(),
      ),
      GoRoute(
        path: fwbCreate,
        name: AppRoute.fwbCreate.name,
        builder: (context, state) => const FwbCreateScreen(),
      ),
      GoRoute(
        path: fwbChat,
        name: AppRoute.fwbChat.name,
        builder: (context, state) {
          final groupId = state.extra as String;
          return FwbChatScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: fwbJoin,
        name: AppRoute.fwbJoin.name,
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return FwbJoinScreen(groupId: groupId);
        },
      ),

      GoRoute(
        path: moderationQueue,
        name: AppRoute.moderationQueue.name,
        builder:
            (context, state) => BlocProvider(
              create:
                  (_) =>
                      ModerationQueueBloc()..add(const FetchModerationQueue()),
              child: const ModerationQueuePage(),
            ),
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
        path: editFart,
        name: AppRoute.editFart.name,
        pageBuilder: (context, state) {
          final fart = state.extra as FartModel;
          return CupertinoPage(
            key: state.pageKey,
            child: EditFartScreen(fart: fart),
          );
        },
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

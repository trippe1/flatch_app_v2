// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flatch/blocs/student_profile_managment/profile_managment_bloc.dart';
import 'package:flatch/common/app_helpers/theme_helper.dart'
    show ThemeController;
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/dialogues/upload_image.dart';
import 'package:flatch/common/local_db/local_database.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/url_services.dart';
import 'package:flatch/common/services/fwb_service.dart';
import 'package:flatch/common/widgets/accident_counter.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/cubits/accident_counter/accident_counter_cubit.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/cubits/user_app_dashboard/user_app_dashboard_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool? _fwbNotif; // null until loaded

  @override
  void initState() {
    // Settings is guest-accessible; only pull the account profile when a user
    // is actually signed in (otherwise the fetch errors out on no user).
    if (FirebaseAuth.instance.currentUser != null) {
      BlocProvider.of<ProfileManagmentBloc>(context).add(GetUserDetailsEvent());
      FwbService.notificationsEnabled().then((v) {
        if (mounted) setState(() => _fwbNotif = v);
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bool signedIn = FirebaseAuth.instance.currentUser != null;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: BlocBuilder<UserAppDashboardCubit, UserAppDashboardState>(
          builder: (context, state) {
            return IconButton(
              style: const ButtonStyle().copyWith(
                backgroundColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                side: const WidgetStatePropertyAll(BorderSide.none),
              ),
              onPressed: () {
                BlocProvider.of<UserAppDashboardCubit>(
                  context,
                ).onUpdateIndex(0);

                context.goNamed(AppRoute.home.name, extra: {"navigation": 0});
              },
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).iconTheme.color,
              ),
            );
          },
        ),
        title: Text(
          signedIn ? "Profile" : "Settings",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).iconTheme.color,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body:
          !signedIn
              ? _guestSettings(context)
              : BlocBuilder<ProfileManagmentBloc, ProfileManagmentState>(
                builder: (context, state) {
                  switch (state) {
                    case ProfileManagmentInitial():
                      return SizedBox();
                    case ProfileManagmentLoading():
                      return const Center(child: KProgressIndicator());
                    case ProfileManagmentLoaded():
                      return _successState(context, state);
                    case ProfileManagmentError():
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error,
                            color: Colors.black,
                            size: height * 0.25,
                          ),
                          const Gap(10),
                          const TextWidget(
                            text: "An error occurred.",
                            size: 22,
                            weight: FontWeight.bold,
                          ),
                          const Gap(20),
                          TextWidget(
                            text: state.error,
                            color: Colors.black.withOpacity(.6),
                            padding: 60,
                            textAlign: TextAlign.center,
                          ),
                          const Gap(40),
                          TextButton(
                            onPressed:
                                () => context.read<ProfileManagmentBloc>().add(
                                  GetUserDetailsEvent(),
                                ),
                            child: const Text("Retry"),
                          ),
                        ],
                      );
                    case UploadingUserImageLoadingState():
                      return imageUploadingLoadingState();
                    case UploadingUserErrorState():
                      return imageUploadingErrorState(state, context);
                  }
                },
              ),
    );
  }

  /// Account-free settings shown to guests: theme, legal, about, buy-device,
  /// support, plus a prompt to create an account. No profile/library/account
  /// options (those require an account).
  Widget _guestSettings(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: 'Guest mode',
                size: 16,
                weight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              const SizedBox(height: 6),
              Text(
                'You can use the device and its built-in sounds without an '
                'account. Create one to post, comment, vote, and manage your '
                'library.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed:
                      () =>
                          GoRouter.of(context).pushNamed(AppRoute.ageGate.name),
                  child: const Text('Create account / Sign in'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader("🛍️ Device & Legal"),
        _buildActionTile(
          icon: Icons.info_outline,
          label: "Buy the Device",
          onTap: () => GoRouter.of(context).pushNamed(AppRoute.buyDevice.name),
        ),
        _buildActionTile(
          icon: CupertinoIcons.eyeglasses,
          label: "Terms of Use",
          onTap:
              () =>
                  UrlLauncherService.instance.launchTermsAndConditions(context),
        ),
        _buildActionTile(
          icon: Icons.privacy_tip_outlined,
          label: "Privacy Policy",
          onTap: () => UrlLauncherService.instance.launchPrivacyPolicy(context),
        ),
        _buildActionTile(
          icon: Icons.info_outline,
          label: "About",
          onTap: () => GoRouter.of(context).pushNamed(AppRoute.about.name),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader("Appearance"),
        _buildThemeSwitchTile(),
        const SizedBox(height: 20),
        _buildSectionHeader("Support"),
        _buildActionTile(
          icon: Icons.mail_outline,
          label: "Contact Us",
          onTap: () => GoRouter.of(context).pushNamed(AppRoute.contactUs.name),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Column imageUploadingErrorState(
    UploadingUserErrorState state,
    BuildContext context,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error,
          color: Colors.black,
          size: MediaQuery.of(context).size.height * 0.25,
        ),
        const Gap(10),
        const TextWidget(
          text: "An error occurred.",
          size: 22,
          weight: FontWeight.bold,
        ),
        const Gap(20),
        TextWidget(
          text: state.error,
          color: Colors.black.withOpacity(.6),
          padding: 60,
          textAlign: TextAlign.center,
        ),
        const Gap(40),
        TextButton(
          onPressed:
              () => context.read<ProfileManagmentBloc>().add(
                GetUserDetailsEvent(),
              ),
          child: const Text("Retry"),
        ),
      ],
    );
  }

  Column imageUploadingLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Image.asset(
            "assets/images/flatch_logo.png",
            height: 200,
            width: 200,
          ),
        ),
        const TextWidget(text: "Uploading", weight: FontWeight.bold, size: 22),
        const Gap(20),
        TextWidget(
          text: "Please wait while your image is being uploaded",
          padding: 60,
          textAlign: TextAlign.center,
          color: Colors.black.withOpacity(.5),
        ),
      ],
    );
  }

  /// Profile card holding the badge-size "Days Since Last Accident" scoreboard.
  /// Tapping anywhere opens the detail page.
  Widget _buildAccidentBadge(BuildContext context) {
    return BlocBuilder<AccidentCounterCubit, AccidentCounterState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF12351F).withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x337ED957)),
          ),
          child: Center(
            child: AccidentCounter(
              value: state.daysSince,
              size: AccidentCounterSize.badge,
              rollToken: state.rollToken,
              onTap: () =>
                  GoRouter.of(context).pushNamed(AppRoute.accidentCounter.name),
            ),
          ),
        );
      },
    );
  }

  Widget _successState(BuildContext context, ProfileManagmentLoaded state) {
    final user = state.user;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 30),

        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              InkWell(
                onTap:
                    () => showDialog(
                      context: context,
                      builder: (context) => const UploadImageDialog(),
                    ),
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.teal, Colors.pinkAccent],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage:
                              user.photoURL == null
                                  ? const AssetImage(
                                    "assets/images/flatch_logo.png",
                                  )
                                  : NetworkImage(user.photoURL!)
                                      as ImageProvider,
                          radius: 42,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap:
                            () => showDialog(
                              context: context,
                              builder: (context) => const UploadImageDialog(),
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(20),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text:
                        state.appUser.name.length > 20
                            ? state.appUser.name.substring(0, 20)
                            : state.appUser.name,
                    size: 18,
                    weight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.appUser.email,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 13,
                    ),
                  ),
                  if (user.phoneNumber != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          user.phoneNumber!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        _buildAccidentBadge(context),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildSectionHeader("👯 Farts with Buddies"),
            _buildActionTile(
              icon: Icons.groups_rounded,
              label: "Farts with Buddies",
              onTap:
                  () => GoRouter.of(context).pushNamed(AppRoute.fwbHome.name),
            ),
            _buildFwbNotificationsTile(),

            const SizedBox(height: 20),
            _buildSectionHeader("📁 Content"),
            _buildActionTile(
              icon: CupertinoIcons.upload_circle,
              label: "My Fart Library",
              onTap:
                  () => GoRouter.of(context).pushNamed(AppRoute.myUploads.name),
            ),

            const SizedBox(height: 20),
            _buildSectionHeader("🛍️ Device & Legal"),
            _buildActionTile(
              icon: Icons.info_outline,
              label: "Buy the Device",
              onTap:
                  () => GoRouter.of(context).pushNamed(AppRoute.buyDevice.name),
            ),
            _buildActionTile(
              icon: CupertinoIcons.eyeglasses,
              label: "Terms of Use",
              onTap:
                  () => UrlLauncherService.instance.launchTermsAndConditions(
                    context,
                  ),
            ),
            _buildActionTile(
              icon: Icons.privacy_tip_outlined,
              label: "Privacy Policy",
              onTap:
                  () =>
                      UrlLauncherService.instance.launchPrivacyPolicy(context),
            ),
            _buildActionTile(
              icon: Icons.info_outline,
              label: "About",
              onTap: () => GoRouter.of(context).pushNamed(AppRoute.about.name),
            ),

            const SizedBox(height: 20),
            _buildSectionHeader("🔐 Account Settings"),
            _buildActionTile(
              icon: Icons.lock_outline,
              label: "Update Password",
              onTap:
                  () => GoRouter.of(
                    context,
                  ).pushNamed(AppRoute.updatePassword.name),
            ),
            _buildActionTile(
              icon: CupertinoIcons.person_crop_circle,
              label: "Update Profile",
              onTap:
                  () => GoRouter.of(
                    context,
                  ).pushNamed(AppRoute.updateProfile.name),
            ),
            _buildActionTile(
              icon: Icons.mail_outline,
              label: "Contact Us",
              onTap:
                  () => GoRouter.of(context).pushNamed(AppRoute.contactUs.name),
            ),

            const SizedBox(height: 20),
            _buildSectionHeader("Appearance"),
            _buildThemeSwitchTile(),
            const SizedBox(height: 20),
            _buildSectionHeader("⚠️ Danger Zone"),
            _buildActionTile(
              icon: CupertinoIcons.delete,
              label: "Delete Account",
              onTap:
                  () => GoRouter.of(
                    context,
                  ).pushNamed(AppRoute.deleteAccount.name),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // 🚪 Logout Button
        Center(
          child: TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await LocalDatabase.instance.deleteFirstVisitDetails();
              context.goNamed(AppRoute.login.name);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("LOGOUT", style: TextStyle(fontSize: 16)),
          ),
        ),
        Gap(20),
        if (state.claims.isAdmin)
          Center(
            child: TextButton(
              onPressed: () async {
                context.goNamed(AppRoute.adminPanel.name);
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("ADMIN", style: TextStyle(fontSize: 16)),
            ),
          ),

        const SizedBox(height: 25),

        // ℹ️ App Version
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              Text(
                "App Version: ${state.version}",
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(.1),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Theme.of(context).iconTheme.color),
            ),
            const SizedBox(width: 12),
            TextWidget(
              text: label,
              size: 16,
              weight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).iconTheme.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFwbNotificationsTile() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextWidget(
              text: 'Notify me about new posts',
              size: 16,
              weight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          Switch(
            value: _fwbNotif ?? true,
            onChanged:
                _fwbNotif == null
                    ? null
                    : (value) {
                      setState(() => _fwbNotif = value);
                      FwbService.setNotifications(value);
                    },
            activeColor: AppColors.primary,
            inactiveThumbColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSwitchTile() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.dark_mode,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
          const SizedBox(width: 12),
          TextWidget(
            text: 'Switch Theme',
            size: 16,
            weight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          const Spacer(),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, themeMode, _) {
              return Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ThemeController.toggleTheme();
                },
                activeColor: AppColors.primary,
                inactiveThumbColor: AppColors.secondary,
              );
            },
          ),
        ],
      ),
    );
  }
}

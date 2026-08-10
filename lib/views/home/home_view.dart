// ignore_for_file: deprecated_member_use

import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/widgets/bottom_app_bar.dart';
import 'package:flatch/common/widgets/community_gate.dart';
import 'package:flatch/cubits/user_app_dashboard/user_app_dashboard_cubit.dart';
import 'package:flatch/views/home/fetch_farts.dart';
import 'package:flatch/views/fwb/fwb_home_screen.dart';
import 'package:flatch/views/home/upload_fart.dart';
import 'package:flatch/views/home/bluetooth_sync.dart';
import 'package:flatch/views/profile/user_profile.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Bottom-nav order:
//   0 Community  — Stock Farts (guest-ok) + gated community farts. FartsPage
//                  is NOT wrapped in AuthGate: guests see Stock Farts and the
//                  "create an account" gate; it reveals community categories
//                  once signed in.
//   1 FWB        — Farts with Buddies. Gated (private group chat needs an
//                  account).
//   2 Upload     — gated (an account is required to post).
//   3 Bluetooth  — the device connection + slots. Guest-accessible.
//   4 Settings   — guest-accessible. UserProfileScreen shows a reduced,
//                  account-free settings view to guests (theme, legal, about,
//                  buy device) with a "create account" prompt; the full
//                  profile/account options appear once signed in.
List<Widget> _childs = [
  FartsPage(),
  AuthGate(feature: 'use Farts with Buddies', child: FwbHomeScreen()),
  AuthGate(feature: 'share your own sounds', child: UploadFartScreen()),
  FlatchBleScreen(),
  UserProfileScreen(),
];

class UserAppDashboardView extends StatefulWidget {
  final dynamic data;
  const UserAppDashboardView({super.key, this.data});

  @override
  State<UserAppDashboardView> createState() => _UserAppDashboardViewState();
}

class _UserAppDashboardViewState extends State<UserAppDashboardView> {
  @override
  void initState() {
    super.initState();

    navigateWhenStateIsNotEmpty();
  }

  void navigateWhenStateIsNotEmpty() {
    if (widget.data != null && (widget.data as Map).containsKey("navigation")) {
      final int navigationIndex = (widget.data as Map)["navigation"] ?? 0;
      BlocProvider.of<UserAppDashboardCubit>(
        context,
      ).onUpdateIndex(navigationIndex);
    } else {
      // Everyone lands on the far-left module (index 0) — the device + built-in
      // sounds — which guests can use with no account.
      BlocProvider.of<UserAppDashboardCubit>(context).onUpdateIndex(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const KBottomAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            stops: [0.3, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppColors.primary.withOpacity(0.01)],
          ),
        ),
        child: BlocBuilder<UserAppDashboardCubit, UserAppDashboardState>(
          builder: (context, state) {
            final int index = state.index;
            return _childs[index];
          },
        ),
      ),
    );
  }
}

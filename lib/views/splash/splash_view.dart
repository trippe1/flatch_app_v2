// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  String? referralCode;
  bool isReferralCodeProcessed = false;
  bool isFirstVisitCompleted = false;
  @override
  void initState() {
    super.initState();
    navigateAfterDelay();
  }

  Future<void> navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));

    context.goNamed(AppRoute.dashboard.name);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          AppLogo(
            logoSize: height < 700 ? 145 : 180,
            textSize: height < 700 ? 12 : 16,
          ),
        ],
      ),
    );
  }
}

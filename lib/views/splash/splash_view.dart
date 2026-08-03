// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  Timer? _timer;
  bool _navigated = false;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    // Hold for 3 seconds, then move on. A hard Timer (not an awaited future
    // whose context can go stale) guarantees we don't get stuck here. Tapping
    // the screen advances immediately (see the GestureDetector in build).
    _timer = Timer(const Duration(seconds: 3), _advance);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance() {
    if (!mounted || _navigated) return;
    _navigated = true; // guard against tap + timer both firing
    _timer?.cancel();
    // Immediate feedback: for signed-in users the router guard resolves before
    // the screen changes, so show a spinner so the tap visibly "does something".
    setState(() => _advancing = true);
    final signedIn = FirebaseAuth.instance.currentUser != null;
    // Guests → the app (far-left module = built-in sounds). Signed-in users go
    // through the router guard for role/verification routing.
    context.go(signedIn ? AppRoutes.dashboard : AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nearBlack,
      // Tap anywhere to advance. The GestureDetector lives inside the body and
      // covers the full screen (opaque + infinite size), so a tap on any part
      // of the black screen — not just the text — fires _advance.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '"Flatulations are not funny."',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.labWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '— my middle school Asst. Principal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.warmGray,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (_advancing) ...[
                const SizedBox(height: 32),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

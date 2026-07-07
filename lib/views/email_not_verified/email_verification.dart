// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flatch/common/routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _verificationTimer;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();

    _verificationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        _verificationTimer.cancel();

        if (mounted) {
          setState(() => _isEmailVerified = true);

          // Navigate to main screen after verification
          context.goNamed(AppRoute.home.name);
        }
      }
    });
  }

  @override
  void dispose() {
    _verificationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
            _isEmailVerified
                ? const CircularProgressIndicator()
                : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined, size: 64),
                      const SizedBox(height: 20),
                      const Text(
                        'Verify your email to continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'We’ve sent a verification link to your email.\n'
                        'Please check your inbox or spam folder and click the link.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && !user.emailVerified) {
                            await user.sendEmailVerification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verification email sent again!'),
                              ),
                            );
                          }
                        },
                        child: const Text('Resend Email'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();

                          context.goNamed(AppRoute.login.name);
                        },
                        child: const Text(
                          'Entered wrong email? Go back',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

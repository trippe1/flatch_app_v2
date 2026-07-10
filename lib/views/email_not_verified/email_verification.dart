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
  Timer? _cooldownTimer;
  bool _isEmailVerified = false;
  bool _checking = false;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    // Poll gently (was every 2s, forever — a real battery/network drain).
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkVerified(),
    );
  }

  Future<void> _checkVerified() async {
    if (_checking) return;
    if (mounted) setState(() => _checking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        _verificationTimer.cancel();
        _cooldownTimer?.cancel();
        if (mounted) {
          setState(() => _isEmailVerified = true);
          context.goNamed(AppRoute.home.name);
        }
      }
    } catch (_) {
      // transient network error — the next poll retries
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent again!')),
    );
    setState(() => _resendIn = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _verificationTimer.cancel();
    _cooldownTimer?.cancel();
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
                        onPressed: _checking ? null : _checkVerified,
                        child: Text(
                          _checking ? 'Checking…' : "I've verified — continue",
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _resendIn > 0 ? null : _resend,
                        child: Text(
                          _resendIn > 0
                              ? 'Resend email (${_resendIn}s)'
                              : 'Resend Email',
                        ),
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

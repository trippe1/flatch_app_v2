import 'package:flatch/blocs/individual_signup/individual_signup_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/age_gate_service.dart';
import 'package:flatch/common/services/telemetry_service.dart';
import 'package:flatch/common/services/url_services.dart';
import 'package:flatch/common/widgets/social_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Single continuous "create your account" flow:
///   • Step 1 of 2 — verify age (birthdate). Under-13 → permanent block.
///   • Step 2 of 2 — once the date validates, the sign-in options slide up on
///     the same screen (no separate checkpoint). Google/Apple sign in inline;
///     email goes to the email form.
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  DateTime? _birthDate;
  bool _verified = false; // passing birthdate confirmed → reveal step 2
  bool _busy = false; // OAuth in progress

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _onContinue() async {
    final dob = _birthDate;
    if (dob == null) return;

    if (AgeGateService.meetsMinimumAge(dob)) {
      Telemetry.instance.signupStarted();
      // Reveal step 2 in place — no navigation, one continuous motion.
      setState(() => _verified = true);
      return;
    }

    // Under the minimum age: permanently block and show a neutral message.
    await AgeGateService.instance.block();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("You can't create an account"),
            content: const Text(
              "Based on the date you entered, you're not able to create an "
              'account or use community features. You can still use the '
              'device and its built-in sounds.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    context.goNamed(AppRoute.home.name);
  }

  void _handleSignupState(BuildContext context, IndividualSignupState state) {
    if (state is IndividualSignupLoading) {
      setState(() => _busy = true);
    } else if (state is DashboardSuccessState) {
      if (state.trialExpired) {
        context.goNamed(AppRoute.userSubscriptionEnded.name);
      } else {
        context.goNamed(AppRoute.home.name);
      }
    } else if (state is DashboardErrorState || state is IndividualSignupFailure) {
      setState(() => _busy = false);
      final msg =
          state is DashboardErrorState
              ? state.errorMessage
              : 'Sign-in failed. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<IndividualSignupBloc, IndividualSignupState>(
      listener: _handleSignupState,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(title: const Text('Create account / Sign in')),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _StepIndicator(step: _verified ? 2 : 1),
                    const SizedBox(height: 20),
                    const Icon(Icons.cake_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Verify your age',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "We're required by law to verify your age before you "
                      'can create an account.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    // Age verification is only needed to CREATE an account —
                    // an existing user already did it at signup. Offer sign-in
                    // on step 1 so returning users never have to re-verify.
                    TextButton(
                      onPressed: () => context.pushNamed(AppRoute.login.name),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: DefaultTextStyle.of(
                            context,
                          ).style.copyWith(fontSize: 15),
                          children: [
                            TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                            const TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _birthDate == null
                            ? 'Select date of birth'
                            : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.primary),
                      ),
                      // Lock the date once verified.
                      onPressed: _verified ? null : _pickDate,
                    ),
                    const Spacer(),
                    // The pivotal moment: Continue gives way to the sign-in
                    // options, sliding up in place.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: _verified ? _authOptions() : _continueButton(),
                    ),
                    const SizedBox(height: 12),
                    // Secondary action: same fill as the background, just a
                    // border so it still reads as a button. Never "highlighted"
                    // — the Continue button is the only accented control.
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: Colors.transparent,
                        foregroundColor:
                            Theme.of(context).textTheme.bodyMedium?.color,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: AppColors.darkGray.withOpacity(0.7),
                        ),
                      ),
                      onPressed:
                          () => UrlLauncherService.instance.launchPrivacyPolicy(
                            context,
                          ),
                      child: const Text('Privacy Policy'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _continueButton() {
    return ElevatedButton(
      key: const ValueKey('continue'),
      style: ElevatedButton.styleFrom(
        // Force full width — inside the AnimatedSwitcher's Stack the button
        // otherwise collapses to its text width and looks narrower than the
        // Privacy Policy button below it.
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Disabled (no birthdate yet) falls back to the default muted grey,
        // so the accent green only appears once a full date is entered.
        disabledBackgroundColor: AppColors.darkGray.withOpacity(0.25),
        disabledForegroundColor: AppColors.darkGray,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _birthDate == null ? null : _onContinue,
      child: const Text('Continue'),
    );
  }

  Widget _authOptions() {
    return Column(
      key: const ValueKey('auth'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose how to sign up',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SocialButtons(
          onGoogle:
              () => context.read<IndividualSignupBloc>().add(
                GoogleLogin(role: 'User'),
              ),
          onApple:
              () => context.read<IndividualSignupBloc>().add(
                AppleLogin(role: 'User'),
              ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.email_outlined, size: 18),
          label: const Text('Sign up with email'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: AppColors.primary),
          ),
          onPressed: () => context.goNamed(AppRoute.signup.name),
        ),
        const SizedBox(height: 8),
        // Returning users reach this gate too — send them straight to sign-in
        // rather than through the registration form.
        TextButton(
          onPressed: () => context.pushNamed(AppRoute.login.name),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
              children: [
                TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(.7),
                  ),
                ),
                const TextSpan(
                  text: 'Sign In',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Step X of 2" with a two-segment progress bar.
class _StepIndicator extends StatelessWidget {
  final int step; // 1 or 2
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    Widget seg(bool active) => Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    return Column(
      children: [
        Text(
          'Step $step of 2',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [seg(true), const SizedBox(width: 6), seg(step >= 2)],
        ),
      ],
    );
  }
}

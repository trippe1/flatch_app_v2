// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:flatch/blocs/dashboard/dashboard_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/url_services.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/common/widgets/social_buttons.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:gap/gap.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoadingState) {
            return const Center(child: KProgressIndicator());
          } else if (state is DashboardErrorState) {
            return _buildErrorState(context, state.errorMessage);
          } else if (state is DashboardSuccessState) {
            return _buildSuccessState(context, state.user);
          } else {
            return _buildInitialState(context, height);
          }
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    final double height = MediaQuery.of(context).size.height;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Icon(Icons.error, color: Colors.black, size: height * 0.20),
        ),
        const Gap(20),
        const TextWidget(
          text: "Oops! Something went wrong.",
          size: 22,
          weight: FontWeight.bold,
        ),
        const Gap(10),
        TextWidget(
          text: errorMessage,
          color: Colors.black.withOpacity(.6),
          padding: 60,
          textAlign: TextAlign.center,
        ),
        const Gap(30),
        TextButton(
          onPressed:
              () => context.read<DashboardBloc>().add(EmitInitialState()),
          child: const Text("Retry"),
        ),
      ],
    );
  }

  Widget _buildSuccessState(BuildContext context, User user) {
    Timer(const Duration(milliseconds: 200), () {
      while (GoRouter.of(context).canPop()) {
        GoRouter.of(context).pop();
      }
      if (!user.emailVerified) {
        context.read<DashboardBloc>().add(EmitInitialState());
        context.goNamed(AppRoute.emailVerificationScreen.name);
      } else {
        context.read<DashboardBloc>().add(EmitInitialState());
        context.goNamed(AppRoute.home.name);
      }
    });

    final double height = MediaQuery.of(context).size.height;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Image.asset(
            "assets/images/check_mark.png",
            height: height * 0.25,
          ),
        ),
        const Gap(20),
        const TextWidget(text: "Success!", size: 22, weight: FontWeight.bold),
        TextWidget(
          text: "Your Flatch account is ready! Redirecting shortly...",
          color: Colors.black.withOpacity(.6),
          padding: 60,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInitialState(BuildContext context, double height) {
    final bool isCompact = height < 700;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: height < 813 ? 60 : 80,
        left: 40,
        right: 40,
      ),
      children: [
        Gap(height < 813 ? 60 : 80),
        const Center(
          child: TextWidget(
            text: "Welcome to Flatch!",
            textAlign: TextAlign.center,
            size: 24,
            weight: FontWeight.w800,
            maxLines: 3,
          ),
        ),
        const Gap(16),
        const Center(
          child: TextWidget(
            text:
                "Record, share, and rate the funniest farts on the planet.\nLet the games begin!",
            textAlign: TextAlign.center,
            color: Colors.grey,
            size: 16,
            maxLines: 3,
          ),
        ),
        Gap(height < 813 ? 35 : 40),

        /// Social login buttons
        SocialButtons(
          onApple: () => context.read<DashboardBloc>().add(AppleLogin()),
          onGoogle: () => context.read<DashboardBloc>().add(GoogleLogin()),
        ),

        const Gap(50),

        /// Signup Button
        Center(
          child: TextButton(
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(
                Size(double.infinity, isCompact ? 35 : 45),
              ),
              backgroundColor: const MaterialStatePropertyAll(
                AppColors.primary,
              ),
              foregroundColor: const MaterialStatePropertyAll(Colors.white),
            ),
            onPressed:
                () => GoRouter.of(context).pushNamed(AppRoute.signup.name),
            child: const Text("SIGN UP"),
          ),
        ),
        Gap(isCompact ? 5 : 15),

        /// Login Button
        Center(
          child: TextButton(
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(
                Size(double.infinity, isCompact ? 35 : 45),
              ),
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              foregroundColor: const MaterialStatePropertyAll(
                AppColors.primary,
              ),
              side: const MaterialStatePropertyAll(
                BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
            onPressed:
                () => GoRouter.of(context).pushNamed(AppRoute.login.name),
            child: const Text("LOGIN"),
          ),
        ),
        Gap(isCompact ? 30 : 40),

        /// Terms and privacy
        Center(
          child: Text.rich(
            TextSpan(
              children: List.generate(4, (index) {
                final theme = Theme.of(context);
                final isLink = index == 1 || index == 3;

                return TextSpan(
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap = () {
                          if (index == 1) {
                            UrlLauncherService.instance.launchPrivacyPolicy(
                              context,
                            );
                          } else if (index == 3) {
                            UrlLauncherService.instance
                                .launchTermsAndConditions(context);
                          }
                        },
                  text:
                      index == 0
                          ? "By using Flatch, you agree to our "
                          : index == 1
                          ? "Privacy Policy "
                          : index == 2
                          ? "and "
                          : "Terms & Conditions",
                  style: TextStyle(
                    color:
                        isLink
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                    fontSize:
                        MediaQuery.of(context).size.height < 813 ? 16 : 18,
                  ),
                );
              }),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

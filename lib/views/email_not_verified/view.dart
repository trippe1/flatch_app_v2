// ignore_for_file: use_build_context_synchronously

import 'package:flatch/blocs/email_not_verified/email_not_verified_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/firebase_auth_error_widget.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EmailNotVerifiedView extends StatelessWidget {
  const EmailNotVerifiedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<EmailNotVerifiedBloc, EmailNotVerifiedState>(
        builder: (context, state) {
          if (state is EmailNotVerifiedInitialState) {
            return initialState(context);
          } else if (state is EmailNotVerifiedLoadingState) {
            return const Center(child: KProgressIndicator());
          } else if (state is EmailNotVerifiedErrorState) {
            return FirebaseAuthError(
              error: state.e,
              ontap: () {
                context.read<EmailNotVerifiedBloc>().add(
                  EmailNotVerifiedVeifyEvent(),
                );
              },
            );
          } else if (state is EmailNotVerifiedInvalidEmailState) {
            return invalidEmailState(context);
          } else {
            final User? user = FirebaseAuth.instance.currentUser;
            return successState(context, user);
          }
        },
      ),
    );
  }

  /// 🟢 UI when email verification is sent successfully
  Widget successState(BuildContext context, User? user) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(child: Image.asset("assets/images/check_mark.png", height: 200)),
        const Gap(30),
        const TextWidget(
          text: "Verification Email Sent!",
          color: AppColors.secondary,
          size: 28,
          weight: FontWeight.w800,
        ),
        const Gap(20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextWidget(
            text:
                "A verification email 📧 has been sent to your email address, ${user != null ? user.email : ""}. Please check your inbox and log in again.",
            size: 18,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(40),
        TextButton(
          onPressed: () async {
            context.read<EmailNotVerifiedBloc>().add(ResetStateEvent());
            await FirebaseAuth.instance.signOut();
            context.goNamed(AppRoute.login.name);
          },
          child: const Text("Login Now"),
        ),
        const Gap(60),
      ],
    );
  }

  /// 🟠 UI when the user's email is invalid
  Widget invalidEmailState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Gap(40),
        const TextWidget(
          text: "Check Your Email",
          size: 24,
          color: AppColors.secondary,
          weight: FontWeight.w700,
          padding: 60,
          textAlign: TextAlign.center,
        ),
        const Gap(20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 50),
          child: TextWidget(
            text:
                "Your email may have a typo. Please check the spelling and try sending "
                "the verification email again. If the issue persists, you can enter a new email.",
            size: 18,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(40),
        TextButton(
          onPressed: () {
            context.read<EmailNotVerifiedBloc>().add(
              EmailNotVerifiedVeifyEvent(),
            );
          },
          child: const Text("Resend Verification Email"),
        ),
        const Gap(20),
        TextButton(
          onPressed: () {
            final TextEditingController emailController =
                TextEditingController();
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text("Enter New Email"),
                    content: TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: "Enter your email",
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          final newEmail = emailController.text.trim();
                          if (newEmail.isNotEmpty) {
                            context.read<EmailNotVerifiedBloc>().add(
                              EmailNotVerifiedVeifyRetryEvent(newEmail),
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text("Update & Verify"),
                      ),
                    ],
                  ),
            );
          },
          child: const Text("Enter a Different Email"),
        ),
        const Gap(50),
      ],
    );
  }

  Column initialState(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Gap(40),
        const TextWidget(
          text: "Please Verify Your Email Address",
          size: 24,
          color: AppColors.primary,
          weight: FontWeight.w700,
          padding: 60,
          textAlign: TextAlign.center,
        ),
        const Gap(20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: TextWidget(
            text:
                "Almost there! Click on 'Verify My Email' to receive a verification link in your inbox 📧 (${user != null ? user.email : ""}).",
            size: 18,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(40),
        TextButton(
          onPressed:
              () => context.read<EmailNotVerifiedBloc>().add(
                EmailNotVerifiedVeifyEvent(),
              ),
          child: const Text("Verify My Email"),
        ),
        const Gap(50),
      ],
    );
  }
}

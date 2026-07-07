// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flatch/blocs/login_bloc/login_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/extensions/email_validator.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/common/widgets/social_buttons.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/common/widgets/text_field_with_text.dart';
import 'package:flatch/cubits/login/company_login_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    // Reset and check if already logged in when dependencies change
    context.read<LoginBloc>().add(ResetStateEvent());
    context.read<LoginBloc>().add(CheckIfAlreadyLoggedInEvent());
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) async {
        if (state is LoginFailureState) {
          // Show error dialog
          showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text("Login Failed"),
                  content: Text(
                    'Please check your email or password and try again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("OK"),
                    ),
                  ],
                ),
          );
        } else if (state is LoginSuccessState) {
          final user = state.user;
          await Future.delayed(Duration.zero);
          if (!user.emailVerified) {
            context.goNamed(AppRoute.emailNotVerified.name);
          } else if (state.trialExpired) {
            context.goNamed(AppRoute.userSubscriptionEnded.name);
          } else {
            context.goNamed(AppRoute.dashboard.name);
          }
          context.read<LoginBloc>().add(ResetStateEvent());
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              buildForm(context, state),
              if (state is LoginLoadingState)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: KProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget buildForm(BuildContext context, LoginState state) {
    final double screenHeight = context.screenHeight;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(left: 40, right: 40, top: 50),
        children: [
          const Gap(30),
          Align(
            alignment: Alignment.bottomLeft,
            child: TextWidget(
              text: "Login Account",
              textAlign: TextAlign.center,
              size: screenHeight < 813 ? 20 : 24,
              weight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const Gap(10),
          Align(
            alignment: Alignment.bottomLeft,
            child: TextWidget(
              text: "Please login with registered account",
              size: screenHeight < 813 ? 12 : 14,
              weight: FontWeight.w700,
              textAlign: TextAlign.center,
              color: Colors.grey,
            ),
          ),
          const Gap(60),
          TextFormFieldWithText(
            prefixIcon: const Icon(
              CupertinoIcons.mail,
              color: AppColors.primary,
            ),
            controller: emailController,
            heading: "Email Address",
            hint: "Valid email address",
            validator: (p0) => p0!.trim().isValidEmail(),
          ),
          const Gap(20),
          BlocBuilder<LoginCubit, LoginCubitState>(
            builder: (context, cubitState) {
              final bool isObsecure = cubitState.isObsecure;
              return TextFormFieldWithText(
                controller: passwordController,
                prefixIcon: const Icon(
                  CupertinoIcons.lock,
                  color: AppColors.primary,
                ),
                heading: "Password",
                hint: "Use strong password",
                obsecure: isObsecure,
                validator: (p0) {
                  if (p0!.trim().isEmpty) {
                    return "Password can't be empty";
                  }
                  return null;
                },
                suffix: IconButton(
                  onPressed:
                      () =>
                          context.read<LoginCubit>().onUnobsecure(!isObsecure),
                  icon: Icon(
                    isObsecure ? CupertinoIcons.lock : CupertinoIcons.lock_open,
                  ),
                  style: const ButtonStyle().copyWith(
                    backgroundColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                  ),
                ),
              );
            },
          ),
          const Gap(10),
          TextButton(
            onPressed: () {
              context.pushNamed(AppRoute.forgotPasswordView.name);
            },
            style: const ButtonStyle().copyWith(
              backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              side: const WidgetStatePropertyAll(BorderSide.none),
              alignment: Alignment.topRight,
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
              textStyle: WidgetStatePropertyAll(style(weight: FontWeight.bold)),
            ),
            child: Text(
              "Forgot Password?",
              style: style(size: screenHeight < 700 ? 12 : 14),
            ),
          ),
          const Gap(5),
          TextButton(
            onPressed:
                (state is LoginLoadingState)
                    ? null
                    : () {
                      FocusScope.of(context).unfocus();
                      if (_formKey.currentState!.validate()) {
                        context.read<LoginBloc>().add(
                          DoLoginEvent(
                            email: emailController.value.text.trim(),
                            password: passwordController.value.text.trim(),
                          ),
                        );
                      }
                    },
            child: Text(
              "LOGIN",
              style: style(size: screenHeight < 700 ? 16 : 18),
            ),
          ),
          const Gap(30),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextWidget(
                  text: "Or",
                  color: Colors.grey.shade500,
                  weight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 1),
              ),
            ],
          ),
          const Gap(20),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextWidget(
                text: "Login With Google or Apple",
                color: Colors.grey.shade500,
                weight: FontWeight.w500,
              ),
            ),
          ),
          const Gap(30),
          SocialButtons(
            onApple: () => context.read<LoginBloc>().add(AppleLoginEvent()),
            onGoogle: () => context.read<LoginBloc>().add(GoogleLoginEvent()),
          ),
          const Gap(30),
          Center(
            child: Text.rich(
              TextSpan(
                children: List.generate(
                  2,
                  (index) => TextSpan(
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = () {
                            if (index == 1) {
                              context.goNamed(AppRoute.signup.name);
                            }
                          },
                    text: index == 0 ? "Don't have an account? " : "Sign up",
                    style: style(
                      color:
                          index == 1
                              ? AppColors.primary
                              : Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(.6),
                      size: screenHeight < 700 ? 14 : 16,
                      weight: index == 1 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Gap(40),
        ],
      ),
    );
  }
}

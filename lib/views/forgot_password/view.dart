import 'package:flatch/blocs/forgot_password/forgot_password_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/extensions/email_validator.dart';
import 'package:flatch/common/widgets/progress_indicator.dart'
    show KProgressIndicator;
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/common/widgets/text_field_with_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          style: const ButtonStyle().copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),

            side: const WidgetStatePropertyAll(BorderSide.none),
          ),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<ForgotPasswordBloc>().add(ResetStateEvent());
            Navigator.of(context).pop();
          },
        ),

        leadingWidth: 120,
        bottom: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 60),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: "Forgot Password",
                  padding: 20,
                  size: 22,
                  color: AppColors.primary,
                  weight: FontWeight.bold,
                ),
                TextWidget(
                  text:
                      "Please enter your email address to reset your password",
                  padding: 20,
                ),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<ForgotPasswordBloc, ForgotPasswordState>(
        builder: (context, state) {
          switch (state) {
            case ForgotPasswordInitial():
              return initialState();
            case ForgotPasswordLoading():
              return const Center(child: KProgressIndicator());
            case ForgotPasswordAccountNotFound():
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Icon(
                      Icons.person_off_outlined,
                      color: AppColors.primary,
                      size: MediaQuery.of(context).size.width * 0.22,
                    ),
                  ),
                  const Gap(10),
                  const TextWidget(
                    text: "No account found",
                    size: 22,
                    weight: FontWeight.bold,
                  ),
                  const Gap(20),
                  TextWidget(
                    text:
                        "There's no Flatch account for ${state.email}, so we "
                        "didn't send a reset email. Check the address for "
                        "typos, or create an account.",
                    padding: 40,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(30),
                  TextButton(
                    onPressed:
                        () => context.read<ForgotPasswordBloc>().add(
                          ResetStateEvent(),
                        ),
                    child: const Text("Try a different email"),
                  ),
                  TextButton(
                    onPressed: () {
                      context.read<ForgotPasswordBloc>().add(ResetStateEvent());
                      GoRouter.of(context).pop();
                    },
                    child: const Text("Back to Login"),
                  ),
                ],
              );
            case ForgotPasswordError():
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Icon(
                      Icons.error_outline,
                      color: AppColors.primary,
                      size: MediaQuery.of(context).size.width * 0.22,
                    ),
                  ),
                  const Gap(10),
                  const TextWidget(
                    text: "Couldn't send the email",
                    size: 22,
                    weight: FontWeight.bold,
                  ),
                  const Gap(20),
                  TextWidget(
                    text: state.message,
                    padding: 40,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(30),
                  TextButton(
                    onPressed: () {
                      context.read<ForgotPasswordBloc>().add(
                        SendCodeEvent(email: emailController.value.text.trim()),
                      );
                    },
                    child: const Text("Retry"),
                  ),
                  TextButton(
                    onPressed:
                        () => context.read<ForgotPasswordBloc>().add(
                          ResetStateEvent(),
                        ),
                    child: const Text("Use a different email"),
                  ),
                ],
              );
            case ForgotPasswordSuccess():
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.black,
                      size: MediaQuery.of(context).size.width * 0.25,
                    ),
                  ),

                  const Gap(10),
                  const TextWidget(
                    text: "Reset email sent.",
                    size: 22,
                    weight: FontWeight.bold,
                  ),
                  const Gap(20),
                  TextWidget(
                    text:
                        "An email with instructions has been sent to your email ${emailController.value.text.trim()}",
                    padding: 60,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(40),
                  TextButton(
                    child: const Text("Back to Login"),
                    onPressed: () {
                      context.read<ForgotPasswordBloc>().add(ResetStateEvent());
                      GoRouter.of(context).pop();
                    },
                  ),
                ],
              );
          }
        },
      ),
    );
  }

  Form initialState() {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.only(top: 30, left: 20, right: 20),
        children: [
          TextFormFieldWithText(
            heading: "Email Address",
            hint: "Enter your valid email address",
            validator: (p0) => p0!.trim().isValidEmail(),
            controller: emailController,
            prefixIcon: const Icon(
              CupertinoIcons.mail,
              color: AppColors.primary,
            ),
          ),
          const Gap(30),
          Center(
            child: TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  context.read<ForgotPasswordBloc>().add(
                    SendCodeEvent(email: emailController.value.text.trim()),
                  );
                }
              },
              child: const Text("Send Link"),
            ),
          ),
        ],
      ),
    );
  }
}

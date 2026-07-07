// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/extensions/password_validator.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/firebase_auth_error_widget.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/common/widgets/text_field_with_text.dart';
import 'package:flatch/cubits/user_app_update_password/user_app_update_password_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class UserAppUpdatePasswordView extends StatefulWidget {
  const UserAppUpdatePasswordView({super.key});

  @override
  State<UserAppUpdatePasswordView> createState() =>
      _UserAppUpdatePasswordViewState();
}

class _UserAppUpdatePasswordViewState extends State<UserAppUpdatePasswordView> {
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final GlobalKey<FormState> key = GlobalKey<FormState>();
  final FocusNode passwordFocusNode = FocusNode();

  @override
  void dispose() {
    passwordFocusNode.dispose();
    passwordFocusNode.unfocus();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          style: ButtonStyle().copyWith(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStatePropertyAll(BorderSide.none),
          ),
          onPressed: () => GoRouter.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: BlocBuilder<UserAppUpdatePasswordCubit, UserAppUpdatePasswordState>(
        builder: (context, state) {
          if (state is UpdateUserAppPasswordErrorState) {
            return FirebaseAuthError(
              error: state.error,
              ontap: () => context.read<UserAppUpdatePasswordCubit>().onRetry(),
            );
          } else if (state is UpdateUserAppPasswordLoadingState) {
            return const Center(child: KProgressIndicator());
          } else if (state is UpdateUserAppPasswordSuccessState) {
            Timer(const Duration(seconds: 2), () async {
              await FirebaseAuth.instance.signOut();
              GoRouter.of(
                // ignore: use_build_context_synchronously
                context,
              ).pushReplacementNamed(AppRoute.dashboard.name);
            });
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    "assets/images/check_mark.png",
                    height: 200,
                    width: 200,
                  ),
                ),
                const Gap(20),
                const TextWidget(
                  text: "Success",
                  weight: FontWeight.bold,
                  size: 22,
                ),
                const Gap(15),
                const TextWidget(
                  text: "Password updated successfully, please login again",
                ),
              ],
            );
          } else {
            return initialState(context);
          }
        },
      ),
    );
  }

  Form initialState(BuildContext context) {
    return Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
        children: [
          // Center(
          //     child: Image.asset("assets/images/lock.png",
          //         height: 200, width: 200)),
          const Gap(20),
          BlocBuilder<UserAppUpdatePasswordCubit, UserAppUpdatePasswordState>(
            builder: (context, state) {
              final bool obsecure = state.obsecureCurrentPassword;
              return TextFormFieldWithText(
                suffix: GestureDetector(
                  onTap:
                      () => context
                          .read<UserAppUpdatePasswordCubit>()
                          .unObsecureCurrent(!obsecure),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Optional: adds rounded corners
                    ),
                    alignment:
                        Alignment
                            .center, // Center the icon inside the container
                    child: Icon(
                      obsecure ? CupertinoIcons.lock : CupertinoIcons.lock_open,
                      size: 20, // Icon size remains unchanged
                    ),
                  ),
                ),
                obsecure: obsecure,
                controller: currentPasswordController,
                validator:
                    (p0) => p0!.trim().isEmpty ? "Password is required" : null,
                heading: "Current Password",
                hint: "Please enter your current password",
              );
            },
          ),
          const Gap(15),
          BlocBuilder<UserAppUpdatePasswordCubit, UserAppUpdatePasswordState>(
            builder: (context, state) {
              final bool obsecure = state.obsecureNewPassword;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormFieldWithText(
                    suffix: GestureDetector(
                      onTap:
                          () => context
                              .read<UserAppUpdatePasswordCubit>()
                              .unObsecureNew(!obsecure),
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          obsecure
                              ? CupertinoIcons.lock
                              : CupertinoIcons.lock_open,
                          size: 20,
                        ),
                      ),
                    ),
                    heading: "New Password",
                    hint: "Please enter your new password",
                    obsecure: obsecure,
                    focusNode: passwordFocusNode,
                    validator: (p0) => p0!.trim().isValidPassword(),
                    controller: newPasswordController,
                    onChanged:
                        (value) => context
                            .read<UserAppUpdatePasswordCubit>()
                            .validatePassword(value),
                  ),
                  if (state is PasswordValidationState &&
                      passwordFocusNode.hasFocus)
                    showPasswordErrors(state, context),
                ],
              );
            },
          ),
          const Gap(30),
          Center(
            child: TextButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  passwordFocusNode.unfocus();
                  context.read<UserAppUpdatePasswordCubit>().onUpdatePassword(
                    currentPasswordController.value.text.trim(),
                    newPasswordController.value.text.trim(),
                  );
                }
              },
              style: const ButtonStyle().copyWith(
                overlayColor: WidgetStatePropertyAll(
                  AppColors.secondary.withOpacity(0.3),
                ),
                minimumSize: const MaterialStatePropertyAll(
                  Size(double.infinity, 55),
                ),
              ),
              child: const Text("Update"),
            ),
          ),
        ],
      ),
    );
  }

  Widget showPasswordErrors(
    PasswordValidationState state,
    BuildContext context,
  ) {
    double screenHeight = MediaQuery.of(context).size.height;

    Widget buildConditionRow(bool condition, String text) {
      return Row(
        children: [
          Icon(
            condition ? Icons.check_circle : Icons.cancel,
            color: condition ? Colors.green : Colors.red,
            size: screenHeight < 700 ? 16 : 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: screenHeight < 700 ? 12 : 14,
              color: condition ? Colors.green : Colors.red,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight < 700 ? 12 : 20),
          buildConditionRow(
            state.usedCapitalLetter,
            "Must include one uppercase letter",
          ),
          buildConditionRow(
            state.usedLowerCase,
            "Must include one lowercase letter",
          ),
          buildConditionRow(
            state.eightOfLength,
            "Must be at least 8 characters long",
          ),
          buildConditionRow(
            state.usedNumber,
            "Must include at least one numeric digit",
          ),
          buildConditionRow(
            state.usedSpecialCharacter,
            "Must include at least one special character",
          ),
        ],
      ),
    );
  }
}

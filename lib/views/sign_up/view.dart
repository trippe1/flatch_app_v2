// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:flatch/blocs/individual_signup/individual_signup_bloc.dart';
import 'package:flatch/blocs/login_bloc/login_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/extensions/email_validator.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/extensions/password_validator.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/url_services.dart';
import 'package:flatch/common/widgets/check_box_with_text.dart';
import 'package:flatch/common/widgets/firebase_auth_error_widget.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/common/widgets/social_buttons.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/common/widgets/text_field_with_text.dart';
import 'package:flatch/cubits/Individual_signup/individual_signup_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class IndividualSignup extends StatefulWidget {
  const IndividualSignup({super.key});

  @override
  State<IndividualSignup> createState() => _IndividualSignupState();
}

class _IndividualSignupState extends State<IndividualSignup> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final FocusNode passwordFocusNode = FocusNode();
  final TextEditingController descriptionController = TextEditingController();

  String countryValue = "";
  String stateValue = "";
  String? nameError;

  bool showPasswordErrorsState = false;

  bool agreedToTermsAndConditions = false;
  final TextEditingController companyCodeController = TextEditingController();
  final GlobalKey _nameFieldKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    BlocProvider.of<IndividualSignupBloc>(context).add(IndividualSignupRetry());

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final signupCubit = BlocProvider.of<IndividualSignupCubit>(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 120,
        leading: IconButton(
          style: const ButtonStyle().copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            side: const WidgetStatePropertyAll(BorderSide.none),
          ),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: BlocBuilder<IndividualSignupBloc, IndividualSignupState>(
        builder: (context, state) {
          if (state is DashboardSuccessState) {
            final User user = state.user;

            Timer(const Duration(milliseconds: 100), () async {
              if (!user.emailVerified) {
                context.goNamed(AppRoute.emailVerificationScreen.name);
              } else {
                final bool trialExpired = state.trialExpired;

                if (trialExpired) {
                  context.goNamed(AppRoute.userSubscriptionEnded.name);
                } else {
                  context.goNamed(AppRoute.home.name);
                }
              }
              BlocProvider.of<LoginBloc>(context).add(ResetStateEvent());
            });

            return const SizedBox();
          }
          if (state is IndividualSignupInitial) {
            return initialState(signupCubit, context, state);
          } else if (state is IndividualSignupLoading) {
            return const Center(child: KProgressIndicator());
          } else if (state is IndividualSignupFailure) {
            return FirebaseAuthError(
              error: state.exception,
              ontap: () {
                nameController.clear();
                passwordController.clear();
                emailController.clear();
                context.read<IndividualSignupBloc>().add(
                  IndividualSignupRetry(),
                );
              },
            );
          } else if (state is IndividualSignupSuccess) {
            final User user = state.user;
            Timer(const Duration(milliseconds: 100), () {
              if (!user.emailVerified) {
                context.goNamed(AppRoute.emailVerificationScreen.name);
              }
            });
            return const SizedBox();
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }

  Form initialState(
    IndividualSignupCubit signupCubit,
    BuildContext context,
    IndividualSignupInitial state,
  ) {
    double screenHeight = context.screenHeight;
    return Form(
      key: formKey,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: screenHeight < 700 ? 5 : 10,
          left: 40,
          right: 40,
        ),
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: TextWidget(
              text: "Create Account",
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
              text: "Create your account to join the community",
              size: screenHeight < 813 ? 12 : 14,
              weight: FontWeight.w700,
              textAlign: TextAlign.center,
              color: Colors.grey,
            ),
          ),
          const Gap(16),
          // Returning users land here from the age gate, so give them a way out
          // without scrolling the whole registration form.
          Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextWidget(
                  text: "Already have an account?",
                  size: screenHeight < 813 ? 12 : 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(.7),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    while (GoRouter.of(context).canPop()) {
                      GoRouter.of(context).pop();
                    }
                    GoRouter.of(context).pushNamed(AppRoute.login.name);
                  },
                  child: Text(
                    "Sign In",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: screenHeight < 813 ? 13 : 15,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(18),

          TextFormFieldWithText(
            controller: nameController,
            textError: nameError,
            heading: "Username",
            hint: "Pick a username others will see",
            prefixIcon: const Icon(
              CupertinoIcons.at,
              color: AppColors.primary,
            ),
            key: _nameFieldKey,
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) {
                return "Username is required";
              } else if (v.length < 3) {
                return "Username must be at least 3 characters";
              } else if (v.length > 20) {
                return "Username must be 20 characters or fewer";
              } else if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v)) {
                return "Use letters, numbers, underscores or periods only";
              }
              return null;
            },
          ),

          const Gap(20),
          TextFormFieldWithText(
            prefixIcon: const Icon(
              CupertinoIcons.mail,
              color: AppColors.primary,
            ),
            validator: (p0) => p0!.isValidEmail(),
            controller: emailController,
            heading: "Email Address",
            hint: "Enter a valid email address",
          ),

          if (showPasswordErrorsState) const Gap(20),
          const Gap(20),
          TextFormFieldWithText(
            controller: descriptionController,
            heading: "Description",
            hint: "Tell us about yourself",
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Description is required";
              } else if (value.trim().length > 200) {
                return "Description must be under 200 characters";
              }
              return null;
            },
          ),
          const Gap(20),
          TextWidget(
            text: "Select Country & State",
            weight: FontWeight.w600,
            size: 14,
            color: AppColors.primary,
          ),
          const Gap(10),
          CSCPickerPlus(
            selectedItemStyle: TextStyle(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            dropdownItemStyle: TextStyle(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
              fontSize: 12,
            ),
            dropdownHeadingStyle: TextStyle(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),

            defaultCountry: CscCountry.United_States,
            dropdownDecoration: BoxDecoration(
              color: AppColors.lightPrimary, // dropdown background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.transparent, // remove default border
                width: 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            disabledDropdownDecoration: BoxDecoration(
              color: AppColors.lightPrimary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.transparent),
            ), // arrow color
            showCities: false, // hide city
            flagState: CountryFlag.ENABLE,
            countryStateLanguage: CountryStateLanguage.englishOrNative,

            onCountryChanged: (value) {
              setState(() {
                countryValue = value;
              });
            },
            onStateChanged: (value) {
              setState(() {
                stateValue = value ?? '';
              });
            },
            onCityChanged: (value) {},
          ),
          const Gap(20),

          BlocBuilder<IndividualSignupCubit, KIndividualSignupState>(
            builder: (context, state) {
              bool obsecure = state.obsecurePassword;
              return TextFormFieldWithText(
                controller: passwordController,
                focusNode: passwordFocusNode,
                validator: (p0) => p0!.isValidPassword(),
                heading: "Password",
                hint: "Use a strong password",
                prefixIcon: const Icon(
                  CupertinoIcons.lock,
                  color: AppColors.primary,
                ),

                obsecure: obsecure,
                suffix: InkWell(
                  onTap: () => signupCubit.onUnobsecure(!obsecure),
                  child: Icon(
                    obsecure ? CupertinoIcons.lock : CupertinoIcons.lock_open,
                  ),
                ),
              );
            },
          ),
          const Gap(10),
          BlocBuilder<IndividualSignupCubit, KIndividualSignupState>(
            builder: (context, state) {
              bool obsecure = state.obsecurePassword;
              return TextFormFieldWithText(
                controller: confirmPasswordController,

                validator: (p0) {
                  if (p0 == null || p0.isEmpty) {
                    return "Please confirm your password";
                  } else if (p0 != passwordController.text) {
                    return "Passwords do not match.";
                  }
                  return null;
                },
                heading: "Confirm Password",
                hint: "enter password again",
                prefixIcon: const Icon(
                  CupertinoIcons.lock,
                  color: AppColors.primary,
                ),
                obsecure: obsecure,
                suffix: InkWell(
                  onTap: () => signupCubit.onUnobsecure(!obsecure),
                  child: Icon(
                    obsecure ? CupertinoIcons.lock : CupertinoIcons.lock_open,
                  ),
                ),
              );
            },
          ),

          const Gap(30),
          BlocBuilder<IndividualSignupCubit, KIndividualSignupState>(
            builder: (context, state) {
              bool ischecked = state.agreeToTerms;
              agreedToTermsAndConditions = state.agreeToTerms;

              final baseTextColor = Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(.6);

              return CheckBoxWithText(
                onTap: () => signupCubit.setAgreeToTerms(!ischecked),
                isChecked: ischecked,
                widget: RichText(
                  text: TextSpan(
                    style: style(
                      size: screenHeight < 813 ? 14 : 16,
                      color: baseTextColor,
                    ),
                    children: [
                      const TextSpan(text: "You agreed to "),
                      TextSpan(
                        text: "Terms & Conditions",
                        style: style(
                          size: screenHeight < 813 ? 14 : 16,
                          color: AppColors.primary, // keep accent color
                          weight: FontWeight.w600,
                        ),
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () async {
                                await UrlLauncherService.instance
                                    .launchTermsAndConditions(context);
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Gap(screenHeight < 700 ? 10 : 15),
          // BlocBuilder<IndividualSignupCubit, KIndividualSignupState>(
          //   builder: (context, state) {
          //     bool isCheck = state.sendMarketingContent;
          //     return CheckBoxWithText(
          //       text: "Send me marketing content",
          //       isChecked: isCheck,
          //       onTap: () => signupCubit.sendMarktingContent(!isCheck),
          //     );
          //   },
          // ),
          Gap(screenHeight < 813 ? 15 : 20),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                if (agreedToTermsAndConditions) {
                  final snapshot =
                      await FirebaseFirestore.instance
                          .collection("app_users")
                          .where("name", isEqualTo: nameController.text.trim())
                          .limit(1)
                          .get();

                  if (snapshot.docs.isNotEmpty) {
                    setState(() {
                      nameError = "This username is already taken";
                    });
                    Scrollable.ensureVisible(
                      _nameFieldKey.currentContext!,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: 0.1,
                    );
                    return;
                  } else {
                    setState(() {
                      nameError = null;
                    });
                  }

                  context.read<IndividualSignupBloc>().add(
                    IndividualSignupStartedEvent(
                      email: emailController.value.text.trim(),
                      password: passwordController.value.text.trim(),
                      name: nameController.value.text.trim(),
                      role: 'User',
                      description: descriptionController.value.text.trim(),
                      state: stateValue,
                      country: countryValue,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please accept Terms & Conditions and try again",
                      ),
                      margin: EdgeInsets.only(left: 30, right: 30, bottom: 20),
                    ),
                  );
                }
              }
            },
            child: Text(
              "signup".toUpperCase(),
              style: style(size: screenHeight < 700 ? 16 : 18),
            ),
          ),
          Gap(screenHeight < 700 ? 5 : 20),
          const Gap(30),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.grey.shade300, // Adjust color if needed
                  thickness: 1, // Adjust thickness if needed
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextWidget(
                  text: "Or",

                  color: Colors.grey.shade500, // Adjust text color if needed
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
            onApple:
                () => context.read<IndividualSignupBloc>().add(
                  AppleLogin(role: 'User'),
                ),
            onGoogle:
                () => context.read<IndividualSignupBloc>().add(
                  GoogleLogin(role: 'User'),
                ),
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
                              while (GoRouter.of(context).canPop()) {
                                GoRouter.of(context).pop();
                              }
                              GoRouter.of(
                                context,
                              ).pushNamed(AppRoute.login.name);
                            }
                          },
                    text: index == 0 ? "Already have an account? " : "Log In",
                    style: style(
                      color:
                          index == 1
                              ? AppColors.primary
                              : Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(.6),
                      size: screenHeight < 700 ? 12 : 16,
                      weight: index == 1 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Gap(30),
        ],
      ),
    );
  }
}

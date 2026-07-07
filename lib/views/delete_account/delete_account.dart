// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flatch/blocs/delete_my_account/delete_my_account_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/firebase_auth_error_widget.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/common/widgets/text_field_with_text.dart';
import 'package:flatch/cubits/delete_user_account/delete_user_account_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DeleteUserAccountView extends StatefulWidget {
  const DeleteUserAccountView({super.key});

  @override
  State<DeleteUserAccountView> createState() => _DeleteUserAccountViewState();
}

class _DeleteUserAccountViewState extends State<DeleteUserAccountView> {
  final controller = TextEditingController();
  final key = GlobalKey<FormState>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 120,
        leading: OutlinedButton.icon(
          onPressed: () => GoRouter.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text("Back"),
        ),
        bottom: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 40),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: "Delete Account",
                  padding: 20,
                  size: 22,
                  weight: FontWeight.bold,
                ),
                TextWidget(text: "Delete your account,", padding: 20),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<DeleteMyAccountBloc, DeleteMyAccountState>(
        builder: (context, state) {
          switch (state) {
            case DeleteMyAccountInitial():
              return initialState(context);
            case DeleteMyAccountLoadingState():
              return const Center(child: KProgressIndicator());
            case DeleteMyAccountErrorState():
              return FirebaseAuthError(
                error: state.error,
                ontap: () {
                  controller.clear();
                  context.read<DeleteMyAccountBloc>().add(
                    RetryDeleteMyUserAccountEvent(),
                  );
                },
              );
            case DeleteMyAccountSuccessState():
              return Builder(
                builder: (context) {
                  Timer(const Duration(milliseconds: 200), () {
                    context.goNamed(AppRoute.intro.name);
                  });
                  return const SizedBox();
                },
              );
          }
        },
      ),
    );
  }

  Form initialState(BuildContext context) {
    return Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 40),
        children: [
          BlocBuilder<DeleteUserAccountCubit, DeleteUserAccountCubitState>(
            builder: (context, state) {
              final bool obsecure = state.obsecure;
              return TextFormFieldWithText(
                controller: controller,
                heading: "Password",
                hint: "Please enter your password",
                validator:
                    (p0) => p0!.trim().isEmpty ? "Password is required" : null,
                obsecure: obsecure,
                suffix: IconButton(
                  onPressed:
                      () => context.read<DeleteUserAccountCubit>().onUnobsecure(
                        !obsecure,
                      ),
                  icon: Icon(
                    obsecure ? CupertinoIcons.lock : CupertinoIcons.lock_open,
                  ),
                  style: const ButtonStyle().copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(35, 35)),
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    backgroundColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                  ),
                ),
              );
            },
          ),
          const Gap(20),
          Center(
            child: TextButton(
              onPressed: () async {
                if (key.currentState!.validate()) {
                  final confirm = await showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Are you sure?'),
                          content: const Text(
                            'This action will permanently delete your account.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ).copyWith(
                                side: WidgetStateProperty.all(
                                  const BorderSide(
                                    color: AppColors.primary,
                                  ), // Border for Cancel
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                context.read<DeleteMyAccountBloc>().add(
                                  DeleteMyUserAccountEvent(
                                    password: controller.text.trim(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true) {
                    context.read<DeleteMyAccountBloc>().add(
                      DeleteMyUserAccountEvent(
                        password: controller.value.text.trim(),
                      ),
                    );
                  }
                }
              },

              child: const Text("Delete My Account"),
            ),
          ),
        ],
      ),
    );
  }
}

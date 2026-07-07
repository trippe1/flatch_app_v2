import 'package:flatch/blocs/update_username/updateusername_bloc.dart';
import 'package:flatch/common/widgets/progress_indicator.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/common/widgets/text_field_with_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class UpdateUsernameView extends StatefulWidget {
  const UpdateUsernameView({super.key});

  @override
  State<UpdateUsernameView> createState() => _UpdateUsernameViewState();
}

class _UpdateUsernameViewState extends State<UpdateUsernameView> {
  final TextEditingController controller = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    BlocProvider.of<UpdateusernameBloc>(
      context,
    ).add(ResetUpdateUserNameState());
    super.initState();
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
        bottom: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 40),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: "Update Username",
                  padding: 20,
                  size: 22,
                  weight: FontWeight.bold,
                ),
                TextWidget(
                  text: "Change your username to something new.",
                  padding: 20,
                ),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<UpdateusernameBloc, UpdateusernameState>(
        builder: (context, state) {
          switch (state) {
            case UpdateusernameInitial():
              return initialState(context);
            case UpdateusernameLoading():
              return const Center(child: KProgressIndicator());
            case UpdateusernameError():
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextWidget(
                      text: state.error,
                      color: Colors.red,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(20),
                    TextButton(
                      onPressed: () {
                        controller.clear();
                        context.read<UpdateusernameBloc>().add(
                          RetryEventPressed(),
                        );
                      },
                      child: const Text("Try Again"),
                    ),
                  ],
                ),
              );
            case UpdateusernameSuccess():
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 80,
                    ),
                    const Gap(20),
                    const TextWidget(
                      text: "Username updated successfully!",
                      size: 18,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(20),
                    TextButton(
                      onPressed: () => GoRouter.of(context).pop(),
                      child: const Text("Back to Profile"),
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  Form initialState(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        children: [
          TextFormFieldWithText(
            controller: controller,
            heading: "New Username",
            hint: "Enter your new username",
            validator:
                (value) =>
                    value!.trim().isEmpty ? "Username is required" : null,
          ),
          const Gap(20),
          Center(
            child: TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  context.read<UpdateusernameBloc>().add(
                    UpdateUserNameEventPressed(
                      username: controller.text.trim(),
                    ),
                  );
                }
              },
              child: const Text("Update Username"),
            ),
          ),
        ],
      ),
    );
  }
}

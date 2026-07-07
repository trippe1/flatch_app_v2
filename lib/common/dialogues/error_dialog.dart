import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/common/widgets/text_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ErrorDialog extends StatelessWidget {
  final String? error;
  const ErrorDialog({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: const Center(
        child: TextWidget(text: "Error Occcured", weight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            TextWidget(
              text:
                  error ?? "An invalid error occurred, please try again later",
            ),
            const Gap(20),
            KTextButton(
              text: "Got it",
              backgroundColor: AppColors.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

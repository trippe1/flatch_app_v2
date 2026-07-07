import 'package:flatch/common/services/app_logger.dart';
import 'package:flatch/common/widgets/error_message.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FirebaseAuthError extends StatelessWidget {
  final Object error;
  final VoidCallback? ontap;
  const FirebaseAuthError({super.key, required this.error, this.ontap});

  @override
  Widget build(BuildContext context) {
    appLogger.e("error $error");
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.black,
            size: MediaQuery.of(context).size.width * 0.25,
          ),
        ),
        const Gap(20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: ErrorMessage(message: error),
        ),
        const Gap(30),
        TextButton(onPressed: ontap, child: const Text("Retry")),
        const Gap(50),
      ],
    );
  }
}

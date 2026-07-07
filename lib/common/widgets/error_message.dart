import 'package:flatch/common/extensions/auth_exceptions.dart';
import 'package:flatch/common/services/app_logger.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ErrorMessage extends StatelessWidget {
  final Object message;
  final String? errorMessage;
  const ErrorMessage({super.key, required this.message, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    if (message is FirebaseAuthException) {
      appLogger.d('som');
      FirebaseAuthException e = message as FirebaseAuthException;
      return TextWidget(
        text: e.authError(),
        size: 16,
        textAlign: TextAlign.center,
      );
    } else {
      return TextWidget(
        text: errorMessage ?? "An invalid error occured",
        size: 16,
        textAlign: TextAlign.center,
      );
    }
  }
}

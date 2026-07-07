import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

void showToast({
  required BuildContext context,
  required String message,
  ToastificationType type = ToastificationType.info,
}) {
  toastification.show(
    context: context,
    type: type,
    style: ToastificationStyle.flat,
    description: Text(message),
    alignment: Alignment.bottomCenter,
    autoCloseDuration: const Duration(seconds: 3),
    showProgressBar: false,
  );
}

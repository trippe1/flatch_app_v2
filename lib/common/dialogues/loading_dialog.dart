import 'package:flatch/common/widgets/circular_percent_indicator.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  const LoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Center(
        child: TextWidget(text: "Please wait", weight: FontWeight.bold),
      ),
      content: KLinearProgress(),
    );
  }
}

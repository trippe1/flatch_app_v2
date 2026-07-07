import 'package:flutter/material.dart';

class RoleSelectionDialog extends StatelessWidget {
  const RoleSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Select your role'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'customer'),
          child: const Text('Customer'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'owner'),
          child: const Text('Owner'),
        ),
        // Add more roles if needed
      ],
    );
  }

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const RoleSelectionDialog(),
    );
  }
}

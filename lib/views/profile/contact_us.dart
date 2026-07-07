import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        leading: IconButton(
          style: ButtonStyle().copyWith(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStatePropertyAll(BorderSide.none),
          ),
          onPressed: () => GoRouter.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Text(
          'Please email us with any issues or feedback at\n\nfartsupport@flatch.cloud',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

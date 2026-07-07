import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome, Admin! Where would you like to go?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.app_registration),
              label: const Text("Go to App Experience"),
              style: ElevatedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                context.goNamed(AppRoute.home.name);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text("Go to Admin Panel"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                context.goNamed(AppRoute.adminPanel.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}

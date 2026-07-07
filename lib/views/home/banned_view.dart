import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:go_router/go_router.dart';

class BannedWall extends StatelessWidget {
  final bool isBan;
  final String banReason;
  final int bannedAt;
  final String supportEmail; // NEW

  const BannedWall({
    super.key,
    required this.isBan,
    required this.banReason,
    required this.bannedAt,
    required this.supportEmail, // NEW
  });

  @override
  Widget build(BuildContext context) {
    if (!isBan) return const SizedBox.shrink();

    final date = DateTime.fromMillisecondsSinceEpoch(bannedAt);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? Colors.red.withAlpha(20) : Colors.red.withAlpha(40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withAlpha(180), width: 1.4),
            boxShadow: [
              BoxShadow(
                color:
                    isDark
                        ? Colors.black.withAlpha(100)
                        : Colors.red.withAlpha(60),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, color: Colors.red.shade400, size: 60),

                const SizedBox(height: 18),

                TextWidget(
                  text: "You Are Banned",
                  size: 24,
                  weight: FontWeight.bold,
                  color: Colors.red.shade400,
                ),

                const SizedBox(height: 20),

                TextWidget(
                  text: "Reason",
                  size: 18,
                  weight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium!.color,
                ),

                const SizedBox(height: 8),

                TextWidget(
                  text: banReason,
                  size: 16,
                  textAlign: TextAlign.center,
                  color: theme.textTheme.bodySmall!.color?.withAlpha(200),
                ),

                const SizedBox(height: 24),

                TextWidget(
                  text: "Banned At",
                  size: 16,
                  weight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium!.color,
                ),

                const SizedBox(height: 6),

                TextWidget(
                  text: "$date",
                  size: 14,
                  color: theme.textTheme.bodySmall!.color?.withAlpha(180),
                ),

                const SizedBox(height: 24),

                TextWidget(
                  text: "For support, contact the email below:",
                  size: 15,
                  textAlign: TextAlign.center,
                  color: theme.textTheme.bodySmall!.color?.withAlpha(220),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 1.4),
                  ),
                  child: TextWidget(
                    text: supportEmail,
                    size: 16,
                    weight: FontWeight.w600,
                    textAlign: TextAlign.center,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white12 : Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      context.goNamed(AppRoute.dashboard.name);
                    }
                  },
                  child: const TextWidget(
                    text: "Change Account",
                    size: 16,
                    weight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

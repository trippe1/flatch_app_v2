import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/age_gate_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows [child] to signed-in users; shows the community sign-in wall to guests.
/// Used to gate social tabs (feed / upload / profile) in guest mode.
class AuthGate extends StatelessWidget {
  final Widget child;
  final String feature;
  const AuthGate({super.key, required this.child, required this.feature});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.data != null) return child;
        return CommunityGateWall(feature: feature);
      },
    );
  }
}

/// The guest-mode wall. Invites eligible users to create an account; for a
/// device already age-blocked it shows a neutral unavailable state (no CTA).
class CommunityGateWall extends StatelessWidget {
  final String feature;
  const CommunityGateWall({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    final blocked = AgeGateService.instance.isBlockedCached;
    final theme = Theme.of(context);
    return Scaffold(
      // Opaque palette background (labWhite / nearBlack) rather than
      // transparent — transparent let the dashboard's white→green gradient
      // show through behind the guest wall.
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  blocked ? Icons.lock_outline : Icons.groups_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  blocked ? 'Community access is unavailable' : 'Community access',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  blocked
                      ? 'The device and its built-in sounds remain available. '
                          'Community features are not available on this device.'
                      : 'A user account is required to record and upload '
                          'sounds and participate in the Flatch community. '
                          'Managing and playing stock sounds on your Flatch '
                          'device remain available without a user account.',
                  textAlign: TextAlign.center,
                  // Was a hardcoded grey[700] — unreadable on the dark
                  // background now that the wall is opaque.
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
                if (!blocked) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => context.pushNamed(AppRoute.ageGate.name),
                      child: const Text('Create account / Sign in'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

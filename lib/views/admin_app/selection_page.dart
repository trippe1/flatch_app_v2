import 'package:cloud_functions/cloud_functions.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  bool _reindexing = false;

  /// Rebuilds `hotScore` + `searchTokens` across every fart.
  ///
  /// Required once after the community index shipped — farts created before it
  /// have no `hotScore`, and Firestore omits docs missing an ordered field, so
  /// they'd never appear in the ranked feed. Safe to re-run any time.
  Future<void> _rebuildIndex() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reindexing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('backfillFartIndex');
      final result = await callable.call();
      final data = Map<String, dynamic>.from(result.data as Map);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Reindexed ${data['updated']} of ${data['scanned']} farts.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Reindex failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Reindex failed: $e')));
    } finally {
      if (mounted) setState(() => _reindexing = false);
    }
  }

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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.shield_outlined),
              label: const Text("Content Moderation Queue"),
              style: ElevatedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                context.goNamed(AppRoute.moderationQueue.name);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon:
                  _reindexing
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.manage_search),
              label: Text(
                _reindexing
                    ? "Rebuilding index…"
                    : "Rebuild search & ranking index",
              ),
              style: ElevatedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _reindexing ? null : _rebuildIndex,
            ),
          ],
        ),
      ),
    );
  }
}

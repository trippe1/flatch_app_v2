import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/models/fwb_models.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/fwb_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Deep-link target for `flik.me/fwb/<groupId>`. Loads the group, then either
/// opens the chat (already a member), offers to join, or asks the user to sign
/// in first.
class FwbJoinScreen extends StatefulWidget {
  final String groupId;
  const FwbJoinScreen({super.key, required this.groupId});

  @override
  State<FwbJoinScreen> createState() => _FwbJoinScreenState();
}

class _FwbJoinScreenState extends State<FwbJoinScreen> {
  late Future<_JoinInfo> _load;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<_JoinInfo> _fetch() async {
    final group = await FwbService.getGroup(widget.groupId);
    if (group == null) return const _JoinInfo(group: null, creatorName: '');
    final creatorName = await FwbService.displayName(group.creatorUid);
    return _JoinInfo(group: group, creatorName: creatorName);
  }

  Future<void> _join(FwbGroup group) async {
    setState(() => _joining = true);
    try {
      await FwbService.joinGroup(widget.groupId);
      if (!mounted) return;
      context.pushReplacementNamed(AppRoute.fwbChat.name, extra: group.id);
    } catch (_) {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farts with Buddies')),
      body: FutureBuilder<_JoinInfo>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snap.data;
          final group = info?.group;
          if (group == null) {
            return _centered(
              icon: Icons.link_off_rounded,
              title: 'Invite not found',
              body: 'This group may have been deleted.',
              button: 'Go home',
              onTap: () => context.goNamed(AppRoute.home.name),
            );
          }

          // Signed out — ask them to sign in first (the link stays on the
          // deep-link path, so they'll land back here after auth).
          if (FwbService.uid == null) {
            return _centered(
              icon: Icons.lock_outline_rounded,
              title: "You're invited!",
              body:
                  "Sign in to join \"${group.name}\" on Farts with Buddies.",
              button: 'Sign in',
              onTap: () => context.goNamed(AppRoute.login.name),
            );
          }

          // Already a member — go straight to the chat.
          if (group.members.contains(FwbService.uid)) {
            return _centered(
              icon: Icons.groups_rounded,
              title: group.name,
              body: "You're already in this group.",
              button: 'Open chat',
              onTap:
                  () => context.pushReplacementNamed(
                    AppRoute.fwbChat.name,
                    extra: group.id,
                  ),
            );
          }

          final me = info!.creatorName;
          return _centered(
            icon: Icons.group_add_rounded,
            title: "Join ${me.isEmpty ? 'this' : "$me's"} group?",
            body:
                '"${group.name}" · ${group.members.length} member'
                '${group.members.length == 1 ? '' : 's'}'
                '${group.anonymous ? ' · Anonymous' : ''}',
            button: _joining ? 'Joining…' : 'Join group',
            onTap: _joining ? null : () => _join(group),
          );
        },
      ),
    );
  }

  Widget _centered({
    required IconData icon,
    required String title,
    required String body,
    required String button,
    required VoidCallback? onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: onTap,
                child: Text(button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinInfo {
  final FwbGroup? group;
  final String creatorName;
  const _JoinInfo({required this.group, required this.creatorName});
}

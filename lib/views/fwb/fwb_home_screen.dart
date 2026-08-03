import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/models/fwb_models.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/fwb_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Landing / list page for "Farts with Buddies": the user's groups + a way to
/// create a new one.
class FwbHomeScreen extends StatelessWidget {
  const FwbHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farts with Buddies')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.pushNamed(AppRoute.fwbCreate.name),
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text('New group', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              "Start a chat and guess each others' farts!",
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<FwbGroup>>(
              stream: FwbService.myGroups(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groups = snap.data ?? const [];
                if (groups.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.groups_2_rounded,
                            size: 56,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No groups yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Create a group and invite your buddies.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Icon(
                            g.anonymous
                                ? Icons.visibility_off_rounded
                                : Icons.groups_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          g.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${g.anonymous ? 'Anonymous · ' : ''}'
                          '${g.members.length} member'
                          '${g.members.length == 1 ? '' : 's'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap:
                            () => context.pushNamed(
                              AppRoute.fwbChat.name,
                              extra: g.id,
                            ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

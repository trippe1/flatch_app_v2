import 'package:flatch/blocs/admin_users/admin_users_bloc.dart';
import 'package:flatch/common/models/app_user.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();

  void _searchUser() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      context.read<AdminUsersBloc>().add(ResetSearchEvent());
      context.read<AdminUsersBloc>().add(SearchUserEvent(query: query));
    }
  }

  @override
  void initState() {
    context.read<AdminUsersBloc>().add(ResetSearchEvent());
    context.read<AdminUsersBloc>().add(FetchAdminUsersEvent());

    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Roles"),
        centerTitle: true,
        leading: IconButton(
          style: const ButtonStyle().copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),

            side: const WidgetStatePropertyAll(BorderSide.none),
          ),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            style: const ButtonStyle().copyWith(
              backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              side: const WidgetStatePropertyAll(BorderSide.none),
            ),
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _searchController.clear();
              context.read<AdminUsersBloc>().add(ResetSearchEvent());
              context.read<AdminUsersBloc>().add(FetchAdminUsersEvent());
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search user by email or username",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  style: ButtonStyle().copyWith(
                    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                    side: WidgetStatePropertyAll(BorderSide.none),
                  ),
                  icon: const Icon(Icons.search),
                  onPressed: _searchUser,
                ),
              ),
              onSubmitted: (_) => _searchUser(),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: BlocBuilder<AdminUsersBloc, AdminUsersState>(
                builder: (context, state) {
                  if (state is AdminUsersLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is AdminUsersError) {
                    return Center(child: Text("Error: ${state.message}"));
                  } else if (state is AdminUsersLoaded) {
                    if (state.users.isEmpty) {
                      return const Center(child: Text("No user found."));
                    }

                    // Show all users
                    return ListView.builder(
                      itemCount: state.users.length,
                      itemBuilder: (context, index) {
                        final userDoc = state.users[index];
                        final appUser = AppUser.fromMap(
                          userDoc.data()! as Map<String, dynamic>,
                        );
                        return UserCard(
                          user: appUser,
                          selectedRole: appUser.role,
                          onRoleChanged: (value) {
                            if (value != null && value != appUser.role) {
                              context.read<AdminUsersBloc>().add(
                                AssignUserRoleEvent(
                                  userId: appUser.uid,
                                  role: value,
                                ),
                              );
                              showToast(
                                context: context,
                                message: 'Role Assigned $value',
                                type: ToastificationType.success,
                              );
                            }
                          },
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserCard extends StatelessWidget {
  final AppUser user;
  final ValueChanged<String?>? onRoleChanged;
  final String? selectedRole;

  const UserCard({
    super.key,
    required this.user,
    this.onRoleChanged,
    this.selectedRole,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.pushNamed(
          AppRoute.userProfileScreen.name,
          extra: user.uid,
          queryParameters: {'isAdmin': 'true'},
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildCircularUserAvatarAdmin(
                context,
                user.profileImage,
                user.name,
                60,
                heroTag: user.uid,
              ),

              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(user.email, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Joined: ${DateTime.fromMillisecondsSinceEpoch(user.joinedOn).toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${user.country ?? '-'}, ${user.state ?? '-'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (user.description != null &&
                        user.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          user.description!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Role dropdown
              if (onRoleChanged != null)
                DropdownButton<String>(
                  value: selectedRole ?? user.role,
                  items: const [
                    DropdownMenuItem(value: 'User', child: Text('User')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: onRoleChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

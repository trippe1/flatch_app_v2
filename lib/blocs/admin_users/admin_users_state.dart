part of 'admin_users_bloc.dart';
sealed class AdminUsersState extends Equatable {
  const AdminUsersState();

  @override
  List<Object?> get props => [];
}

final class AdminUsersInitial extends AdminUsersState {}

final class AdminUsersLoading extends AdminUsersState {}

final class AdminUsersLoaded extends AdminUsersState {
  final List<DocumentSnapshot> users;
  final bool hasMore;

  const AdminUsersLoaded({required this.users, required this.hasMore});

  @override
  List<Object?> get props => [users, hasMore];

  AdminUsersLoaded copyWith({List<DocumentSnapshot>? users, bool? hasMore}) {
    return AdminUsersLoaded(
      users: users ?? this.users,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final class AdminUsersError extends AdminUsersState {
  final String message;

  const AdminUsersError(this.message);

  @override
  List<Object?> get props => [message];
}

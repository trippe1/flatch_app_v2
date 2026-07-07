part of 'admin_users_bloc.dart';



sealed class AdminUsersEvent extends Equatable {
  const AdminUsersEvent();

  @override
  List<Object?> get props => [];
}

final class FetchAdminUsersEvent extends AdminUsersEvent {
  final DocumentSnapshot? lastDoc;

  const FetchAdminUsersEvent({this.lastDoc});

  @override
  List<Object?> get props => [lastDoc];
}
final class AssignUserRoleEvent extends AdminUsersEvent {
  final String userId;
  final String role; 

  const AssignUserRoleEvent({required this.userId, required this.role});

  @override
  List<Object?> get props => [userId, role];
}
final class SearchUserEvent extends AdminUsersEvent {
  final String query;

  const SearchUserEvent({required this.query});

  @override
  List<Object?> get props => [query];
}

final class ResetSearchEvent extends AdminUsersEvent{}
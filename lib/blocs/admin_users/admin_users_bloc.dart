import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

part 'admin_users_event.dart';
part 'admin_users_state.dart';

class AdminUsersBloc extends Bloc<AdminUsersEvent, AdminUsersState> {
  AdminUsersBloc() : super(AdminUsersInitial()) {
    on<FetchAdminUsersEvent>(_onFetchUsers);
    on<AssignUserRoleEvent>(_onAssignUserRole);
    on<SearchUserEvent>(_onSearchUser);
    on<ResetSearchEvent>((event, emit) {
      emit(AdminUsersInitial());
    });
  }

  static const int limit = 20;
  Future<void> _onSearchUser(
    SearchUserEvent event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(AdminUsersLoading());
    try {
      final query = event.query.trim();

      if (isEmail(query)) {
        // Search by exact email
        final emailSnap =
            await FirebaseFirestore.instance
                .collection('app_users')
                .where('email', isEqualTo: query)
                .limit(1)
                .get();

        if (emailSnap.docs.isNotEmpty) {
          emit(AdminUsersLoaded(users: emailSnap.docs, hasMore: false));
          return;
        }
      }

      // Otherwise, treat as a name and search (e.g. startsWith)
      final nameSnap =
          await FirebaseFirestore.instance
              .collection('app_users')
              .orderBy('name')
              .startAt([query])
              .endAt(['$query\uf8ff'])
              .limit(10)
              .get();

      if (nameSnap.docs.isNotEmpty) {
        emit(AdminUsersLoaded(users: [nameSnap.docs.first], hasMore: false));
        return;
      }

      emit(const AdminUsersError('No user found with that email or username.'));
    } catch (e) {
      emit(AdminUsersError('Search failed: ${e.toString()}'));
    }
  }

  // Add this helper function:
  bool isEmail(String input) {
    return input.contains('@') && input.contains('.');
  }

  Future<void> _onFetchUsers(
    FetchAdminUsersEvent event,
    Emitter<AdminUsersState> emit,
  ) async {
    try {
      final currentState = state;
      List<DocumentSnapshot> oldUsers = [];

      if (currentState is AdminUsersLoaded && event.lastDoc != null) {
        oldUsers = currentState.users;
      } else {
        emit(AdminUsersLoading());
      }

      Query query = FirebaseFirestore.instance
          .collection('app_users')
          .orderBy('joinedOn', descending: true)
          .limit(limit);

      if (event.lastDoc != null) {
        query = query.startAfterDocument(event.lastDoc!);
      }

      final snapshot = await query.get();
      final users = snapshot.docs;
      final allUsers = [...oldUsers, ...users];

      emit(AdminUsersLoaded(users: allUsers, hasMore: users.length == limit));
    } catch (e) {
      emit(AdminUsersError(e.toString()));
    }
  }

  Future<void> _onAssignUserRole(
    AssignUserRoleEvent event,
    Emitter<AdminUsersState> emit,
  ) async {
    final currentState = state;
    if (currentState is AdminUsersLoaded) {
      try {
        await FirebaseFirestore.instance
            .collection('app_users')
            .doc(event.userId)
            .update({'role': event.role});

        final updatedUsers =
            currentState.users.map((doc) {
              if (doc.id == event.userId) {
                final data = doc.data()! as Map<String, dynamic>;
                data['role'] = event.role;
                return doc;
              }
              return doc;
            }).toList();

        emit(currentState.copyWith(users: updatedUsers));
      } catch (e) {
        emit(AdminUsersError('Failed to assign role: ${e.toString()}'));
      }
    }
  }
}

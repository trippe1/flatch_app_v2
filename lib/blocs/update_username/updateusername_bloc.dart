import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'updateusername_event.dart';
part 'updateusername_state.dart';

class UpdateusernameBloc
    extends Bloc<UpdateusernameEvent, UpdateusernameState> {
  UpdateusernameBloc() : super(UpdateusernameInitial()) {
    on<UpdateUserNameEventPressed>(
      (event, emit) async {
        emit(UpdateusernameLoading());

        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            emit(const UpdateusernameError(error: "User not logged in"));
            return;
          }

          final firestore = FirebaseFirestore.instance;

          final appUsersSnapshot = await firestore
              .collection('app_users')
              .where('uid', isEqualTo: user.uid)
              .get();

          if (appUsersSnapshot.docs.isNotEmpty) {
            final docId = appUsersSnapshot.docs.first.id;
            await firestore.collection('app_users').doc(docId).update({
              'name': event.username,
            });
          }

          final companyUsersSnapshot = await firestore
              .collection('company_users')
              .where('uid', isEqualTo: user.uid)
              .get();

          if (companyUsersSnapshot.docs.isNotEmpty) {
            final docId = companyUsersSnapshot.docs.first.id;
            await firestore.collection('company_users').doc(docId).update({
              'name': event.username,
            });
          }

          await user.updateDisplayName(event.username);

          if (appUsersSnapshot.docs.isNotEmpty ||
              companyUsersSnapshot.docs.isNotEmpty) {
            emit(UpdateusernameSuccess());
          } else {
            emit(const UpdateusernameError(
                error: "User document not found in both collections"));
          }
        } catch (e) {
          emit(UpdateusernameError(error: e.toString()));
        }
      },
    );

    on<RetryEventPressed>(
      (event, emit) => emit(UpdateusernameInitial()),
    );
    on<ResetUpdateUserNameState>((event, emit) {
      emit(UpdateusernameInitial());
    });
  }
}

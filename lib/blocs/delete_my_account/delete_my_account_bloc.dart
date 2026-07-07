import 'package:flatch/common/local_db/local_database.dart';
import 'package:flatch/common/services/cloud_functions.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'delete_my_account_event.dart';
part 'delete_my_account_state.dart';

class DeleteMyAccountBloc
    extends Bloc<DeleteMyAccountEvent, DeleteMyAccountState> {
  DeleteMyAccountBloc() : super(DeleteMyAccountInitial()) {
    on<DeleteMyAccountEvent>((event, emit) {});
    on<DeleteMyUserAccountEvent>((event, emit) async {
      try {
        emit(DeleteMyAccountLoadingState());
        UserCredential cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: FirebaseAuth.instance.currentUser!.email!,
              password: event.password.trim(),
            );
        final User? user = cred.user;
        if (user != null) {
          final String uid = user.uid;
          await user.delete();
          await CloudFunctionsService.instance.deleteUserAccount(uid);
          await LocalDatabase.instance.deleteFirstVisitDetails();
          emit(DeleteMyAccountSuccessState());
        } else {
          throw Exception('User not found');
        }
      } catch (e) {
        emit(DeleteMyAccountErrorState(error: e));
      }
    });
    on<RetryDeleteMyUserAccountEvent>(
      (event, emit) => emit(DeleteMyAccountInitial()),
    );
  }
}

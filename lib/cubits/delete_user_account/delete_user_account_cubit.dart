import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
part 'delete_user_account_state.dart';

class DeleteUserAccountCubit extends Cubit<DeleteUserAccountCubitState> {
  DeleteUserAccountCubit() : super(DeleteUserAccountInitial());

  void onUnobsecure(bool isSecure) => emit(state.copyWith(obsecure: isSecure));
}

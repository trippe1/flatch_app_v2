part of 'delete_user_account_cubit.dart';

final class DeleteUserAccountCubitState extends Equatable {
  final bool obsecure;
  const DeleteUserAccountCubitState({this.obsecure = true});

  @override
  List<Object> get props => [obsecure];
  DeleteUserAccountCubitState copyWith({bool? obsecure}) {
    return DeleteUserAccountCubitState(obsecure: obsecure ?? this.obsecure);
  }
}

final class DeleteUserAccountInitial extends DeleteUserAccountCubitState {}

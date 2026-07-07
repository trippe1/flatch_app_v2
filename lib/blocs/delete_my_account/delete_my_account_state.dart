part of 'delete_my_account_bloc.dart';

sealed class DeleteMyAccountState extends Equatable {
  const DeleteMyAccountState();

  @override
  List<Object> get props => [];
}

final class DeleteMyAccountInitial extends DeleteMyAccountState {}

final class DeleteMyAccountLoadingState extends DeleteMyAccountState {}

final class DeleteMyAccountErrorState extends DeleteMyAccountState {
  final Object error;

  const DeleteMyAccountErrorState({required this.error});
}

final class DeleteMyAccountSuccessState extends DeleteMyAccountState {}

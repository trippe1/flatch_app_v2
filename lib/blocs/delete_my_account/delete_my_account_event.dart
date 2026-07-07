part of 'delete_my_account_bloc.dart';

sealed class DeleteMyAccountEvent extends Equatable {
  const DeleteMyAccountEvent();

  @override
  List<Object> get props => [];
}

final class DeleteMyUserAccountEvent extends DeleteMyAccountEvent {
  final String password;

  const DeleteMyUserAccountEvent({required this.password});
}

final class RetryDeleteMyUserAccountEvent extends DeleteMyAccountEvent {}

final class UnObsecuredDeleteMyUserAccountEvent extends DeleteMyAccountEvent {
  final bool obsecure;

  const UnObsecuredDeleteMyUserAccountEvent({required this.obsecure});
}

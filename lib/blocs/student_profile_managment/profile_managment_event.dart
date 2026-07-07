part of 'profile_managment_bloc.dart';

sealed class ProfileManagmentEvent extends Equatable {
  const ProfileManagmentEvent();

  @override
  List<Object> get props => [];
}

final class GetProfileEvent extends ProfileManagmentEvent {}

final class GetUserDetailsEvent extends ProfileManagmentEvent {}

final class UploadUserImageEvent extends ProfileManagmentEvent {
  final ImageSource source;
  const UploadUserImageEvent({required this.source});
}

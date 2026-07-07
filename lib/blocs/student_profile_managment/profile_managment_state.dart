part of 'profile_managment_bloc.dart';

sealed class ProfileManagmentState extends Equatable {
  const ProfileManagmentState();

  @override
  List<Object> get props => [];
}

final class ProfileManagmentInitial extends ProfileManagmentState {}

final class ProfileManagmentLoading extends ProfileManagmentState {}

final class ProfileManagmentLoaded extends ProfileManagmentState {
  final User user;
  final AppUser appUser;
  final String version;
  final CustomClaims claims;
  const ProfileManagmentLoaded({
    required this.user,
    required this.appUser,
    required this.version,
    required this.claims,
  });
}

final class ProfileManagmentError extends ProfileManagmentState {
  final String error;
  const ProfileManagmentError(this.error);
}

final class UploadingUserImageLoadingState extends ProfileManagmentState {
  const UploadingUserImageLoadingState();
}

final class UploadingUserErrorState extends ProfileManagmentState {
  final String error;
  const UploadingUserErrorState({required this.error});
}

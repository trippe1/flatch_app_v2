part of 'user_details_bloc.dart';

sealed class UserDetailsState extends Equatable {
  const UserDetailsState();
  
  @override
  List<Object> get props => [];
}

final class UserDetailsInitial extends UserDetailsState {}

final class UserDetailsLoading extends UserDetailsState {}

final class UserDetailsLoaded extends UserDetailsState {
  final AppUser appUser;
  final List<FartModel> farts;
 

  const UserDetailsLoaded({
required this.appUser,
required this.farts

  });
}
final class UserDetailsError extends UserDetailsState {
  final String message;

  const UserDetailsError(this.message);
}
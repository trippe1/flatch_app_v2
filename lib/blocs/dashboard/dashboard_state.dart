part of 'dashboard_bloc.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object> get props => [];
}

final class DashboardInitial extends DashboardState {}

final class DashboardLoadingState extends DashboardState {}

final class DashboardErrorState extends DashboardState {
  final String errorMessage;

  const DashboardErrorState({required this.errorMessage});
}

final class DashboardSuccessState extends DashboardState {
  final User user;

  const DashboardSuccessState({required this.user});
}

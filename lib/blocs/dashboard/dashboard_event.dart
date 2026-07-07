part of 'dashboard_bloc.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object> get props => [];
}

final class GoogleLogin extends DashboardEvent {
  final String? role;
  const GoogleLogin({this.role});
}

final class AppleLogin extends DashboardEvent {
  final String? role;
  const AppleLogin({this.role});
}

final class EmitInitialState extends DashboardEvent {}

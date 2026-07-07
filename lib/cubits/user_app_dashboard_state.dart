part of 'user_app_dashboard_cubit.dart';

final class UserAppDashboardState extends Equatable {
  final int index;
  final bool isTappedOnActions;
  final bool showBottomNavBar;
  final bool navigateToBottom;
  const UserAppDashboardState({
    this.index = 0,
    this.isTappedOnActions = false,
    this.showBottomNavBar = true,
    this.navigateToBottom = false,
  });

  @override
  List<Object> get props => [
    index,
    isTappedOnActions,
    showBottomNavBar,
    navigateToBottom,
  ];

  UserAppDashboardState copyWith({
    int? index,
    final bool? isTappedOnActions,
    bool? showBottomNavBar,
    bool? navigateToBottom,
  }) {
    return UserAppDashboardState(
      index: index ?? this.index,
      isTappedOnActions: isTappedOnActions ?? this.isTappedOnActions,
      showBottomNavBar: showBottomNavBar ?? this.showBottomNavBar,
      navigateToBottom: navigateToBottom ?? this.navigateToBottom,
    );
  }
}

final class UserAppDashboardInitial extends UserAppDashboardState {}

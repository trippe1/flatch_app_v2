import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'user_app_dashboard_state.dart';

class UserAppDashboardCubit extends Cubit<UserAppDashboardState> {
  UserAppDashboardCubit() : super(UserAppDashboardInitial());

  void onUpdateIndex(int index) => emit(state.copyWith(index: index));

  void onTapActions() => emit(state.copyWith(isTappedOnActions: true));

  void onShowOrRemoveBottomNavBar() {
    final bool shotBottomBar = state.showBottomNavBar;
    emit(state.copyWith(showBottomNavBar: !shotBottomBar));
  }

  void navigateToBottom() async {
    emit(state.copyWith(navigateToBottom: true));
    Timer(
      const Duration(seconds: 2),
      () => emit(state.copyWith(navigateToBottom: false)),
    );
  }
}

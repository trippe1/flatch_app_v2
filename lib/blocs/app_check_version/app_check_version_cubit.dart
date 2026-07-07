import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:equatable/equatable.dart';

part 'app_check_version_state.dart';

class AppCheckVersionCubit extends Cubit<AppCheckVersionState> {
  AppCheckVersionCubit() : super(AppCheckVersionInitial());

  void loadData() async {
    final plugin = DeviceInfoPlugin();

    bool isAndroid15 = false;
    if (Platform.isAndroid) {
      final androidInfo = await plugin.androidInfo;
      isAndroid15 = (androidInfo.version.sdkInt) >= 34;
    }

    emit(state.copyWith(isAndroid15: isAndroid15));
  }
}

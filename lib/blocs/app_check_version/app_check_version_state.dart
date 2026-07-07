part of 'app_check_version_cubit.dart';

final class AppCheckVersionState extends Equatable {
  final bool isAndroid15;

  const AppCheckVersionState({this.isAndroid15 = false});

  @override
  List<Object> get props => [isAndroid15];

  AppCheckVersionState copyWith({
    bool? isAndroid15,
  }) {
    return AppCheckVersionState(
      isAndroid15: isAndroid15 ?? this.isAndroid15,
    );
  }
}

final class AppCheckVersionInitial extends AppCheckVersionState {}

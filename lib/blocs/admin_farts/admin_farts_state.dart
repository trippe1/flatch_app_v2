part of 'admin_farts_bloc.dart';

sealed class AdminFartsState extends Equatable {
  const AdminFartsState();

  @override
  List<Object?> get props => [];
}

final class AdminFartsInitial extends AdminFartsState {}

final class AdminFartsLoading extends AdminFartsState {}
final class AdminFartsLoaded extends AdminFartsState {
  final List<FartModel> farts;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;

  const AdminFartsLoaded({
    required this.farts,
    required this.hasMore,
    this.lastDoc,
  });

  @override
  List<Object?> get props => [farts, hasMore, lastDoc];

  AdminFartsLoaded copyWith({
    List<FartModel>? farts,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
  }) {
    return AdminFartsLoaded(
      farts: farts ?? this.farts,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
    );
  }
}


final class AdminFartsError extends AdminFartsState {
  final String message;

  const AdminFartsError(this.message);

  @override
  List<Object?> get props => [message];
}

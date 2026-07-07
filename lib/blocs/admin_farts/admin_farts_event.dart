part of 'admin_farts_bloc.dart';

sealed class AdminFartsEvent extends Equatable {
  const AdminFartsEvent();

  @override
  List<Object?> get props => [];
}

final class FetchAdminFartsEvent extends AdminFartsEvent {
  final String? category;
  final DocumentSnapshot? lastDoc;

  const FetchAdminFartsEvent({this.category, this.lastDoc});

  @override
  List<Object?> get props => [category, lastDoc];
}

final class DeleteFartEvent extends AdminFartsEvent{
  final String fartId;

  const DeleteFartEvent({required this.fartId});

  @override
  List<Object?> get props => [fartId];

}

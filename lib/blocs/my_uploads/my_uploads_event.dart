part of 'my_uploads_bloc.dart';

final class MyUploadsEvent extends Equatable {
  const MyUploadsEvent();

  @override
  List<Object?> get props => [];
}

final class FetcnInitialUploads extends MyUploadsEvent {}

final class FetchMoreUploads extends MyUploadsEvent {
  final DocumentSnapshot lastDoc;

  const FetchMoreUploads(this.lastDoc);

  @override
  List<Object?> get props => [lastDoc];
}

final class DeleteUpload extends MyUploadsEvent {
  final String id;

  const DeleteUpload({required this.id});
}
final class EditUploadName extends MyUploadsEvent {
  final String id;
  final String newName;

  const EditUploadName({required this.id, required this.newName});
}

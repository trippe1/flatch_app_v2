part of 'my_uploads_bloc.dart';

sealed class MyUploadsState extends Equatable {
  const MyUploadsState();

  @override
  List<Object?> get props => [];
}

final class MyUploadsInitial extends MyUploadsState {}

final class MyUploadsLoading extends MyUploadsState {}

final class MyUploadsLoaded extends MyUploadsState {
  final List<FartModel> uploads;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const MyUploadsLoaded({
    required this.uploads,
    this.lastDoc,
    required this.hasMore,
  });
  MyUploadsLoaded copyWith({
    List<FartModel>? uploads,
    DocumentSnapshot? lastDoc,
    bool? hasMore,
  }) {
    return MyUploadsLoaded(
      uploads: uploads ?? this.uploads,
      lastDoc: lastDoc ?? this.lastDoc,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [uploads, lastDoc, hasMore];
}

final class MyUploadsError extends MyUploadsState {
  final String message;
  const MyUploadsError({required this.message});
}

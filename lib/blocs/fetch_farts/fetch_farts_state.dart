part of 'fetch_farts_bloc.dart';

sealed class FetchFartsState extends Equatable {
  const FetchFartsState();

  @override
  List<Object?> get props => [];
}

final class FetchFartsInitial extends FetchFartsState {}

final class FetchFartsLoading extends FetchFartsState {}

final class FetchFartsSuccess extends FetchFartsState {
  final List<FartModel> farts;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const FetchFartsSuccess({
    required this.farts,
    this.lastDoc,
    required this.hasMore,
  });

  @override
  List<Object?> get props => [farts, lastDoc, hasMore];
}

final class FetchFartsFailure extends FetchFartsState {
  final String error;

  const FetchFartsFailure(this.error);

  @override
  List<Object?> get props => [error];
}

final class FetchCommentsSuccess extends FetchFartsState {
  final String fartId;
  final List<CommentModel> comments;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const FetchCommentsSuccess({
    required this.fartId,
    required this.comments,
    this.lastDoc,
    required this.hasMore,
  });

  FetchCommentsSuccess copyWith({
    List<CommentModel>? comments,
    DocumentSnapshot? lastDoc,
    bool? hasMore,
  }) {
    return FetchCommentsSuccess(
      fartId: fartId,
      comments: comments ?? this.comments,
      lastDoc: lastDoc ?? this.lastDoc,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [fartId, comments, lastDoc, hasMore];
}

final class FetchCommentsFailure extends FetchFartsState {
  final String fartId;
  final String error;

  const FetchCommentsFailure({required this.fartId, required this.error});

  @override
  List<Object?> get props => [fartId, error];
}

final class CommentsLoading extends FetchFartsState {}

part of 'fetch_farts_bloc.dart';

sealed class FetchFartsEvent extends Equatable {
  const FetchFartsEvent();

  @override
  List<Object?> get props => [];
}

final class FetchMoreFarts extends FetchFartsEvent {
  final DocumentSnapshot lastDoc;

  const FetchMoreFarts(this.lastDoc);

  @override
  List<Object?> get props => [lastDoc];
}

final class VoteFart extends FetchFartsEvent {
  final String fartId;
  final String voteType;

  const VoteFart({required this.fartId, required this.voteType});

  @override
  List<Object?> get props => [fartId, voteType];
}

final class _FartsUpdated extends FetchFartsEvent {
  final List<FartModel> updatedFarts;

  const _FartsUpdated(this.updatedFarts);

  @override
  List<Object?> get props => [updatedFarts];
}

final class FetchTopFarts extends FetchFartsEvent {
  final String? category;

  const FetchTopFarts({this.category});

  @override
  List<Object?> get props => [category];
}

final class ReportFart extends FetchFartsEvent {
  final String fartId;
  final String reason;

  const ReportFart({required this.fartId, required this.reason});

  @override
  List<Object?> get props => [fartId];
}

final class FetchCommentsFart extends FetchFartsEvent {
  final String fartId;
  final DocumentSnapshot? lastDoc;
  const FetchCommentsFart({required this.fartId, this.lastDoc});
}

final class FetchMoreCommentsFart extends FetchFartsEvent {
  final String fartId;
  const FetchMoreCommentsFart({required this.fartId});
}

final class AddCommentFart extends FetchFartsEvent {
  final String text;
  final String fartId;
  final String? parentCommentId; 

  const AddCommentFart({
    required this.text,
    required this.fartId,
    this.parentCommentId, 
  });
}


final class DeleteCommentFart extends FetchFartsEvent {
  final String fartId;
  final String commentId;
   final bool isAdmin;

  const DeleteCommentFart({required this.fartId, required this.commentId, this.isAdmin = false});

  @override
  List<Object?> get props => [fartId, commentId];
}

final class VoteCommentFart extends FetchFartsEvent {
  final String fartId;
  final String commentId;
  final String voteType;
  final String userId;

  const VoteCommentFart({
    required this.fartId,
    required this.commentId,
    required this.voteType,
    required this.userId,
  });

  @override
  List<Object?> get props => [fartId, commentId, voteType];
}

final class ReportCommentFart extends FetchFartsEvent {
  final String fartId;
  final String commentId;
  final String reason;

  const ReportCommentFart({
    required this.fartId,
    required this.commentId,
    required this.reason,
  });

  @override
  List<Object?> get props => [fartId, commentId, reason];
}


final class EditCommentFart extends FetchFartsEvent {
  final String fartId;
  final String commentId;
  final String newText;

  const EditCommentFart({
    required this.fartId,
    required this.commentId,
    required this.newText,
  });

  @override
  List<Object?> get props => [fartId, commentId, newText];
}

class CommentModel {
  final String id;
  final String fartId;
  final String uid;
  final String text;
  final String? userName;
  final int upvotes;
  final int downvotes;
  final List<String> upvotedUserIds;
  final List<String> downvotedUserIds;
  final int createdAt;
  final int updatedAt;
  final String? parentCommentId;
  final List<CommentModel> replies;
  final int reportCount; // total number of reports
  final List<String> reportedUserIds; // users who reported this comment
  final bool? userReported; // whether current user reported

  CommentModel({
    required this.id,
    required this.fartId,
    required this.uid,
    required this.text,
    this.userName,
    this.upvotes = 0,
    this.downvotes = 0,
    List<String>? upvotedUserIds,
    List<String>? downvotedUserIds,
    required this.createdAt,
    required this.updatedAt,
    this.parentCommentId,
    List<CommentModel>? replies,
    this.reportCount = 0,
    List<String>? reportedUserIds,
    this.userReported,
  }) : upvotedUserIds = upvotedUserIds ?? [],
       downvotedUserIds = downvotedUserIds ?? [],
       replies = replies ?? [],
       reportedUserIds = reportedUserIds ?? [];

  bool isUpvotedBy(String userId) => upvotedUserIds.contains(userId);
  bool isDownvotedBy(String userId) => downvotedUserIds.contains(userId);
  bool isReportedBy(String userId) => reportedUserIds.contains(userId);

  CommentModel copyWith({
    String? id,
    String? fartId,
    String? uid,
    String? text,
    String? userName,
    int? upvotes,
    int? downvotes,
    List<String>? upvotedUserIds,
    List<String>? downvotedUserIds,
    int? createdAt,
    int? updatedAt,
    String? parentCommentId,
    List<CommentModel>? replies,
    int? reportCount,
    List<String>? reportedUserIds,
    bool? userReported,
  }) {
    return CommentModel(
      id: id ?? this.id,
      fartId: fartId ?? this.fartId,
      uid: uid ?? this.uid,
      text: text ?? this.text,
      userName: userName ?? this.userName,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      upvotedUserIds: upvotedUserIds ?? this.upvotedUserIds,
      downvotedUserIds: downvotedUserIds ?? this.downvotedUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
      reportCount: reportCount ?? this.reportCount,
      reportedUserIds: reportedUserIds ?? this.reportedUserIds,
      userReported: userReported ?? this.userReported,
    );
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] ?? '',
      fartId: map['fartId'] ?? '',
      uid: map['uid'] ?? '',
      text: map['text'] ?? '',
      userName: map['userName'],
      upvotes: (map['upvotes'] ?? 0).clamp(0, double.infinity).toInt(),
      downvotes: (map['downvotes'] ?? 0).clamp(0, double.infinity).toInt(),
      upvotedUserIds: List<String>.from(map['upvotedUserIds'] ?? []),
      downvotedUserIds: List<String>.from(map['downvotedUserIds'] ?? []),
      createdAt: map['createdAt'] ?? 0,
      updatedAt: map['updatedAt'] ?? 0,
      parentCommentId: map['parentCommentId'],
      replies:
          map['replies'] != null
              ? List<CommentModel>.from(
                (map['replies'] as List).map((x) => CommentModel.fromMap(x)),
              )
              : [],
      reportCount: map['reportCount'] ?? 0,
      reportedUserIds: List<String>.from(map['reportedUserIds'] ?? []),
      userReported: map['userReported'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fartId': fartId,
      'uid': uid,
      'text': text,
      if (userName != null) 'userName': userName,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'upvotedUserIds': upvotedUserIds,
      'downvotedUserIds': downvotedUserIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      'replies': replies.map((r) => r.toMap()).toList(),
      'reportCount': reportCount,
      'reportedUserIds': reportedUserIds,
      'userReported': userReported,
    };
  }
}

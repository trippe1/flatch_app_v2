import 'package:cloud_firestore/cloud_firestore.dart';

class FartModel {
  final String id;
  final String fileUrl;
  final String fileType;
  final String uid;
  final int duration;
  final int createdAt;
  final int updatedAt;
  final String title;
  final String category;
  final String region;
  final int upvotes;
  final int downvotes;
  final bool isPublic;
  final String? userVote;
  final bool? userReported;
  final String? reportReason;
  final int commentCount;
  final String? userName;
  final int reportCount;
  final String? source;


  FartModel({
    required this.id,
    required this.fileUrl,
    required this.fileType,
    required this.uid,
    required this.duration,
    required this.createdAt,
    required this.updatedAt,
    required this.title,
    required this.category,
    required this.region,
    this.upvotes = 0,
    this.downvotes = 0,
    this.userVote,
    this.userReported,
    this.reportReason,
    this.isPublic = true,
    this.commentCount = 0,
    this.userName,
    this.reportCount = 0,
      this.source,
  });
  

  factory FartModel.fromMap(
    Map<String, dynamic> map, {
    String? userVote,
    bool? userReported,
    String? reportReason,

  }) {
    final isPublic = map['isPublic'] ?? true;

    return FartModel(
      id: map['id'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileType: map['fileType'] ?? '',
      uid: map['uid'] ?? '',
      duration: map['duration'] ?? 0,
      createdAt: map['createdAt'] ?? 0,
      updatedAt: map['updatedAt'] ?? 0,
      title: isPublic ? (map['title'] ?? '') : 'Private Fart',
      category: isPublic ? (map['category'] ?? '') : 'Unknown',
      region: isPublic ? (map['region'] ?? 'Global') : 'Unknown',
      upvotes: (map['upvotes'] ?? 0).clamp(0, double.infinity).toInt(),
      downvotes: (map['downvotes'] ?? 0).clamp(0, double.infinity).toInt(),
      userVote: userVote,
      userReported: userReported,
      reportReason: reportReason,
      isPublic: isPublic,
      commentCount: map['commentCount'] ?? 0,
      userName: map['userName'] ?? '',
      reportCount: map['reportCount'] ?? 0,
      
    );
  }
   static FartModel fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FartModel.fromMap({
      'id': doc.id,
      'fileUrl': data['fileUrl'],
      'fileType': data['fileType'],
      'uid': data['uid'],
      'duration': data['duration'],
      'createdAt': data['createdAt'],
      'updatedAt': data['updatedAt'],
      'title': data['title'],
      'category': data['category'],
      'region': data['region'],
      'upvotes': data['upvotes'],
      'downvotes': data['downvotes'],
      'commentCount': data['commentCount'],
      'userName': data['userName'],
      'reportCount': data['reportCount'],
      'isPublic': data['isPublic'],
    });
  }

  FartModel copyWith({
    String? id,
    String? fileUrl,
    String? fileType,
    String? uid,
    int? duration,
    int? createdAt,
    int? updatedAt,
    String? title,
    String? category,
    String? region,
    int? upvotes,
    int? downvotes,
    String? userVote,
    bool? userReported,
    String? reportReason,
    bool? isPublic,
    int? commentCount,
    String?userName,
    int? reportCount,
     String? source,
  }) {
    return FartModel(
      id: id ?? this.id,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      uid: uid ?? this.uid,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      category: category ?? this.category,
      region: region ?? this.region,
      upvotes: (upvotes ?? this.upvotes).clamp(0, double.infinity).toInt(),
      downvotes:
          (downvotes ?? this.downvotes).clamp(0, double.infinity).toInt(),
      userVote: userVote ?? this.userVote,
      userReported: userReported ?? this.userReported,
      reportReason: reportReason ?? this.reportReason,
      isPublic: isPublic ?? this.isPublic,
      commentCount: commentCount ?? this.commentCount,
      userName: userName ?? this.userName,
      reportCount: reportCount ?? this.reportCount,
      source: source ?? this.source,
      
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileUrl': fileUrl,
      'fileType': fileType,
      'uid': uid,
      'duration': duration,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'title': title,
      'category': category,
      'region': region,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'isPublic': isPublic,
      'commentCount': commentCount,
      'userName': userName,
      'reportCount': reportCount
    };
  }
}



class UserFartLibraryModel {
  final String id;
  final String uid;
  final String fartId;
  final String name;
  final String audioUrl;
  final String fileType;
  final String source;
  final String fartOwnerUid;
  final int createdAt;

  UserFartLibraryModel({
    required this.id,
    required this.uid,
    required this.fartId,
    required this.name,
    required this.audioUrl,
    required this.fileType,
    required this.source,
    required this.fartOwnerUid,
    required this.createdAt,
  });

  factory UserFartLibraryModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserFartLibraryModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      fartId: data['fartId'] ?? '',
      name: data['name'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      fileType: data['fileType'] ?? '',
      source: data['source'] ?? 'community',
      fartOwnerUid: data['fartOwnerUid'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).millisecondsSinceEpoch
          : (data['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fartId': fartId,
      'name': name,
      'audioUrl': audioUrl,
      'fileType': fileType,
      'source': source,
      'fartOwnerUid': fartOwnerUid,
      'createdAt': createdAt,
    };
  }

  UserFartLibraryModel copyWith({
    String? id,
    String? uid,
    String? fartId,
    String? name,
    String? audioUrl,
    String? fileType,
    String? source,
    String? fartOwnerUid,
    int? createdAt,
  }) {
    return UserFartLibraryModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      fartId: fartId ?? this.fartId,
      name: name ?? this.name,
      audioUrl: audioUrl ?? this.audioUrl,
      fileType: fileType ?? this.fileType,
      source: source ?? this.source,
      fartOwnerUid: fartOwnerUid ?? this.fartOwnerUid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

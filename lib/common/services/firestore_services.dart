// ignore_for_file: avoid_print

import 'package:flatch/common/models/app_user.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/models/comment_model.dart';
import 'package:flatch/common/models/fart_model.dart';

class FirestoreServices {
  FirestoreServices._();
  static final FirestoreServices instance = FirestoreServices._();

  //! fetch the user from the firebase
  Future<AppUser?> getSingleAppUser(String? uid) async {
    QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection("app_users")
            .where("uid", isEqualTo: uid)
            .get();
    if (snapshot.docs.isNotEmpty) {
      AppUser user = AppUser.fromMap(snapshot.docs.first.data());
      return user;
    } else {
      return null;
    }
  }
  //! fetch comments for a fart
  Future<List<CommentModel>> fetchComments(
    String fartId, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection('user_farts')
        .doc(fartId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final comments =
        snapshot.docs
            .map(
              (doc) => CommentModel.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();

    return comments;
  }

  Future<FartModel>   fetchFartById(String id)async{

    final fartRef = FirebaseFirestore.instance
        .collection('user_farts')
        .doc(id);
    final fartSnapshot = await fartRef.get();
    final fart = FartModel.fromMap(fartSnapshot.data() as Map<String, dynamic>);
    return fart;
  }


Future<void> addComment(String fartId, String text) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now().millisecondsSinceEpoch;

    final commentRef =
        FirebaseFirestore.instance
            .collection('user_farts')
            .doc(fartId)
            .collection('comments')
            .doc();

    await commentRef.set({
      'id': commentRef.id,
      'fartId': fartId,
      'uid': userId,
      'text': text,
      'upvotes': 0,
      'upvotedUserIds': [],
      'createdAt': now,
      'updatedAt': now,
      'parentCommentId': null,
    });

    final fartRef = FirebaseFirestore.instance
        .collection('user_farts')
        .doc(fartId);
    await fartRef.update({'commentCount': FieldValue.increment(1)});
  }


  //! Function for add User to Firestore
  Future<void> setUserActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('app_active_users')
        .doc(user.uid)
        .set({
          'isActive': true,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
  }

  Future<void> setUserInactive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('app_active_users')
        .doc(user.uid)
        .set({
          'isActive': false,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
  }

  Future<bool> addUserToFirestore(
    User user, {
    required String name,
    required String role,
    String? description,
    String? state,
    String? country,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection("app_users")
          .doc(user.uid)
          .set(
            AppUser(
              uid: user.uid,
              name: name,
              email: user.email ?? "not found",
              role: role,
              joinedOn: DateTime.now().millisecondsSinceEpoch,
              profileImage: user.photoURL ?? "",
              description: description ?? '',
              state: state ?? '',
              country: country ?? '',
            ).toMap(),
          );
      return true;
    } catch (e) {
      return false;
    }
  }

  //! getting subscription of the single

  //! fetvhing the profiles(gigs) of the consultant
}

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/models/comment_model.dart';
import 'package:flatch/common/models/fart_model.dart';

part 'fetch_farts_event.dart';
part 'fetch_farts_state.dart';

class FetchFartsBloc extends Bloc<FetchFartsEvent, FetchFartsState> {
  FetchFartsBloc() : super(FetchFartsInitial()) {
    final Set<String> activeVoteTransactions = {};
    const int limit = 30;
    
     

    on<FetchTopFarts>((event, emit) async {
      emit(FetchFartsLoading());
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          emit(FetchFartsFailure('User not logged in'));
          return;
        }

        Query query = FirebaseFirestore.instance
            .collection('user_farts')
            .where('isPublic', isEqualTo: true)
            .orderBy('upvotes', descending: true)
            .limit(limit);

        if (event.category != null && event.category!.isNotEmpty) {
          query = query.where('category', isEqualTo: event.category);
        }

        final snapshot = await query.get();

        final farts = await _enrichFarts(snapshot.docs, userId);

        emit(
          FetchFartsSuccess(
            farts: farts,
            lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
            hasMore: snapshot.docs.length == limit,
          ),
        );
      } catch (e) {
        emit(FetchFartsFailure(e.toString()));
      }
    });

    on<FetchMoreFarts>((event, emit) async {
      if (state is! FetchFartsSuccess) return;
      final currentState = state as FetchFartsSuccess;

      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) return;

        final query = FirebaseFirestore.instance
            .collection('user_farts')
            .where('isPublic', isEqualTo: true)
            .orderBy('upvotes', descending: true)
            .startAfterDocument(event.lastDoc)
            .limit(limit);

        final snapshot = await query.get();
        final farts = await _enrichFarts(snapshot.docs, userId);

        emit(
          FetchFartsSuccess(
            farts: [...currentState.farts, ...farts],
            lastDoc:
                snapshot.docs.isNotEmpty ? snapshot.docs.last : event.lastDoc,
            hasMore: snapshot.docs.length == limit,
          ),
        );
      } catch (e) {
        emit(FetchFartsFailure(e.toString()));
      }
    });

    on<VoteFart>((event, emit) async {
      final fartId = event.fartId;
      if (activeVoteTransactions.contains(fartId)) {
        print('⏳ Transaction already in progress for $fartId — skipping');
        return;
      }
      activeVoteTransactions.add(fartId);
      print('🟡 Vote started for fartId: $fartId with type: ${event.voteType}');

      final fartDoc = FirebaseFirestore.instance
          .collection('user_farts')
          .doc(fartId);
      final voteDoc = fartDoc
          .collection('votes')
          .doc(FirebaseAuth.instance.currentUser!.uid);

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final fartSnapshot = await transaction.get(fartDoc);
          if (!fartSnapshot.exists) {
            print('❌ Fart document not found');
            return;
          }

          final voteSnapshot = await transaction.get(voteDoc);
          final previousVote = voteSnapshot.data()?['type'] as String?;

          int upvotes = (fartSnapshot.data()?['upvotes'] ?? 0) as int;
          int downvotes = (fartSnapshot.data()?['downvotes'] ?? 0) as int;

          if (event.voteType == 'remove') {
            if (previousVote == 'upvote') upvotes--;
            if (previousVote == 'downvote') downvotes--;

            transaction.update(fartDoc, {
              'upvotes': upvotes.clamp(0, double.infinity).toInt(),
              'downvotes': downvotes.clamp(0, double.infinity).toInt(),
            });

            transaction.delete(voteDoc);
            return;
          }

          if (previousVote == event.voteType) return;

          if (previousVote == 'upvote') upvotes--;
          if (previousVote == 'downvote') downvotes--;

          if (event.voteType == 'upvote') {
            upvotes++;
          } else if (event.voteType == 'downvote') {
            downvotes++;
          }

          transaction.update(fartDoc, {
            'upvotes': upvotes.clamp(0, double.infinity).toInt(),
            'downvotes': downvotes.clamp(0, double.infinity).toInt(),
          });

          transaction.set(voteDoc, {
            'type': event.voteType,
            'votedAt': DateTime.now().millisecondsSinceEpoch,
          });
        });

        print('🟢 Vote transaction completed');
      } catch (e, st) {
        print('❌ Error during vote transaction: $e');
        print(st);
      } finally {
        activeVoteTransactions.remove(fartId);
      }
    });
    on<ReportFart>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final fartRef = FirebaseFirestore.instance
          .collection('user_farts')
          .doc(event.fartId);

      final reportRef = fartRef.collection('reports').doc(userId);

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final fartSnap = await txn.get(fartRef);
        if (!fartSnap.exists) return;

        final existingReport = await txn.get(reportRef);

        int currentCount = fartSnap.data()?['reportCount'] ?? 0;

        if (existingReport.exists) {
          txn.delete(reportRef);

          final newCount = (currentCount - 1).clamp(0, double.infinity).toInt();
          txn.update(fartRef, {'reportCount': newCount});
        } else {
          txn.set(reportRef, {
            'reportedAt': FieldValue.serverTimestamp(),
            'reason': event.reason,
            'userId': userId,
          });

          txn.update(fartRef, {'reportCount': currentCount + 1});
        }
      });
    });
   on<ReportCommentFart>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final commentRef = FirebaseFirestore.instance
          .collection('user_farts')
          .doc(event.fartId)
          .collection('comments')
          .doc(event.commentId);

      final reportRef = commentRef.collection('reports').doc(userId);

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final commentSnap = await txn.get(commentRef);
        if (!commentSnap.exists) return;

        final existingReport = await txn.get(reportRef);
        int currentCount = commentSnap.data()?['reportCount'] ?? 0;
        List<String> reportedUserIds = List<String>.from(
          commentSnap.data()?['reportedUserIds'] ?? [],
        );

        if (existingReport.exists) {
          // Undo report
          txn.delete(reportRef);

          final newCount = (currentCount - 1).clamp(0, double.infinity).toInt();
          reportedUserIds.remove(userId);

          txn.update(commentRef, {
            'reportCount': newCount,
            'reportedUserIds': reportedUserIds,
          });
        } else {
          // Add new report
          txn.set(reportRef, {
            'reportedAt': FieldValue.serverTimestamp(),
            'reason': event.reason,
            'userId': userId,
          });

          reportedUserIds.add(userId);

          txn.update(commentRef, {
            'reportCount': currentCount + 1,
            'reportedUserIds': reportedUserIds,
          });
        }
      });
    });



    on<_FartsUpdated>((event, emit) {
      emit(
        FetchFartsSuccess(
          farts: event.updatedFarts,
          lastDoc: null,
          hasMore: true,
        ),
      );
    });

    on<FetchCommentsFart>((event, emit) async {
      try {
        final query = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .limit(20);

        final snapshot = await query.get();
        final comments =
            snapshot.docs
                .map((doc) => CommentModel.fromMap(doc.data()))
                .toList();

        emit(
          FetchCommentsSuccess(
            fartId: event.fartId,
            comments: comments,
            lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
            hasMore: snapshot.docs.length == 20,
          ),
        );
      } catch (e) {
        emit(FetchCommentsFailure(fartId: event.fartId, error: e.toString()));
      }
    });

    on<FetchMoreCommentsFart>((event, emit) async {
      final currentState = state;
      if (currentState is! FetchCommentsSuccess ||
          currentState.fartId != event.fartId ||
          currentState.lastDoc == null ||
          !currentState.hasMore) {
        return;
      }

      try {
        final query = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .startAfterDocument(currentState.lastDoc!)
            .limit(20);

        final snapshot = await query.get();
        final moreComments =
            snapshot.docs
                .map((doc) => CommentModel.fromMap(doc.data()))
                .toList();

        emit(
          currentState.copyWith(
            comments: [...currentState.comments, ...moreComments],
            lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
            hasMore: snapshot.docs.length == 20,
          ),
        );
      } catch (e) {
        emit(FetchCommentsFailure(fartId: event.fartId, error: e.toString()));
      }
    });

   on<AddCommentFart>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final commentRef =
          FirebaseFirestore.instance
              .collection('user_farts')
              .doc(event.fartId)
              .collection('comments')
              .doc();

      final user = FirebaseAuth.instance.currentUser;
      final userDoc =
          await FirebaseFirestore.instance
              .collection('app_users')
              .doc(user!.uid)
              .get();

      final comment = CommentModel(
        id: commentRef.id,
        fartId: event.fartId,
        uid: userId,
        text: event.text,
        userName: userDoc.data()?['name'] ?? 'Anonymous',
        upvotes: 0,
        downvotes: 0,
        upvotedUserIds: [],
        downvotedUserIds: [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        parentCommentId: event.parentCommentId, // handle reply
      );

      try {
        // Save comment in Firestore
        await commentRef.set(comment.toMap());

        // Increment comment count in parent fart
        final fartDoc = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId);
        await fartDoc.update({'commentCount': FieldValue.increment(1)});

        // Update Bloc state
        final currentState = state;
        if (currentState is FetchCommentsSuccess &&
            currentState.fartId == event.fartId) {
          emit(
            currentState.copyWith(
              comments: [comment, ...currentState.comments],
              lastDoc: currentState.lastDoc,
              hasMore: currentState.hasMore,
            ),
          );
        } else {
          add(FetchCommentsFart(fartId: event.fartId));
        }
      } catch (e) {
        emit(FetchCommentsFailure(fartId: event.fartId, error: e.toString()));
      }
    });

    on<DeleteCommentFart>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      try {
        final commentRef = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId)
            .collection('comments')
            .doc(event.commentId);

        final commentSnap = await commentRef.get();

        if (!commentSnap.exists) return;

        final commentData = commentSnap.data() as Map<String, dynamic>;
        if ( !event.isAdmin && commentData['uid'] != userId) {
          return;
        }

        await commentRef.delete();

        final fartDoc = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId);
        await fartDoc.update({'commentCount': FieldValue.increment(-1)});

        final currentState = state;
        if (currentState is FetchCommentsSuccess &&
            currentState.fartId == event.fartId) {
          final updatedComments =
              currentState.comments
                  .where((c) => c.id != event.commentId)
                  .toList();

          emit(
            currentState.copyWith(
              comments: updatedComments,
              hasMore: currentState.hasMore,
              lastDoc: currentState.lastDoc,
            ),
          );
        }
      } catch (e) {
        emit(FetchCommentsFailure(fartId: event.fartId, error: e.toString()));
      }
    });
  on<VoteCommentFart>((event, emit) async {
      try {
        final commentRef = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId)
            .collection('comments')
            .doc(event.commentId);

        // Fetch the current comment data
        final commentSnapshot = await commentRef.get();
        if (!commentSnapshot.exists) throw Exception("Comment not found");

        final data = commentSnapshot.data()!;
        List<String> upvotedUserIds = List<String>.from(
          data['upvotedUserIds'] ?? [],
        );
        List<String> downvotedUserIds = List<String>.from(
          data['downvotedUserIds'] ?? [],
        );
        int upvotes = data['upvotes'] ?? 0;
        int downvotes = data['downvotes'] ?? 0;

        // Prepare update map
        Map<String, dynamic> updates = {};

        switch (event.voteType) {
          case 'upvote':
            if (downvotedUserIds.contains(event.userId)) {
              updates['downvotes'] = FieldValue.increment(-1);
              updates['downvotedUserIds'] = FieldValue.arrayRemove([
                event.userId,
              ]);
              downvotes--;
              downvotedUserIds.remove(event.userId);
            }
            if (!upvotedUserIds.contains(event.userId)) {
              updates['upvotes'] = FieldValue.increment(1);
              updates['upvotedUserIds'] = FieldValue.arrayUnion([event.userId]);
              upvotes++;
              upvotedUserIds.add(event.userId);
            }
            break;

          case 'downvote':
            if (upvotedUserIds.contains(event.userId)) {
              updates['upvotes'] = FieldValue.increment(-1);
              updates['upvotedUserIds'] = FieldValue.arrayRemove([
                event.userId,
              ]);
              upvotes--;
              upvotedUserIds.remove(event.userId);
            }
            if (!downvotedUserIds.contains(event.userId)) {
              updates['downvotes'] = FieldValue.increment(1);
              updates['downvotedUserIds'] = FieldValue.arrayUnion([
                event.userId,
              ]);
              downvotes++;
              downvotedUserIds.add(event.userId);
            }
            break;

          case 'remove_upvote':
            if (upvotedUserIds.contains(event.userId)) {
              updates['upvotes'] = FieldValue.increment(-1);
              updates['upvotedUserIds'] = FieldValue.arrayRemove([
                event.userId,
              ]);
              upvotes--;
              upvotedUserIds.remove(event.userId);
            }
            break;

          case 'remove_downvote':
            if (downvotedUserIds.contains(event.userId)) {
              updates['downvotes'] = FieldValue.increment(-1);
              updates['downvotedUserIds'] = FieldValue.arrayRemove([
                event.userId,
              ]);
              downvotes--;
              downvotedUserIds.remove(event.userId);
            }
            break;
        }

        if (updates.isNotEmpty) await commentRef.update(updates);

        if (state is FetchCommentsSuccess) {
          final currentState = state as FetchCommentsSuccess;
          final updatedComments =
              currentState.comments.map((c) {
                if (c.id == event.commentId) {
                  return c.copyWith(
                    upvotes: upvotes,
                    downvotes: downvotes,
                    upvotedUserIds: upvotedUserIds,
                    downvotedUserIds: downvotedUserIds,
                  );
                }
                return c;
              }).toList();

          emit(currentState.copyWith(comments: updatedComments));
        }
      } catch (e) {
        emit(FetchCommentsFailure(fartId: event.fartId, error: e.toString()));
      }
    });
on<EditCommentFart>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      try {
        final commentRef = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId)
            .collection('comments')
            .doc(event.commentId);

        final commentSnap = await commentRef.get();
        if (!commentSnap.exists) return;

        final data = commentSnap.data() as Map<String, dynamic>;
        if (data['uid'] != userId) return;

        await commentRef.update({
          'text': event.newText,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        final currentState = state;
        if (currentState is FetchCommentsSuccess &&
            currentState.fartId == event.fartId) {
          final updatedComments =
              currentState.comments.map((c) {
                if (c.id == event.commentId) {
                  return c.copyWith(
                    text: event.newText,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                  );
                }
                return c;
              }).toList();

          emit(currentState.copyWith(comments: updatedComments));
        }
      } catch (e) {
        emit(FetchCommentsFailure(fartId: event.fartId, error: e.toString()));
      }
    });


  }

  /// Enriches raw `user_farts` documents with each author's display name and the
  /// current user's vote/report state, then returns ready-to-render [FartModel]s.
  ///
  /// Author names are resolved with batched `whereIn` queries over deduplicated
  /// author ids (≤30 per query) instead of one `app_users` read per fart, so a
  /// page of clips by repeat authors costs far fewer reads. Vote/report state
  /// still needs one read per fart (they live in a per-fart subcollection keyed
  /// by user id), but those run concurrently to keep latency low. Eliminating
  /// them entirely would require denormalizing that state onto the fart doc.
  Future<List<FartModel>> _enrichFarts(
    List<QueryDocumentSnapshot> docs,
    String userId,
  ) async {
    if (docs.isEmpty) return const [];

    final firestore = FirebaseFirestore.instance;

    // 1) Resolve author names in batches of 30 (Firestore's `whereIn` limit).
    final uids = <String>{};
    for (final doc in docs) {
      final uid = (doc.data() as Map<String, dynamic>)['uid'];
      if (uid is String && uid.isNotEmpty) uids.add(uid);
    }

    final userNames = <String, String>{};
    final uidList = uids.toList();
    for (var i = 0; i < uidList.length; i += 30) {
      final end = (i + 30 < uidList.length) ? i + 30 : uidList.length;
      final chunk = uidList.sublist(i, end);
      final usersSnap =
          await firestore
              .collection('app_users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final userDoc in usersSnap.docs) {
        final name = userDoc.data()['name'];
        if (name is String) userNames[userDoc.id] = name;
      }
    }

    // 2) Resolve the current user's vote + report for each fart concurrently.
    return Future.wait(
      docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final id = doc.id;

        final snaps = await Future.wait([
          firestore
              .collection('user_farts')
              .doc(id)
              .collection('votes')
              .doc(userId)
              .get(),
          firestore
              .collection('user_farts')
              .doc(id)
              .collection('reports')
              .doc(userId)
              .get(),
        ]);
        final voteSnap = snaps[0];
        final reportSnap = snaps[1];

        final userVote =
            (voteSnap.exists && voteSnap.data() != null)
                ? voteSnap.data()!['type'] as String?
                : null;

        return FartModel.fromMap(
          data,
          userVote: userVote,
          userReported: reportSnap.exists,
          reportReason: reportSnap.data()?['reason'] as String?,
        ).copyWith(
          id: id,
          userName: userNames[data['uid']] ?? '',
          upvotes: data['upvotes'] ?? 0,
          downvotes: data['downvotes'] ?? 0,
        );
      }),
    );
  }
}

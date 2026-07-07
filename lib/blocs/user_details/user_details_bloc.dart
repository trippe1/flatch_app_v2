// ignore_for_file: avoid_print

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/models/app_user.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/services/firestore_services.dart';

part 'user_details_event.dart';
part 'user_details_state.dart';

class UserDetailsBloc extends Bloc<UserDetailsEvent, UserDetailsState> {
  UserDetailsBloc() : super(UserDetailsInitial()) {
        final Set<String> activeVoteTransactions = {};

    on<UserDetailsEvent>((event, emit) {});
    on<FetchUserDetails>((event, emit) async {
      try {
        emit(UserDetailsLoading());
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          emit(UserDetailsError('User not logged in'));
          return;
        }

        final AppUser? appUser = await FirestoreServices.instance
            .getSingleAppUser(event.uid);

        Query query = FirebaseFirestore.instance
            .collection('user_farts').where('uid', isEqualTo: event.uid)
            .where('isPublic', isEqualTo: true)
            .orderBy('upvotes', descending: true);

        final snapshot = await query.get();

        final futures = snapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final id = doc.id;
          String? userName;
          if (data['uid'] != null) {
            final userDoc =
                await FirebaseFirestore.instance
                    .collection('app_users')
                    .doc(data['uid'])
                    .get();
            userName = userDoc.data()?['name'];
          }

          final voteSnap =
              await FirebaseFirestore.instance
                  .collection('user_farts')
                  .doc(id)
                  .collection('votes')
                  .doc(userId)
                  .get();

          final userVote =
              (voteSnap.exists && voteSnap.data() != null)
                  ? voteSnap.data()!['type'] as String?
                  : null;

          final reportSnap =
              await FirebaseFirestore.instance
                  .collection('user_farts')
                  .doc(id)
                  .collection('reports')
                  .doc(userId)
                  .get();

          final userReported = reportSnap.exists;
          final reportReason = reportSnap.data()?['reason'] as String?;

          return FartModel.fromMap(
            data,
            userVote: userVote,

            userReported: userReported,
            reportReason: reportReason,
          ).copyWith(
            id: id,
            userName: userName,
            upvotes: data['upvotes'] ?? 0,
            downvotes: data['downvotes'] ?? 0,
          );
        });

        final farts = await Future.wait(futures);

        if (appUser != null) {
          emit(UserDetailsLoaded(appUser: appUser, farts: farts));
        }
      } catch (e) {
        emit(UserDetailsError(e.toString()));
      }
    });
     on<VoteUserVote>((event, emit) async {
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
     on<ReportUserFart>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final reportRef = FirebaseFirestore.instance
          .collection('user_farts')
          .doc(event.fartId)
          .collection('reports')
          .doc(userId);

      final existingReport = await reportRef.get();
      if (!existingReport.exists) {
        await reportRef.set({
          'reportedAt': DateTime.now().millisecondsSinceEpoch,
          'reason': event.reason,
          'userId': userId,
        });
      }
    });
  }
}

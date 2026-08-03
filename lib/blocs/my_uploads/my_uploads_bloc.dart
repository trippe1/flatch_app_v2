import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flatch/common/models/fart_model.dart';

part 'my_uploads_event.dart';
part 'my_uploads_state.dart';

class MyUploadsBloc extends Bloc<MyUploadsEvent, MyUploadsState> {
  MyUploadsBloc() : super(MyUploadsInitial()) {
    on<EditUploadName>((event, emit) async {
      if (state is! MyUploadsLoaded) return;

      final currentState = state as MyUploadsLoaded;

      await FirebaseFirestore.instance
          .collection('user_farts')
          .doc(event.id)
          .update({'title': event.newName});

      final updated =
          currentState.uploads.map((f) {
            if (f.id == event.id) {
              return f.copyWith(title: event.newName);
            }
            return f;
          }).toList();

      emit(currentState.copyWith(uploads: updated));
    });

    on<FetcnInitialUploads>((event, emit) async {
      emit(MyUploadsLoading());

      try {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null) {
          emit(const MyUploadsError(message: "User not logged in"));
          return;
        }

        final libraryQuery = FirebaseFirestore.instance
            .collection('user_fart_library')
            .where('uid', isEqualTo: currentUid)
            .orderBy('createdAt', descending: true)
            .limit(_limit);

        final librarySnapshot = await libraryQuery.get();

        final futures = librarySnapshot.docs.map((libDoc) async {
          final libData = libDoc.data();
          final fartId = libData['fartId'] as String?;
          final source = libData['source'];

          if (fartId == null || fartId.isEmpty) return null;

          final fartDoc =
              await FirebaseFirestore.instance
                  .collection('user_farts')
                  .doc(fartId)
                  .get();

          if (!fartDoc.exists) return null;

          final data = fartDoc.data() as Map<String, dynamic>;
          final id = fartDoc.id;
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
                  .doc(currentUid)
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
                  .doc(currentUid)
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
            source: source,
          );
        });

        final uploads =
            (await Future.wait(futures)).whereType<FartModel>().toList();

        emit(
          MyUploadsLoaded(
            uploads: uploads,
            lastDoc:
                librarySnapshot.docs.isNotEmpty
                    ? librarySnapshot.docs.last
                    : null,
            hasMore: librarySnapshot.docs.length == _limit,
          ),
        );
      } catch (e) {
        emit(MyUploadsError(message: e.toString()));
      }
    });

    on<FetchMoreUploads>((event, emit) async {
      if (state is! MyUploadsLoaded) return;
      final currentState = state as MyUploadsLoaded;

      try {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null) {
          emit(const MyUploadsError(message: "User not logged in"));
          return;
        }

        final query = FirebaseFirestore.instance
            .collection('user_farts')
            .where('uid', isEqualTo: currentUid)
            .orderBy('createdAt', descending: true)
            .startAfterDocument(event.lastDoc)
            .limit(_limit);

        final snapshot = await query.get();

        final newUploads =
            snapshot.docs.map((doc) => FartModel.fromMap(doc.data())).toList();

        emit(
          MyUploadsLoaded(
            uploads: [...currentState.uploads, ...newUploads],
            lastDoc:
                snapshot.docs.isNotEmpty
                    ? snapshot.docs.last
                    : currentState.lastDoc,
            hasMore: snapshot.docs.length == _limit,
          ),
        );
      } catch (e) {
        emit(MyUploadsError(message: e.toString()));
      }
    });
    on<DeleteUpload>((event, emit) async {
      if (state is! MyUploadsLoaded) return;
      final currentState = state as MyUploadsLoaded;

      try {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null) return;

        final fart = currentState.uploads.firstWhere((f) => f.id == event.id);

        // Library-only: remove just this user's saved copy; leave the public
        // community fart untouched. (Also the path for farts you don't own.)
        if (event.libraryOnly || fart.uid != currentUid) {
          final librarySnap =
              await FirebaseFirestore.instance
                  .collection('user_fart_library')
                  .where('uid', isEqualTo: currentUid)
                  .where('fartId', isEqualTo: event.id)
                  .limit(1)
                  .get();

          if (librarySnap.docs.isNotEmpty) {
            await librarySnap.docs.first.reference.delete();
          }

          final updatedUploads =
              currentState.uploads.where((f) => f.id != event.id).toList();

          emit(currentState.copyWith(uploads: updatedUploads));
          return;
        }

        final fartDocRef = FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.id);

        final fartDocSnapshot = await fartDocRef.get();
        final fileUrl = fartDocSnapshot.data()?['fileUrl'];

        if (fileUrl != null) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(fileUrl);
            await ref.delete();
          } catch (_) {}
        }

        await fartDocRef.delete();

        // Only remove OUR OWN library entries for this fart. Other users' saved
        // copies are theirs to delete — trying to delete them fails the security
        // rules (owner-only) and surfaced a false "permission denied" error even
        // though the fart itself was already deleted.
        final librarySnap =
            await FirebaseFirestore.instance
                .collection('user_fart_library')
                .where('fartId', isEqualTo: event.id)
                .where('uid', isEqualTo: currentUid)
                .get();

        for (final doc in librarySnap.docs) {
          await doc.reference.delete();
        }

        final updatedUploads =
            currentState.uploads.where((f) => f.id != event.id).toList();

        emit(currentState.copyWith(uploads: updatedUploads));
      } catch (e) {
        emit(MyUploadsError(message: 'Failed to delete: ${e.toString()}'));
      }
    });
  }

  static const int _limit = 20;
}

import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flatch/common/models/fart_model.dart';

part 'upload_fart_event.dart';
part 'upload_fart_state.dart';

class UploadFartBloc extends Bloc<UploadFartEvent, UploadFartState> {
  UploadFartBloc() : super(UploadFartInitial()) {
    on<UploadUserFart>(_onUploadUserFart);
    on<ResetUploadState>((event, emit) => emit(UploadFartInitial()));
  }

  Future<void> _onUploadUserFart(
    UploadUserFart event,
    Emitter<UploadFartState> emit,
  ) async {
    try {
      emit(UploadFartLoading());

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(const UploadFartFailure(error: 'User not authenticated'));
        return;
      }

      final File localFile = File(event.filePath);
      if (!localFile.existsSync()) {
        emit(const UploadFartFailure(error: 'Audio file not found'));
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('app_users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        emit(const UploadFartFailure(error: 'User profile not found'));
        return;
      }

      final userData = userDoc.data();
      final region = userData?['country'] ?? 'Unknown';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('farts')
          .child(user.uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.${event.fileType}');

      await storageRef.putFile(localFile);
      final downloadUrl = await storageRef.getDownloadURL();

      if (downloadUrl.isEmpty) {
        emit(const UploadFartFailure(error: 'Failed to upload audio file'));
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final fart = FartModel(
        id: '',
        fileUrl: downloadUrl,
        fileType: event.fileType,
        uid: user.uid,
        duration: event.duration,
        createdAt: now,
        updatedAt: now,
        // Always keep the user's real title (even for private sounds).
        title: event.title,
        category: '', // categories were removed from the upload flow
        isPublic: event.isPublic,
        upvotes: 0,
        downvotes: 0,
        userVote: null,
        region: region,
        commentCount: 0,
        reportCount: 0,
      );

      final docRef = await FirebaseFirestore.instance
          .collection('user_farts')
          .add(fart.toMap());

      await docRef.update({'id': docRef.id});
      final libraryDocRef =
          FirebaseFirestore.instance.collection('user_fart_library').doc();

      final libraryEntry = UserFartLibraryModel(
        id: libraryDocRef.id,
        uid: user.uid,
        fartId: docRef.id,
        name: fart.title,
        audioUrl: fart.fileUrl,
        fileType: fart.fileType,
        source: 'my_fart',
        fartOwnerUid: user.uid,
        createdAt: now,
      );

      await libraryDocRef.set(libraryEntry.toMap());

      emit(UploadFartSuccess());
    } catch (e) {
      emit(UploadFartFailure(error: e.toString()));
    }
  }
}

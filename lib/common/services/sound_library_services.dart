// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class SoundLibraryService {
  SoundLibraryService._();

  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

static Future<void> saveToLibrary({
    required BuildContext context,
    required FartModel fart,
    required String source,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _showToast(context, 'User not logged in', ToastificationType.error);
        return;
      }

      final existing =
          await _firestore
              .collection('user_fart_library')
              .where('uid', isEqualTo: uid)
              .where('fartId', isEqualTo: fart.id)
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty) {
        _showToast(
          context,
          'Already saved to Library',
          ToastificationType.info,
        );
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final libraryDocRef = _firestore.collection('user_fart_library').doc();

      final libraryEntry = UserFartLibraryModel(
        id: libraryDocRef.id,
        uid: uid,
        fartId: fart.id,
        name: fart.title,
        audioUrl: fart.fileUrl,
        fileType: fart.fileType,
        source: source,
        fartOwnerUid: fart.uid,
        createdAt: now,
      );

      await libraryDocRef.set(libraryEntry.toMap());

      _showToast(context, 'Saved to Library', ToastificationType.success);
    } catch (e) {
      _showToast(context, 'Failed to save sound', ToastificationType.error);
    }
  }


  static Future<void> shareSoundUrl({
    required String audioUrl,
    String? title,
  }) async {
    final params = ShareParams(
      subject: title ?? 'Sound',
      text:
          title != null
              ? '$title\n$audioUrl'
              : 'Check out this sound:\n$audioUrl',
    );

    await SharePlus.instance.share(params);
  }


  static void _showToast(
    BuildContext context,
    String message,
    ToastificationType type,
  ) {
    toastification.show(
      context: context,
      title: Text(message),
      type: type,
      autoCloseDuration: const Duration(seconds: 2),
    );
  }
}

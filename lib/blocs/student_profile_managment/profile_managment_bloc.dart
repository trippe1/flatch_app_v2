import 'dart:io';

import 'package:flatch/common/models/app_user.dart';
import 'package:flatch/common/models/custom_claims.dart';
import 'package:flatch/common/services/image_compressor.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'profile_managment_event.dart';
part 'profile_managment_state.dart';

class ProfileManagmentBloc
    extends Bloc<ProfileManagmentEvent, ProfileManagmentState> {
  ProfileManagmentBloc() : super(ProfileManagmentInitial()) {
    on<ProfileManagmentEvent>((event, emit) {});
    on<GetUserDetailsEvent>((event, emit) async {
      emit(ProfileManagmentLoading());
      try {
        final User user = FirebaseAuth.instance.currentUser!;

        QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection("app_users")
                .where("uid", isEqualTo: user.uid)
                .get();
        final AppUser appUser =
            snapshot.docs.map((e) => AppUser.fromMap(e.data())).toList().first;
        final CustomClaims claims = CustomClaims(role: appUser.role);
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final version = packageInfo.version;
        emit(
          ProfileManagmentLoaded(
            user: user,
            appUser: appUser,
            version: version,
            claims: claims,
          ),
        );
      } catch (e) {
        emit(ProfileManagmentError(e.toString()));
      }
    });
    on<UploadUserImageEvent>((event, emit) async {
      XFile? image = await ImagePicker().pickImage(source: event.source);
      if (image != null) {
        emit(const UploadingUserImageLoadingState());
        try {
          final String path = await ImageCompressor.instance.compressImage(
            image,
          );
          final File file = File(path);
          FirebaseStorage storage = FirebaseStorage.instance;
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw Exception("User not logged in");
          }
          final ref = storage.ref().child("images/${DateTime.now()}.png");
          UploadTask task = ref.putFile(file);
          TaskSnapshot taskSnapshot = await task;
          String url = await taskSnapshot.ref.getDownloadURL();
          await user.updatePhotoURL(url);

          final querySnapshot =
              await FirebaseFirestore.instance
                  .collection('app_users')
                  .where('uid', isEqualTo: user.uid)
                  .get();

          if (querySnapshot.docs.isNotEmpty) {
            final docId = querySnapshot.docs.first.id;

            await FirebaseFirestore.instance
                .collection('app_users')
                .doc(docId)
                .update({'profileImage': url});
          } else {
            throw Exception("User document not found in Firestore");
          }

          add(GetUserDetailsEvent());
        } catch (e) {
          emit(UploadingUserErrorState(error: e.toString()));
        }
      }
    });
  }
}

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flutter/material.dart';

part 'fetch_farts_state.dart';

class FetchFartsCubit extends Cubit<FetchFartsCubitState> {
  FetchFartsCubit() : super(FetchFartsCubitState());

  void selectCategory(String? category) {
    emit(state.copyWith(selectedCategory: category));
  }
  

  void setFarts(List<FartModel> farts) {
    emit(state.copyWith(farts: farts));
  }

  void updateFart(FartModel updatedFart) {
    final updatedList =
        state.farts.map((f) {
          return f.id == updatedFart.id ? updatedFart : f;
        }).toList();
    emit(state.copyWith(farts: updatedList));
  }

  void clearFarts() {
    emit(state.copyWith(farts: []));
  }
  void deleteFart(String fartId) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_farts')
          .doc(fartId)
          .delete();

      final updated = state.farts.where((f) => f.id != fartId).toList();

      emit(state.copyWith(farts: updated));
    } catch (e) {
      debugPrint(e.toString());
    }
  }




  void banUser(String userId, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('app_users')
          .doc(userId)
          .update({
            'isBan': true,
            'banReason': reason,
            'bannedAt': DateTime.now().millisecondsSinceEpoch,
          });
    } catch (e) {
      debugPrint(e.toString());
    }
  }
  void reinstateUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('app_users')
          .doc(userId)
          .update({
            'isBan': false,
            'banReason': FieldValue.delete(),
            'bannedAt': FieldValue.delete(),
          });
    } catch (e) {
      debugPrint(e.toString());
    }
  }


}

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flatch/common/models/fart_model.dart';

part 'admin_farts_event.dart';
part 'admin_farts_state.dart';

class AdminFartsBloc extends Bloc<AdminFartsEvent, AdminFartsState> {
  AdminFartsBloc() : super(AdminFartsInitial()) {
    on<FetchAdminFartsEvent>(_onFetchAdminFarts);
    on<DeleteFartEvent>(_onDeleteFart);
  }

  static const int limit = 5;
  Future<void> _onDeleteFart(
    DeleteFartEvent event,
    Emitter<AdminFartsState> emit,
  ) async {
    final currentState = state;
    if (currentState is AdminFartsLoaded) {
      try {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('user_farts')
            .doc(event.fartId)
            .delete();

        // Remove from current state without reloading
        final updatedFarts =
            currentState.farts.where((doc) => doc.id != event.fartId).toList();

        emit(currentState.copyWith(farts: updatedFarts));
      } catch (e) {
        emit(AdminFartsError('Failed to delete fart: ${e.toString()}'));
      }
    }
  }

Future<void> _onFetchAdminFarts(
    FetchAdminFartsEvent event,
    Emitter<AdminFartsState> emit,
  ) async {
    try {
      final currentState = state;
      List<FartModel> oldFarts = [];

      DocumentSnapshot? lastDoc = event.lastDoc;

      if (currentState is AdminFartsLoaded && event.lastDoc != null) {
        oldFarts = currentState.farts;
      } else {
        emit(AdminFartsLoading());
      }

      Query query = FirebaseFirestore.instance
          .collection('user_farts')
          .where('isPublic', isEqualTo: true)
          .orderBy('upvotes', descending: true)
          .limit(limit);

      if (event.category != null && event.category!.isNotEmpty) {
        query = query.where('category', isEqualTo: event.category);
      }

      if (event.lastDoc != null) {
        query = query.startAfterDocument(event.lastDoc!);
      }

      final snapshot = await query.get();

      // Enrich with userName for each fart
      final futures = snapshot.docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final uid = data['uid'];
        String? userName;
        if (uid != null && (uid as String).isNotEmpty) {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('app_users')
                  .doc(uid)
                  .get();
          userName = userDoc.data()?['name'];
        }

        return FartModel.fromMap({...data, 'id': doc.id, 'userName': userName});
      });

      final farts = await Future.wait(futures);
      final allFarts = [...oldFarts, ...farts];

      emit(
        AdminFartsLoaded(
          farts: allFarts,
          hasMore: farts.length == limit,
          lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : lastDoc,
        ),
      );
    } catch (e) {
      emit(AdminFartsError(e.toString()));
    }
  }

}

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class ModerationItem extends Equatable {
  final String fartId;
  final String uid;
  final String title;
  final String fileUrl;
  final String status; // auto_blocked | pending_review | error
  final bool adult;
  final double confidence;
  final String category;
  final String reason;

  const ModerationItem({
    required this.fartId,
    required this.uid,
    required this.title,
    required this.fileUrl,
    required this.status,
    required this.adult,
    required this.confidence,
    required this.category,
    required this.reason,
  });

  factory ModerationItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final verdict = (data['verdict'] as Map<String, dynamic>?) ?? {};
    return ModerationItem(
      fartId: (data['fartId'] ?? d.id) as String,
      uid: (data['uid'] ?? '') as String,
      title: (data['title'] ?? '') as String,
      fileUrl: (data['fileUrl'] ?? '') as String,
      status: (data['status'] ?? 'pending_review') as String,
      adult: (verdict['adult'] ?? false) as bool,
      confidence: ((verdict['confidence'] ?? 0) as num).toDouble(),
      category: (verdict['category'] ?? '') as String,
      reason: (verdict['reason'] ?? '') as String,
    );
  }

  @override
  List<Object?> get props => [fartId, status];
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class ModerationQueueEvent extends Equatable {
  const ModerationQueueEvent();
  @override
  List<Object?> get props => [];
}

class FetchModerationQueue extends ModerationQueueEvent {
  const FetchModerationQueue();
}

/// Content is fine: restore it to the public feed and clear it from the queue.
class ApproveModerationItem extends ModerationQueueEvent {
  final String fartId;
  const ApproveModerationItem(this.fartId);
  @override
  List<Object?> get props => [fartId];
}

/// Content violates policy: delete the fart (+ its audio file) and clear it.
class RemoveModerationItem extends ModerationQueueEvent {
  final String fartId;
  final String fileUrl;
  const RemoveModerationItem(this.fartId, this.fileUrl);
  @override
  List<Object?> get props => [fartId, fileUrl];
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------
abstract class ModerationQueueState extends Equatable {
  const ModerationQueueState();
  @override
  List<Object?> get props => [];
}

class ModerationQueueInitial extends ModerationQueueState {}

class ModerationQueueLoading extends ModerationQueueState {}

class ModerationQueueLoaded extends ModerationQueueState {
  final List<ModerationItem> items;
  const ModerationQueueLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class ModerationQueueError extends ModerationQueueState {
  final String message;
  const ModerationQueueError(this.message);
  @override
  List<Object?> get props => [message];
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------
class ModerationQueueBloc
    extends Bloc<ModerationQueueEvent, ModerationQueueState> {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ModerationQueueBloc({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance,
      super(ModerationQueueInitial()) {
    on<FetchModerationQueue>(_onFetch);
    on<ApproveModerationItem>(_onApprove);
    on<RemoveModerationItem>(_onRemove);
  }

  Future<void> _onFetch(
    FetchModerationQueue event,
    Emitter<ModerationQueueState> emit,
  ) async {
    emit(ModerationQueueLoading());
    try {
      // Show flagged items first (auto_blocked, then pending_review, then error),
      // newest first within the set.
      final snap =
          await _firestore
              .collection('moderation_queue')
              .orderBy('createdAt', descending: true)
              .limit(200)
              .get();
      final items = snap.docs.map(ModerationItem.fromDoc).toList();
      items.sort((a, b) => _rank(a.status).compareTo(_rank(b.status)));
      emit(ModerationQueueLoaded(items));
    } catch (e) {
      emit(ModerationQueueError(e.toString()));
    }
  }

  int _rank(String status) {
    switch (status) {
      case 'auto_blocked':
        return 0;
      case 'pending_review':
        return 1;
      default:
        return 2; // error / unknown
    }
  }

  Future<void> _onApprove(
    ApproveModerationItem event,
    Emitter<ModerationQueueState> emit,
  ) async {
    try {
      await _firestore.collection('user_farts').doc(event.fartId).update({
        'isPublic': true,
        'moderationStatus': 'approved',
      });
      await _firestore
          .collection('moderation_queue')
          .doc(event.fartId)
          .delete();
      _removeFromState(event.fartId, emit);
    } catch (e) {
      emit(ModerationQueueError(e.toString()));
    }
  }

  Future<void> _onRemove(
    RemoveModerationItem event,
    Emitter<ModerationQueueState> emit,
  ) async {
    try {
      // Best-effort delete of the audio file; ignore if already gone.
      if (event.fileUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(event.fileUrl).delete();
        } catch (_) {}
      }
      await _firestore.collection('user_farts').doc(event.fartId).delete();
      await _firestore
          .collection('moderation_queue')
          .doc(event.fartId)
          .delete();
      _removeFromState(event.fartId, emit);
    } catch (e) {
      emit(ModerationQueueError(e.toString()));
    }
  }

  void _removeFromState(String fartId, Emitter<ModerationQueueState> emit) {
    final s = state;
    if (s is ModerationQueueLoaded) {
      emit(
        ModerationQueueLoaded(
          s.items.where((i) => i.fartId != fartId).toList(),
        ),
      );
    }
  }
}

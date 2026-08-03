import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Persists the user's hand-arranged order for "My Fart Library".
///
/// Stored as an ordered list of fart ids on `user_settings/{uid}.libraryOrder`
/// — the same doc that already holds the FWB preferences, so it inherits the
/// owner-only rules and costs one read/write rather than touching every
/// library document.
class LibraryOrderService {
  LibraryOrderService._();

  static final _db = FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// The saved order, or an empty list if the user has never reordered.
  static Future<List<String>> load() async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      final doc = await _db.collection('user_settings').doc(uid).get();
      final raw = doc.data()?['libraryOrder'];
      return raw is List ? raw.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<String> fartIds) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('user_settings').doc(uid).set({
      'libraryOrder': fartIds,
    }, SetOptions(merge: true));
  }

  /// Applies [order] to [items].
  ///
  /// Anything not in the saved order (a fresh upload, or a sound saved from the
  /// community since the last drag) is treated as new and kept at the TOP,
  /// matching the default newest-first feel. Ordered items follow, in the
  /// arrangement the user chose.
  ///
  /// Deliberately avoids `List.sort` — it isn't stable in Dart, so unranked
  /// items would shuffle unpredictably between rebuilds.
  static List<T> apply<T>(
    List<T> items,
    List<String> order,
    String Function(T) idOf,
  ) {
    if (order.isEmpty) return items;
    final rank = <String, int>{
      for (var i = 0; i < order.length; i++) order[i]: i,
    };

    final ranked = <T>[];
    final fresh = <T>[];
    for (final item in items) {
      (rank.containsKey(idOf(item)) ? ranked : fresh).add(item);
    }
    ranked.sort((a, b) => rank[idOf(a)]!.compareTo(rank[idOf(b)]!));
    return [...fresh, ...ranked];
  }

  /// Merges a newly arranged page into the saved order.
  ///
  /// Only the ids currently on screen are being rearranged; ids the user has
  /// ordered before but that aren't loaded yet (pagination) must keep their
  /// positions instead of being silently dropped.
  static List<String> merge(List<String> visibleInNewOrder, List<String> saved) {
    final visible = visibleInNewOrder.toSet();
    return [...visibleInNewOrder, ...saved.where((id) => !visible.contains(id))];
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/models/fwb_models.dart';

/// Data layer for "Farts with Buddies" — groups, chat messages, membership,
/// the shareable invite link, and the per-user notification preference.
class FwbService {
  FwbService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const String _domain = 'https://flik.me';

  static String? get uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('fwb_groups');

  static CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _groups.doc(groupId).collection('messages');

  static String linkFor(String groupId) => '$_domain/fwb/$groupId';

  /// Groups the current user belongs to (newest first, sorted client-side to
  /// avoid a composite index).
  static Stream<List<FwbGroup>> myGroups() {
    final u = uid;
    if (u == null) return const Stream.empty();
    return _groups.where('members', arrayContains: u).snapshots().map((s) {
      final list = s.docs.map(FwbGroup.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  static Stream<FwbGroup?> groupStream(String groupId) => _groups
      .doc(groupId)
      .snapshots()
      .map((d) => d.exists ? FwbGroup.fromDoc(d) : null);

  static Future<FwbGroup?> getGroup(String groupId) async {
    final d = await _groups.doc(groupId).get();
    return d.exists ? FwbGroup.fromDoc(d) : null;
  }

  static Future<String> createGroup(String name, bool anonymous) async {
    final ref = _groups.doc();
    await ref.set({
      'name': name.trim(),
      'creatorUid': uid,
      'anonymous': anonymous,
      'members': [uid],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return ref.id;
  }

  static Future<void> joinGroup(String groupId) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  static Future<void> leaveGroup(FwbGroup g) async {
    final u = uid!;
    // Post the "left" note BEFORE removing membership — the message-create rule
    // requires the sender to still be a member. Skip it in anonymous groups.
    if (!g.anonymous) {
      final name = await displayName(u);
      await _messages(g.id).add({
        'senderUid': u,
        'type': 'system',
        'text': '$name left the group',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _groups.doc(g.id).update({
      'members': FieldValue.arrayRemove([u]),
    });
  }

  static Future<void> deleteGroup(String groupId) =>
      _groups.doc(groupId).delete();

  static Stream<List<FwbMessage>> messages(String groupId) => _messages(groupId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(FwbMessage.fromDoc).toList());

  static Future<void> sendText(String groupId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _messages(groupId).add({
      'senderUid': uid,
      'type': 'text',
      'text': t,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> sendFart(
    String groupId, {
    required String fileUrl,
    required String title,
    int? duration,
  }) async {
    await _messages(groupId).add({
      'senderUid': uid,
      'type': 'fart',
      'fileUrl': fileUrl,
      'title': title,
      'duration': duration ?? 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---- Name lookups (cached) --------------------------------------------
  static final Map<String, String> _nameCache = {};

  static Future<String> displayName(String memberUid) async {
    if (_nameCache.containsKey(memberUid)) return _nameCache[memberUid]!;
    try {
      final d = await _db.collection('app_users').doc(memberUid).get();
      final n = d.data()?['name'] as String?;
      final name = (n == null || n.isEmpty) ? 'Someone' : n;
      _nameCache[memberUid] = name;
      return name;
    } catch (_) {
      return 'Someone';
    }
  }

  // ---- Library farts (for the share-a-fart picker) ----------------------
  // Mirrors the "My Fart Library" screen: read the user's library rows, then
  // join each to its live `user_farts` doc so the picker shows the SAME set —
  // skipping rows whose fart was deleted and using the current title/fileUrl
  // (not the library row's cached copy, which can go stale after an edit).
  static Future<List<Map<String, dynamic>>> myLibrary() async {
    final u = uid;
    if (u == null) return const [];

    final snap = await _db
        .collection('user_fart_library')
        .where('uid', isEqualTo: u)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final futures = snap.docs.map((libDoc) async {
      final libData = libDoc.data();
      final fartId = libData['fartId'] as String?;
      if (fartId == null || fartId.isEmpty) return null;

      final fartDoc = await _db.collection('user_farts').doc(fartId).get();
      if (!fartDoc.exists) return null; // fart was deleted → not in the library

      final data = fartDoc.data() ?? const {};
      final fart = FartModel.fromMap(Map<String, dynamic>.from(data));
      if (fart.fileUrl.isEmpty) return null;

      return {
        'fartId': fartId,
        'title': fart.title, // live title (matches the library screen)
        'fileUrl': fart.fileUrl, // live audio URL
        'createdAt': libData['createdAt'] ?? 0,
      };
    });

    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }

  // ---- Notification preference ------------------------------------------
  static Future<bool> notificationsEnabled() async {
    final u = uid;
    if (u == null) return false;
    final d = await _db.collection('user_settings').doc(u).get();
    return d.data()?['fwbNotifications'] ?? true;
  }

  static Future<void> setNotifications(bool enabled) async {
    await _db.collection('user_settings').doc(uid).set({
      'fwbNotifications': enabled,
    }, SetOptions(merge: true));
  }

  // ---- Per-chat mute ----------------------------------------------------
  // Muted groups never push notifications to this user (checked alongside the
  // global toggle by the notify Cloud Function). Stored on the same
  // user_settings doc so it's one read server-side.

  /// The set of group ids the current user has muted, streamed live.
  static Stream<Set<String>> mutedGroups() {
    final u = uid;
    if (u == null) return Stream.value(const <String>{});
    return _db.collection('user_settings').doc(u).snapshots().map((d) {
      final list = d.data()?['mutedFwbGroups'];
      return list is List ? list.whereType<String>().toSet() : <String>{};
    });
  }

  static Future<bool> isGroupMuted(String groupId) async {
    final u = uid;
    if (u == null) return false;
    final d = await _db.collection('user_settings').doc(u).get();
    final list = d.data()?['mutedFwbGroups'];
    return list is List && list.contains(groupId);
  }

  static Future<void> setGroupMuted(String groupId, bool muted) async {
    final u = uid;
    if (u == null) return;
    await _db.collection('user_settings').doc(u).set({
      'mutedFwbGroups': muted
          ? FieldValue.arrayUnion([groupId])
          : FieldValue.arrayRemove([groupId]),
    }, SetOptions(merge: true));
  }
}

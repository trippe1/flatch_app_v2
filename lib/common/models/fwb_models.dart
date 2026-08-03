import 'package:cloud_firestore/cloud_firestore.dart';

/// A "Farts with Buddies" group. [anonymous] is fixed at creation: when true,
/// posts in the chat are attributed to "Anonymous" (the member list stays
/// viewable, but you can't tell who posted what).
class FwbGroup {
  final String id;
  final String name;
  final String creatorUid;
  final bool anonymous;
  final List<String> members;
  final int createdAt;

  const FwbGroup({
    required this.id,
    required this.name,
    required this.creatorUid,
    required this.anonymous,
    required this.members,
    required this.createdAt,
  });

  factory FwbGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return FwbGroup(
      id: d.id,
      name: (m['name'] as String?)?.trim().isNotEmpty == true
          ? m['name']
          : 'Group',
      creatorUid: m['creatorUid'] ?? '',
      anonymous: m['anonymous'] == true,
      members: List<String>.from(m['members'] ?? const []),
      createdAt: m['createdAt'] ?? 0,
    );
  }

  bool isCreator(String uid) => creatorUid == uid;
}

class FwbMessage {
  final String id;
  final String senderUid;
  final String type; // 'text' | 'fart' | 'system'
  final String? text;
  final String? fileUrl;
  final String? title;
  final int? duration;
  final int createdAt;

  const FwbMessage({
    required this.id,
    required this.senderUid,
    required this.type,
    this.text,
    this.fileUrl,
    this.title,
    this.duration,
    required this.createdAt,
  });

  factory FwbMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return FwbMessage(
      id: d.id,
      senderUid: m['senderUid'] ?? '',
      type: m['type'] ?? 'text',
      text: m['text'],
      fileUrl: m['fileUrl'],
      title: m['title'],
      duration: m['duration'],
      createdAt: m['createdAt'] ?? 0,
    );
  }

  bool get isSystem => type == 'system';
  bool get isFart => type == 'fart';
}

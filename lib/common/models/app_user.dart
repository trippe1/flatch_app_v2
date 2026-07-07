class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final int joinedOn;
  final String? profileImage;
  final String? description;
  final String? country;
  final String? state;

  // 🔒 Ban-related (nullable)
  final bool? isBan;
  final String? banReason;
  final int? bannedAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedOn,
    this.profileImage,
    this.description,
    this.country,
    this.state,
    this.isBan,
    this.banReason,
    this.bannedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'joinedOn': joinedOn,
      'profileImage': profileImage,
      'description': description,
      'country': country,
      'state': state,

      // ban fields (only stored if present)
      'isBan': isBan,
      'banReason': banReason,
      'bannedAt': bannedAt,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      joinedOn: map['joinedOn'] as int,
      profileImage: map['profileImage'] as String?,
      description: map['description'] as String?,
      country: map['country'] as String?,
      state: map['state'] as String?,

      // 👇 SAFE parsing (nullable)
      isBan: map['isBan'] as bool?,
      banReason: map['banReason'] as String?,
      bannedAt: map['bannedAt'] as int?,
    );
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    int? joinedOn,
    String? profileImage,
    String? description,
    String? country,
    String? state,
    bool? isBan,
    String? banReason,
    int? bannedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      joinedOn: joinedOn ?? this.joinedOn,
      profileImage: profileImage ?? this.profileImage,
      description: description ?? this.description,
      country: country ?? this.country,
      state: state ?? this.state,
      isBan: isBan ?? this.isBan,
      banReason: banReason ?? this.banReason,
      bannedAt: bannedAt ?? this.bannedAt,
    );
  }
}

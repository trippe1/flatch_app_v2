class CustomClaims {
  final String role; // Role can be 'Student', 'Consultant', or 'Admin'

  CustomClaims({required this.role});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'role': role};
  }

  factory CustomClaims.fromMap(Map<String, dynamic> map) {
    return CustomClaims(
      role: map['role'] as String, // Ensure that role is of type String
    );
  }

  // Additional helper methods to check the role
  bool get isAdmin => role == 'Admin';
  bool get isConsultant => role == 'Consultant';
  bool get isStudent => role == 'Student';
}

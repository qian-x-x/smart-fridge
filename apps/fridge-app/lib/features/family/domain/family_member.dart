class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    required this.currentUser,
  });

  final int userId;
  final String? username;
  final String displayName;
  final String role;
  final DateTime joinedAt;
  final bool currentUser;

  bool get isOwner => role == 'OWNER';
  bool get isEditor => role == 'EDITOR';

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String?,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      currentUser: json['currentUser'] as bool? ?? false,
    );
  }
}

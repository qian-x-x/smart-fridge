class FamilyInfo {
  const FamilyInfo({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUserId,
    required this.role,
    this.isDemo = false,
  });

  final int id;
  final String name;
  final String inviteCode;
  final int ownerUserId;
  final String role;
  final bool isDemo;

  bool get canManage => role == 'OWNER';

  factory FamilyInfo.fromJson(Map<String, dynamic> json) {
    return FamilyInfo(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      inviteCode: json['inviteCode'] as String,
      ownerUserId: (json['ownerUserId'] as num).toInt(),
      role: json['currentUserRole'] as String,
    );
  }

  static const demo = FamilyInfo(
    id: 0,
    name: '小满的家',
    inviteCode: 'MANS2026',
    ownerUserId: 0,
    role: 'OWNER',
    isDemo: true,
  );
}

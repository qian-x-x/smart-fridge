class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.username,
    this.phone,
    required this.role,
  });

  final int id;
  final String displayName;
  final String? username;
  final String? phone;
  final String role;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      displayName: json['displayName'] as String,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'USER',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'username': username,
    'phone': phone,
    'role': role,
  };
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
    this.isDemo = false,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserProfile user;
  final bool isDemo;

  factory AuthSession.fromApi(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      isDemo: json['isDemo'] as bool? ?? false,
    );
  }

  factory AuthSession.demo() {
    return const AuthSession(
      accessToken: 'demo-access',
      refreshToken: 'demo-refresh',
      expiresIn: 0,
      user: UserProfile(
        id: 0,
        displayName: '小满',
        username: 'demo_owner',
        role: 'USER',
      ),
      isDemo: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
    'user': user.toJson(),
    'isDemo': isDemo,
  };
}

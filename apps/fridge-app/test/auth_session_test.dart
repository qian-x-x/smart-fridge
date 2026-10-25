import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';

void main() {
  test('auth session survives local JSON round trip', () {
    const session = AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      user: UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );

    final restored = AuthSession.fromJson(session.toJson());

    expect(restored.accessToken, 'access');
    expect(restored.refreshToken, 'refresh');
    expect(restored.user.displayName, '小满');
    expect(restored.user.username, 'manman');
    expect(restored.isDemo, isFalse);
  });
}

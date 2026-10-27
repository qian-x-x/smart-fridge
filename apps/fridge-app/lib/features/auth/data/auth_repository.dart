import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final body = await _api.post('/api/v1/auth/login', {
      'identifier': identifier.trim(),
      'password': password,
    });
    return AuthSession.fromApi(body['data'] as Map<String, dynamic>);
  }

  Future<AuthSession> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final body = await _api.post('/api/v1/auth/register', {
      'username': username.trim(),
      'phone': null,
      'displayName': displayName.trim(),
      'password': password,
    });
    return AuthSession.fromApi(body['data'] as Map<String, dynamic>);
  }

  Future<AuthSession> refresh(AuthSession session) async {
    final body = await _api.post('/api/v1/auth/refresh', {
      'refreshToken': session.refreshToken,
    });
    return AuthSession.fromApi(body['data'] as Map<String, dynamic>);
  }

  Future<void> logout(AuthSession session) async {
    if (session.isDemo) {
      return;
    }
    await _api.post('/api/v1/auth/logout', {
      'refreshToken': session.refreshToken,
    }, accessToken: session.accessToken);
  }
}

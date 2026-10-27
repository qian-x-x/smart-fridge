import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/data/auth_repository.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';

void main() {
  test('refreshes an expired session with its refresh token', () async {
    final api = _RefreshApiClient();
    final repository = AuthRepository(api);
    final session = AuthSession(
      accessToken: 'expired-access',
      refreshToken: 'valid-refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );

    final refreshed = await repository.refresh(session);

    expect(api.path, '/api/v1/auth/refresh');
    expect(api.body, {'refreshToken': 'valid-refresh'});
    expect(refreshed.accessToken, 'new-access');
    expect(refreshed.refreshToken, 'new-refresh');
  });
}

class _RefreshApiClient extends ApiClient {
  _RefreshApiClient() : super(Dio());

  String? path;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    this.path = path;
    this.body = body;
    return {
      'code': 'OK',
      'message': 'success',
      'data': {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
        'tokenType': 'Bearer',
        'expiresIn': 1800,
        'user': {
          'id': 7,
          'displayName': '小满',
          'username': 'manman',
          'phone': null,
          'role': 'USER',
        },
      },
      'traceId': 'test',
    };
  }
}

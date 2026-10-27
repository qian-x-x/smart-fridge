import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';

void main() {
  test('restores an expired session by refreshing it', () async {
    final store = _MemorySessionStore(_expiredSession());
    final api = _AuthRefreshApiClient();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final session = await container.read(authControllerProvider.future);

    expect(api.refreshCalls, 1);
    expect(session?.accessToken, 'new-access');
    expect(store.session?.accessToken, 'new-access');
  });

  test('clears an invalid session when refresh is rejected', () async {
    final store = _MemorySessionStore(_expiredSession());
    final api = _AuthRefreshApiClient(failRefresh: true);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final session = await container.read(authControllerProvider.future);

    expect(session, isNull);
    expect(store.session, isNull);
    expect(store.clearCalls, 1);
  });
}

AuthSession _expiredSession() {
  return AuthSession(
    accessToken: 'expired-access',
    refreshToken: 'expired-refresh',
    expiresIn: 1800,
    issuedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    user: const UserProfile(
      id: 7,
      displayName: '小满',
      username: 'manman',
      role: 'USER',
    ),
  );
}

class _MemorySessionStore implements SessionStore {
  _MemorySessionStore(this.session);

  AuthSession? session;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    session = null;
  }

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async {
    this.session = session;
  }
}

class _AuthRefreshApiClient extends ApiClient {
  _AuthRefreshApiClient({this.failRefresh = false}) : super(Dio());

  final bool failRefresh;
  int refreshCalls = 0;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    if (path != '/api/v1/auth/refresh') {
      throw StateError('Unexpected POST $path');
    }
    refreshCalls++;
    if (failRefresh) {
      throw const ApiFailure(
        '刷新令牌已失效',
        statusCode: 401,
        code: 'UNAUTHORIZED',
      );
    }
    return {
      'code': 'OK',
      'message': 'success',
      'data': {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
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

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';

void main() {
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

  test('loads family list through the authenticated gateway', () async {
    final api = _FamilyApiClient();
    final repository = ApiFamilyRepository(api);

    final families = await repository.list(session);

    expect(families.single.name, 'S2 接口测试家庭');
    expect(families.single.inviteCode, 'TEST2026');
    expect(families.single.role, 'OWNER');
    expect(api.getPath, '/api/v1/families');
    expect(api.accessToken, 'access');
  });

  test('creates a family and returns its owner role', () async {
    final api = _FamilyApiClient();
    final repository = ApiFamilyRepository(api);

    final family = await repository.create(session, '第二家庭');

    expect(family.name, '第二家庭');
    expect(family.role, 'OWNER');
    expect(api.postPath, '/api/v1/families');
    expect(api.postBody, {'name': '第二家庭'});
  });
}

class _FamilyApiClient extends ApiClient {
  _FamilyApiClient() : super(Dio());

  String? getPath;
  String? postPath;
  String? accessToken;
  Map<String, dynamic>? postBody;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    getPath = path;
    this.accessToken = accessToken;
    return {
      'code': 'OK',
      'message': 'success',
      'data': [
        {
          'id': 4,
          'name': 'S2 接口测试家庭',
          'inviteCode': 'TEST2026',
          'ownerUserId': 7,
          'currentUserRole': 'OWNER',
          'createdAt': '2026-10-28T00:00:00Z',
        },
      ],
      'traceId': 'test',
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    postPath = path;
    postBody = body;
    this.accessToken = accessToken;
    return {
      'code': 'OK',
      'message': 'success',
      'data': {
        'id': 9,
        'name': body['name'],
        'inviteCode': 'SECOND26',
        'ownerUserId': 7,
        'currentUserRole': 'OWNER',
        'createdAt': '2026-10-28T00:00:00Z',
      },
      'traceId': 'test',
    };
  }
}

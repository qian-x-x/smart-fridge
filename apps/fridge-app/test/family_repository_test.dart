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

  test('creates a family workspace with an initialized fridge', () async {
    final api = _FamilyApiClient();
    final repository = ApiFamilyRepository(api);

    final family = await repository.create(session, '第二家庭');

    expect(family.name, '第二家庭');
    expect(family.role, 'OWNER');
    expect(api.postPath, '/api/v1/families/workspaces');
    expect(api.postBody!['name'], '第二家庭');
    expect(api.postBody!['requestId'], matches(r'^[A-Za-z0-9_-]{8,64}$'));
    expect(api.accessToken, 'access');
  });

  test('retries an uncertain creation with the same idempotency key', () async {
    final api = _FamilyApiClient()..failNext = true;
    final repository = ApiFamilyRepository(api);
    await expectLater(
      repository.create(session, ' 第二家庭 '),
      throwsA(isA<ApiFailure>()),
    );
    final requestId = api.postBody!['requestId'];
    await repository.create(session, '第二家庭');
    expect(api.postBody!['requestId'], requestId);
    await repository.create(session, '第二家庭');
    expect(api.postBody!['requestId'], isNot(requestId));
  });

  test('retains the request key if the fridge is not confirmed', () async {
    final api = _FamilyApiClient()..fridgeId = 0;
    final repository = ApiFamilyRepository(api);
    await expectLater(
      repository.create(session, '第二家庭'),
      throwsA(isA<ApiFailure>()),
    );
    final requestId = api.postBody!['requestId'];
    api.fridgeId = 10;
    await repository.create(session, '第二家庭');
    expect(api.postBody!['requestId'], requestId);
  });
}

class _FamilyApiClient extends ApiClient {
  _FamilyApiClient() : super(Dio());

  String? getPath;
  String? postPath;
  String? accessToken;
  Map<String, dynamic>? postBody;
  bool failNext = false;
  int fridgeId = 10;

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
    if (failNext) {
      failNext = false;
      throw const ApiFailure('连接中断');
    }
    return {
      'code': 'OK',
      'message': 'success',
      'data': {
        'fridgeId': fridgeId,
        'family': {
          'id': 9,
          'name': body['name'],
          'inviteCode': 'SECOND26',
          'ownerUserId': 7,
          'currentUserRole': 'OWNER',
          'createdAt': '2026-10-28T00:00:00Z',
        },
      },
      'traceId': 'test',
    };
  }
}

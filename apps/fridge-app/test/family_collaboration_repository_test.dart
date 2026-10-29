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

  test('joins a family with a normalized invite code', () async {
    final api = _CollaborationApiClient();
    final repository = ApiFamilyRepository(api);

    final family = await repository.join(session, ' test2026 ');

    expect(family.name, '新加入家庭');
    expect(family.role, 'VIEWER');
    expect(api.postPath, '/api/v1/families/join');
    expect(api.postBody, {'inviteCode': 'TEST2026'});
  });

  test('loads and manages family members', () async {
    final api = _CollaborationApiClient();
    final repository = ApiFamilyRepository(api);

    final members = await repository.listMembers(session, 4);
    final updated = await repository.updateMemberRole(session, 4, 9, 'EDITOR');
    await repository.removeMember(session, 4, 9);
    final family = await repository.transferOwner(session, 4, 9);

    expect(members.single.displayName, '家庭成员');
    expect(members.single.currentUser, isFalse);
    expect(updated.role, 'EDITOR');
    expect(api.getPath, '/api/v1/families/4/members');
    expect(api.patchPath, '/api/v1/families/4/members/9');
    expect(api.patchBody, {'role': 'EDITOR'});
    expect(api.deletePath, '/api/v1/families/4/members/9');
    expect(api.postPath, '/api/v1/families/4/transfer-owner');
    expect(api.postBody, {'targetUserId': 9});
    expect(family.role, 'EDITOR');
  });
}

class _CollaborationApiClient extends ApiClient {
  _CollaborationApiClient() : super(Dio());

  String? getPath;
  String? postPath;
  String? patchPath;
  String? deletePath;
  Map<String, dynamic>? postBody;
  Map<String, dynamic>? patchBody;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    getPath = path;
    return {
      'code': 'OK',
      'data': [
        {
          'userId': 9,
          'username': 'family_member',
          'displayName': '家庭成员',
          'role': 'VIEWER',
          'joinedAt': '2026-10-29T00:00:00Z',
          'currentUser': false,
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
    if (path.endsWith('/transfer-owner')) {
      return _familyResponse(role: 'EDITOR', ownerUserId: 9);
    }
    return _familyResponse(role: 'VIEWER', ownerUserId: 1);
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    patchPath = path;
    patchBody = body;
    return {
      'code': 'OK',
      'data': {
        'userId': 9,
        'username': 'family_member',
        'displayName': '家庭成员',
        'role': body['role'],
        'joinedAt': '2026-10-29T00:00:00Z',
        'currentUser': false,
      },
      'traceId': 'test',
    };
  }

  @override
  Future<void> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    deletePath = path;
  }

  Map<String, dynamic> _familyResponse({
    required String role,
    required int ownerUserId,
  }) {
    return {
      'code': 'OK',
      'data': {
        'id': 4,
        'name': '新加入家庭',
        'inviteCode': 'TEST2026',
        'ownerUserId': ownerUserId,
        'currentUserRole': role,
        'createdAt': '2026-10-29T00:00:00Z',
      },
      'traceId': 'test',
    };
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

final familyDataSourceProvider = Provider<FamilyDataSource>((ref) {
  return ApiFamilyRepository(ref.watch(apiClientProvider));
});

abstract interface class FamilyDataSource {
  Future<FamilyInfo> join(AuthSession session, String inviteCode);

  Future<List<FamilyMember>> listMembers(AuthSession session, int familyId);

  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  );

  Future<void> removeMember(AuthSession session, int familyId, int userId);

  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  );

  Future<List<FamilyInfo>> list(AuthSession session);

  Future<FamilyInfo> create(AuthSession session, String name);
}

class ApiFamilyRepository implements FamilyDataSource {
  ApiFamilyRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async {
    if (session.isDemo) {
      return const [FamilyInfo.demo];
    }
    final body = await _api.get(
      '/api/v1/families',
      accessToken: session.accessToken,
    );
    final data = body['data'];
    if (data is! List) {
      throw const ApiFailure('家庭列表格式不正确');
    }
    return data
        .map((value) => FamilyInfo.fromJson(_map(value)))
        .toList(growable: false);
  }

  @override
  Future<FamilyInfo> create(AuthSession session, String name) async {
    final body = await _api.post('/api/v1/families', {
      'name': name.trim(),
    }, accessToken: session.accessToken);
    return FamilyInfo.fromJson(_map(body['data']));
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
    final body = await _api.post('/api/v1/families/join', {
      'inviteCode': inviteCode.trim().toUpperCase(),
    }, accessToken: session.accessToken);
    return FamilyInfo.fromJson(_map(body['data']));
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async {
    final body = await _api.get(
      '/api/v1/families/$familyId/members',
      accessToken: session.accessToken,
    );
    final data = body['data'];
    if (data is! List) {
      throw const ApiFailure('家庭成员列表格式不正确');
    }
    return data
        .map((value) => FamilyMember.fromJson(_map(value)))
        .toList(growable: false);
  }

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) async {
    final body = await _api.patch(
      '/api/v1/families/$familyId/members/$userId',
      {'role': role},
      accessToken: session.accessToken,
    );
    return FamilyMember.fromJson(_map(body['data']));
  }

  @override
  Future<void> removeMember(AuthSession session, int familyId, int userId) {
    return _api.delete(
      '/api/v1/families/$familyId/members/$userId',
      accessToken: session.accessToken,
    );
  }

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) async {
    final body = await _api.post('/api/v1/families/$familyId/transfer-owner', {
      'targetUserId': targetUserId,
    }, accessToken: session.accessToken);
    return FamilyInfo.fromJson(_map(body['data']));
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const ApiFailure('家庭数据格式不正确');
  }
}

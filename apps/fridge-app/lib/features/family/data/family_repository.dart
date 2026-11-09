import 'dart:math';

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
  final _random = Random.secure();
  final Map<String, String> _pendingCreations = {};

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
    if (session.isDemo) throw StateError('请登录真实账号后管理家庭');
    final normalized = name.trim();
    final key = '${session.user.id}:$normalized';
    final requestId = _pendingCreations.putIfAbsent(
      key,
      () =>
          'workspace_${List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
    );
    final body = await _api.post('/api/v1/families/workspaces', {
      'name': normalized,
      'requestId': requestId,
    }, accessToken: session.accessToken);
    final workspace = _map(body['data']);
    if (workspace['fridgeId'] is! num || (workspace['fridgeId'] as num) <= 0) {
      throw const ApiFailure('家庭冰箱尚未初始化，请使用原请求重试');
    }
    final family = FamilyInfo.fromJson(_map(workspace['family']));
    _pendingCreations.remove(key);
    return family;
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

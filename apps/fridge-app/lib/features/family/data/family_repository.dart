import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';

final familyDataSourceProvider = Provider<FamilyDataSource>((ref) {
  return ApiFamilyRepository(ref.watch(apiClientProvider));
});

abstract interface class FamilyDataSource {
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
    final body = await _api.post(
      '/api/v1/families',
      {'name': name.trim()},
      accessToken: session.accessToken,
    );
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

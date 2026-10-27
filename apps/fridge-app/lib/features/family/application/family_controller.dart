import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';

final familyControllerProvider =
    AsyncNotifierProvider<FamilyController, List<FamilyInfo>>(
      FamilyController.new,
    );

class FamilyController extends AsyncNotifier<List<FamilyInfo>> {
  FamilyDataSource get _source => ref.read(familyDataSourceProvider);

  @override
  Future<List<FamilyInfo>> build() async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    return _source.list(await _freshSession(session));
  }

  Future<FamilyInfo> create(String name) async {
    final session = await _session();
    final family = await _source.create(session, name);
    state = AsyncData(await _source.list(session));
    return family;
  }

  Future<void> refresh() async {
    final session = await _session();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _source.list(session));
  }

  Future<AuthSession> _session() async {
    final session = await ref.read(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    return _freshSession(session);
  }

  Future<AuthSession> _freshSession(AuthSession session) async {
    if (!session.isAccessTokenExpiring) {
      return session;
    }
    return ref
        .read(authControllerProvider.notifier)
        .refreshAccessToken();
  }
}

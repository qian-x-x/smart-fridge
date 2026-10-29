import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

final familyMembersProvider =
    AsyncNotifierProvider<FamilyMembersController, List<FamilyMember>>(
      FamilyMembersController.new,
    );

class FamilyMembersController extends AsyncNotifier<List<FamilyMember>> {
  FamilyDataSource get _source => ref.read(familyDataSourceProvider);

  @override
  Future<List<FamilyMember>> build() async {
    final workspace = await ref.watch(familyControllerProvider.future);
    final family = workspace.selectedFamily;
    if (family == null) {
      return const [];
    }
    final session = await _session();
    return _source.listMembers(session, family.id);
  }

  Future<void> updateRole(int userId, String role) async {
    final session = await _session();
    final family = await _selectedFamily();
    await _mutate(() async {
      await _source.updateMemberRole(session, family.id, userId, role);
    });
  }

  Future<void> remove(int userId) async {
    final session = await _session();
    final family = await _selectedFamily();
    await _mutate(() => _source.removeMember(session, family.id, userId));
  }

  Future<void> transfer(int targetUserId) async {
    final session = await _session();
    final family = await _selectedFamily();
    final previous = state;
    try {
      await _source.transferOwner(session, family.id, targetUserId);
      await ref.read(familyControllerProvider.notifier).refresh();
      state = AsyncData(await _source.listMembers(session, family.id));
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    final session = await _session();
    final family = await _selectedFamily();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _source.listMembers(session, family.id),
    );
  }

  Future<void> _mutate(Future<void> Function() action) async {
    final session = await _session();
    final family = await _selectedFamily();
    final previous = state;
    try {
      await action();
      state = AsyncData(await _source.listMembers(session, family.id));
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<({int id})> _selectedFamily() async {
    final workspace = await ref.read(familyControllerProvider.future);
    final family = workspace.selectedFamily;
    if (family == null) {
      throw StateError('当前没有可用的家庭');
    }
    return (id: family.id);
  }

  Future<AuthSession> _session() async {
    var session = await ref.read(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    if (session.isAccessTokenExpiring) {
      session = await ref
          .read(authControllerProvider.notifier)
          .refreshAccessToken();
    }
    return session;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_workspace_state.dart';

final familyControllerProvider =
    AsyncNotifierProvider<FamilyController, FamilyWorkspaceState>(
      FamilyController.new,
    );

class FamilyController extends AsyncNotifier<FamilyWorkspaceState> {
  FamilyDataSource get _source => ref.read(familyDataSourceProvider);
  FamilySelectionStore get _selectionStore =>
      ref.read(familySelectionStoreProvider);

  @override
  Future<FamilyWorkspaceState> build() async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    final freshSession = await _freshSession(session);
    final families = await _source.list(freshSession);
    if (freshSession.isDemo) {
      return FamilyWorkspaceState(
        families: families,
        selectedFamilyId: families.firstOrNull?.id,
      );
    }
    if (families.isEmpty) {
      await _selectionStore.clear(freshSession.user.id);
      return const FamilyWorkspaceState(families: [], selectedFamilyId: null);
    }

    final storedId = await _selectionStore.read(freshSession.user.id);
    final selectedId = families.any((family) => family.id == storedId)
        ? storedId!
        : families.first.id;
    await _selectionStore.write(freshSession.user.id, selectedId);
    return FamilyWorkspaceState(
      families: families,
      selectedFamilyId: selectedId,
    );
  }

  Future<FamilyInfo> create(String name) async {
    final session = await _session();
    if (session.isDemo) throw StateError('请登录真实账号后管理家庭');
    final family = await _source.create(session, name);
    await _replaceFamiliesAndSelect(session, family);
    return family;
  }

  Future<FamilyInfo> join(String inviteCode) async {
    final session = await _session();
    if (session.isDemo) throw StateError('请登录真实账号后管理家庭');
    final family = await _source.join(session, inviteCode.trim().toUpperCase());
    await _replaceFamiliesAndSelect(session, family);
    return family;
  }

  Future<void> selectFamily(int familyId) async {
    final session = await _session();
    final current = state.requireValue;
    if (!current.families.any((family) => family.id == familyId)) {
      throw StateError('家庭不存在或无权访问');
    }
    if (!session.isDemo) await _selectionStore.write(session.user.id, familyId);
    state = AsyncData(current.withSelectedFamily(familyId));
  }

  Future<void> refresh() async {
    final session = await _session();
    final previousId = state.value?.selectedFamilyId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final families = await _source.list(session);
      if (session.isDemo) {
        return FamilyWorkspaceState(
          families: families,
          selectedFamilyId: families.firstOrNull?.id,
        );
      }
      if (families.isEmpty) {
        await _selectionStore.clear(session.user.id);
        return const FamilyWorkspaceState(families: [], selectedFamilyId: null);
      }
      final selectedId = families.any((family) => family.id == previousId)
          ? previousId!
          : families.first.id;
      await _selectionStore.write(session.user.id, selectedId);
      return FamilyWorkspaceState(
        families: families,
        selectedFamilyId: selectedId,
      );
    });
  }

  Future<void> _replaceFamiliesAndSelect(
    AuthSession session,
    FamilyInfo selected,
  ) async {
    final families = await _source.list(session);
    await _selectionStore.write(session.user.id, selected.id);
    state = AsyncData(
      FamilyWorkspaceState(families: families, selectedFamilyId: selected.id),
    );
  }

  FamilyInfo? get selectedFamily {
    return state.value?.selectedFamily;
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
    return ref.read(authControllerProvider.notifier).refreshAccessToken();
  }
}

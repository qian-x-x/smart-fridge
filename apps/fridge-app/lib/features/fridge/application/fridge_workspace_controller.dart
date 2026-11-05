import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/domain/family_workspace_state.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

final fridgeWorkspaceProvider =
    AsyncNotifierProvider<FridgeWorkspaceController, FridgeWorkspaceData>(
      FridgeWorkspaceController.new,
    );

class FridgeWorkspaceController extends AsyncNotifier<FridgeWorkspaceData> {
  FridgeDataSource get _source => ref.read(fridgeDataSourceProvider);

  @override
  Future<FridgeWorkspaceData> build() async {
    var session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    if (session.isAccessTokenExpiring) {
      session = await _session();
    }
    final workspace = await ref.watch(familyControllerProvider.future);
    return _load(session, workspace);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // The provider exposes the error with a retry action on the page.
    }
  }

  Future<void> addFood(NewFoodInput input) async {
    final session = await _requireEditableSession();
    final workspace = state.requireValue;
    await _mutate(() => _source.addFood(session, workspace, input));
  }

  Future<void> createFridge(String name) async {
    final session = await _session();
    final family = (await ref.read(familyControllerProvider.future))
        .selectedFamily;
    if (session.isDemo || family?.role != 'OWNER') {
      throw StateError('仅家庭拥有者可以创建冰箱');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw StateError('请输入 1 至 80 个字符的冰箱名称');
    }
    await _mutate(() => _source.createFridge(session, family!.id, trimmed));
  }

  Future<void> moveFood(FridgeFood food, FridgeZone targetZone) async {
    final session = await _requireEditableSession();
    await _mutate(() => _source.moveFood(session, food, targetZone));
  }

  Future<void> consume(FridgeFood food, double quantity) async {
    final session = await _requireEditableSession();
    await _mutate(() => _source.consume(session, food, quantity));
  }

  Future<void> discard(FridgeFood food) async {
    final session = await _requireEditableSession();
    await _mutate(() => _source.discardFood(session, food));
  }

  Future<List<FoodOperation>> loadOperations(int fridgeId) async {
    final session = await _session();
    if (session.isDemo) {
      throw StateError('演示模式不能查看真实操作记录');
    }
    return _source.loadOperations(session, fridgeId);
  }

  Future<void> undoOperation(FoodOperation operation) async {
    final session = await _requireEditableSession();
    await _source.undoOperation(session, operation);
    ref.invalidateSelf();
  }

  Future<void> restoreOperation(FoodOperation operation) async {
    final session = await _requireEditableSession();
    await _source.restoreOperation(session, operation);
    ref.invalidateSelf();
  }

  Future<void> cook({
    required int fridgeId,
    required int recipeId,
    required String recipeName,
    required int servings,
    required List<CookItemInput> items,
  }) async {
    final session = await _requireEditableSession();
    if (items.isEmpty) {
      throw StateError('请至少选择一种要扣减的食材');
    }
    await _source.cook(
      session,
      fridgeId: fridgeId,
      recipeId: recipeId,
      recipeName: recipeName,
      servings: servings,
      items: items,
      requestId: _cookRequestId(),
    );
    ref.invalidateSelf();
  }

  String _cookRequestId() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'cook-$stamp-$salt';
  }

  Future<FridgeWorkspaceData> _load(
    AuthSession session,
    FamilyWorkspaceState families,
  ) async {
    if (session.isDemo) {
      return _source.load(session, 0);
    }
    final family = families.selectedFamily;
    if (family == null) {
      throw StateError('当前账号尚未加入家庭');
    }
    final loaded = await _source.load(session, family.id);
    return loaded.withFamilyIdentity(
      familyId: family.id,
      familyName: family.name,
      role: family.role,
    );
  }

  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    // A committed write succeeds independently of the following read. Let the
    // workspace show loading/error and retry reads without resubmitting writes.
    ref.invalidateSelf();
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

  Future<AuthSession> _requireEditableSession() async {
    final session = await _session();
    if (session.isDemo) {
      throw StateError('演示模式不能修改真实冰箱');
    }
    if (!state.requireValue.canEdit) {
      throw StateError('当前家庭成员没有编辑权限');
    }
    return session;
  }
}

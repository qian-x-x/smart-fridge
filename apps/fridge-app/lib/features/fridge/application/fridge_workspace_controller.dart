import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

final fridgeWorkspaceProvider =
    AsyncNotifierProvider<FridgeWorkspaceController, FridgeWorkspaceData>(
      FridgeWorkspaceController.new,
    );

class FridgeWorkspaceController extends AsyncNotifier<FridgeWorkspaceData> {
  FridgeDataSource get _source => ref.read(fridgeDataSourceProvider);

  @override
  Future<FridgeWorkspaceData> build() async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    return _source.load(session);
  }

  Future<void> refresh() async {
    final session = await _session();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _source.load(session));
  }

  Future<void> addFood(NewFoodInput input) async {
    final session = await _requireEditableSession();
    final workspace = state.requireValue;
    await _mutate(() async {
      await _source.addFood(session, workspace, input);
    });
  }

  Future<void> moveFood(FridgeFood food, FridgeZone targetZone) async {
    final session = await _requireEditableSession();
    await _mutate(() async {
      await _source.moveFood(session, food, targetZone);
    });
  }

  Future<void> consume(FridgeFood food, double quantity) async {
    final session = await _requireEditableSession();
    await _mutate(() async {
      await _source.consume(session, food, quantity);
    });
  }

  Future<void> discard(FridgeFood food) async {
    final session = await _requireEditableSession();
    await _mutate(() async {
      await _source.discardFood(session, food);
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    final session = await _session();
    final previous = state;
    try {
      await action();
      state = AsyncData(await _source.load(session));
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
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

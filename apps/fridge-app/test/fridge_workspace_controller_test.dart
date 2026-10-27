import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

void main() {
  test('real sessions load fridge data through the repository', () async {
    final source = _FakeFridgeDataSource();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(_RealSessionStore()),
        fridgeDataSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);

    final workspace = await container.read(fridgeWorkspaceProvider.future);

    expect(workspace.familyId, 4);
    expect(workspace.fridgeId, 1);
    expect(workspace.foods.single.name, '测试牛奶');
    expect(source.loadCount, 1);
  });
}

class _FakeFridgeDataSource implements FridgeDataSource {
  int loadCount = 0;

  @override
  Future<FridgeWorkspaceData> load(AuthSession session) async {
    loadCount++;
    return const FridgeWorkspaceData(
      familyId: 4,
      familyName: '小满的家',
      role: 'OWNER',
      fridgeId: 1,
      fridgeName: '厨房冰箱',
      timezone: 'Asia/Shanghai',
      zones: [
        FridgeZone(
          id: FridgeZoneId.fresh,
          serverId: 11,
          name: '冷藏',
          description: '蔬果 · 饮品 · 熟食',
          temperature: '4°C',
          emoji: '🥬',
        ),
      ],
      foods: [
        FridgeFood(
          id: '31',
          serverId: 31,
          name: '测试牛奶',
          emoji: '🥛',
          quantity: 2,
          unit: '盒',
          expiresInDays: 5,
          zone: FridgeZoneId.fresh,
          category: '蛋奶',
          owner: '小满',
          tilt: 0,
        ),
      ],
    );
  }

  @override
  Future<void> addFood(
    AuthSession session,
    FridgeWorkspaceData workspace,
    NewFoodInput input,
  ) async {}

  @override
  Future<void> consume(
    AuthSession session,
    FridgeFood food,
    double quantity,
  ) async {}

  @override
  Future<void> discardFood(AuthSession session, FridgeFood food) async {}

  @override
  Future<void> moveFood(
    AuthSession session,
    FridgeFood food,
    FridgeZone targetZone,
  ) async {}
}

class _RealSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc(),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {}
}

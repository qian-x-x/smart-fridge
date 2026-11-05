import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

void main() {
  test(
    'successful add is not retried when only the inventory reload fails',
    () async {
      final source = _FakeFridgeDataSource()..failAfterWrite = true;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sessionStoreProvider.overrideWithValue(_RealSessionStore()),
          familyDataSourceProvider.overrideWithValue(_FridgeFamilySource()),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final workspace = await container.read(fridgeWorkspaceProvider.future);
      final controller = container.read(fridgeWorkspaceProvider.notifier);
      await controller.addFood(
        NewFoodInput(
          zone: workspace.zones.first,
          name: '新食材',
          category: '其他',
          quantity: 1,
          unit: '份',
          productionDate: DateTime(2026, 10, 31),
          expiresOn: DateTime(2026, 11, 1),
        ),
      );
      expect(source.writes, 1);
      await expectLater(
        container.read(fridgeWorkspaceProvider.future),
        throwsA(isA<ApiFailure>()),
      );
      expect(container.read(fridgeWorkspaceProvider).hasError, isTrue);
      await controller.refresh();
      expect(container.read(fridgeWorkspaceProvider).hasValue, isTrue);
      expect(source.writes, 1);
    },
  );
  test(
    'creation validates name and requires the selected family owner',
    () async {
      final source = _FakeFridgeDataSource();
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RealSessionStore()),
          familyDataSourceProvider.overrideWithValue(_FridgeFamilySource()),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      await container.read(fridgeWorkspaceProvider.future);
      final controller = container.read(fridgeWorkspaceProvider.notifier);
      await expectLater(controller.createFridge('  '), throwsStateError);
      await expectLater(controller.createFridge('名' * 81), throwsStateError);
      expect(source.createdFamilyId, isNull);
      await controller.createFridge(' 厨房冰箱 ');
      expect(source.createdFamilyId, 4);
      expect(source.createdName, '厨房冰箱');
      await container.read(familyControllerProvider.notifier).selectFamily(5);
      await container.read(fridgeWorkspaceProvider.future);
      await expectLater(controller.createFridge('新冰箱'), throwsStateError);
      expect(source.createdFamilyId, 4);
    },
  );
  test('loads the selected family and reloads after switching', () async {
    final fridgeSource = _FakeFridgeDataSource();
    final familySource = _FridgeFamilySource();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(_RealSessionStore()),
        familyDataSourceProvider.overrideWithValue(familySource),
        familySelectionStoreProvider.overrideWithValue(_FridgeSelectionStore()),
        fridgeDataSourceProvider.overrideWithValue(fridgeSource),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(fridgeWorkspaceProvider.future);
    expect(first.familyId, 4);
    expect(first.familyName, '小满的家');
    expect(fridgeSource.lastFamilyId, 4);

    await container.read(familyControllerProvider.notifier).selectFamily(5);
    final second = await container.read(fridgeWorkspaceProvider.future);

    expect(second.familyId, 5);
    expect(second.familyName, '父母的厨房');
    expect(fridgeSource.lastFamilyId, 5);
  });
}

class _FakeFridgeDataSource implements FridgeDataSource {
  bool failAfterWrite = false;
  bool failNextLoad = false;
  int writes = 0;
  int? createdFamilyId;
  String? createdName;
  @override
  Future<void> createFridge(
    AuthSession session,
    int familyId,
    String name,
  ) async {
    createdFamilyId = familyId;
    createdName = name;
  }

  int? lastFamilyId;

  @override
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async {
    if (failNextLoad) {
      failNextLoad = false;
      throw const ApiFailure('读取库存失败');
    }
    lastFamilyId = familyId;
    return FridgeWorkspaceData(
      familyId: familyId,
      familyName: familyId == 4 ? '小满的家' : '父母的厨房',
      role: familyId == 4 ? 'OWNER' : 'EDITOR',
      fridgeId: familyId,
      fridgeName: '厨房冰箱',
      timezone: 'Asia/Shanghai',
      zones: const [
        FridgeZone(
          id: FridgeZoneId.fresh,
          serverId: 11,
          name: '冷藏',
          description: '蔬果 · 饮品 · 熟食',
          temperature: '4°C',
          emoji: '🥬',
        ),
      ],
      foods: const [
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
  ) async {
    writes++;
    failNextLoad = failAfterWrite;
  }

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

class _FridgeFamilySource implements FamilyDataSource {
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => const [
    FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
    ),
    FamilyInfo(
      id: 5,
      name: '父母的厨房',
      inviteCode: 'PARENT26',
      ownerUserId: 9,
      role: 'EDITOR',
    ),
  ];

  @override
  Future<FamilyInfo> create(AuthSession session, String name) {
    throw UnimplementedError();
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async => const [];

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {}

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) {
    throw UnimplementedError();
  }
}

class _FridgeSelectionStore implements FamilySelectionStore {
  int? selectedFamilyId = 4;

  @override
  Future<int?> read(int userId) async => selectedFamilyId;

  @override
  Future<void> write(int userId, int familyId) async {
    selectedFamilyId = familyId;
  }

  @override
  Future<void> clear(int userId) async {
    selectedFamilyId = null;
  }
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

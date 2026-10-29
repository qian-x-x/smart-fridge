import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  int? lastFamilyId;

  @override
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async {
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

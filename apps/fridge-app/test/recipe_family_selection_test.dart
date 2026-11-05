import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/recipe/application/recipe_controller.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

void main() {
  test('recipe matching reloads after switching family', () async {
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(_RecipeFamilySessionStore()),
        familyDataSourceProvider.overrideWithValue(_RecipeFamilySource()),
        familySelectionStoreProvider.overrideWithValue(
          _RecipeFamilySelectionStore(),
        ),
        fridgeDataSourceProvider.overrideWithValue(_RecipeFamilyFridgeSource()),
        recipeDataSourceProvider.overrideWithValue(_ToFuRecipeSource()),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(recipeBrowserProvider.future);
    await container.read(familyControllerProvider.notifier).selectFamily(5);
    final second = await container.read(recipeBrowserProvider.future);

    expect(first.single.score, 100);
    expect(second.single.score, 0);
  });
}

class _RecipeFamilyFridgeSource implements FridgeDataSource {
  @override
  Future<void> createFridge(
    AuthSession session,
    int familyId,
    String name,
  ) async {}

  @override
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async {
    return FridgeWorkspaceData(
      familyId: familyId,
      familyName: familyId == 4 ? '小满的家' : '父母的厨房',
      role: 'OWNER',
      fridgeId: familyId,
      fridgeName: '厨房冰箱',
      timezone: 'Asia/Shanghai',
      zones: const [
        FridgeZone(
          id: FridgeZoneId.fresh,
          serverId: 11,
          name: '冷藏',
          description: '冷藏',
          temperature: '4°C',
          emoji: '🥬',
        ),
      ],
      foods: familyId == 4
          ? const [
              FridgeFood(
                id: '10',
                name: '嫩豆腐',
                emoji: '🥣',
                quantity: 1,
                unit: '盒',
                expiresInDays: 2,
                zone: FridgeZoneId.fresh,
                category: '豆制品',
                owner: '小满',
                tilt: 0,
              ),
            ]
          : const [],
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

class _ToFuRecipeSource implements RecipeDataSource {
  @override
  Future<List<Recipe>> load(AuthSession session) async {
    return const [
      Recipe(
        id: 99,
        name: '香煎测试豆腐',
        summary: '接口菜谱',
        category: '测试菜',
        durationMinutes: 12,
        calories: 180,
        difficulty: '简单',
        servings: 2,
        coverEmoji: '🍳',
        steps: ['切豆腐', '煎熟'],
        featured: true,
        ingredients: [RecipeIngredient(name: '嫩豆腐', quantity: 1, unit: '盒')],
      ),
    ];
  }
}

class _RecipeFamilySource implements FamilyDataSource {
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

class _RecipeFamilySelectionStore implements FamilySelectionStore {
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

class _RecipeFamilySessionStore implements SessionStore {
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

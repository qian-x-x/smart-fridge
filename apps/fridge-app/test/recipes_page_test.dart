import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';
import 'package:smart_fridge_app/features/recipe/presentation/recipes_page.dart';
import 'package:smart_fridge_app/features/recipe/application/recipe_controller.dart';

void main() {
  for (final width in [390.0, 1366.0]) {
    testWidgets(
      'empty expiry filter can return to all recipes at width $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recipeBrowserProvider.overrideWith(_NoExpiringRecipes.new),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: RecipesPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('临期优先'));
        await tester.pumpAndSettle();
        expect(find.text('当前筛选下没有菜谱'), findsOneWidget);
        expect(find.text('全部菜谱'), findsOneWidget);
        await tester.tap(find.text('查看全部菜谱'));
        await tester.pumpAndSettle();
        expect(find.text('香煎测试豆腐'), findsAtLeastNWidgets(1));
        await tester.tap(find.text('临期优先'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('全部菜谱'));
        await tester.pumpAndSettle();
        expect(find.text('当前筛选下没有菜谱'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('renders recipes returned by the recipe API', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RecipeSessionStore()),
          familyDataSourceProvider.overrideWithValue(
            _FridgeFixtureFamilySource(),
          ),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeFixtureSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(_RecipeFridgeSource()),
          recipeDataSourceProvider.overrideWithValue(_RecipeSource()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: RecipesPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('香煎测试豆腐'), findsAtLeastNWidgets(1));
    expect(find.textContaining('100% 匹配'), findsAtLeastNWidgets(1));
    expect(find.text('番茄滑蛋'), findsNothing);
  });
}

class _NoExpiringRecipes extends RecipeBrowserController {
  @override
  Future<List<RecipeMatch>> build() async =>
      RecipeMatcher.rank(await _RecipeSource().load(AuthSession.demo()), []);
}

class _RecipeSessionStore implements SessionStore {
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

class _RecipeSource implements RecipeDataSource {
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

class _RecipeFridgeSource implements FridgeDataSource {
  @override
  Future<void> createFridge(
    AuthSession session,
    int familyId,
    String name,
  ) async {}

  @override
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async {
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
          serverId: 1,
          name: '冷藏',
          description: '冷藏',
          temperature: '4°C',
          emoji: '🥬',
        ),
      ],
      foods: [
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
  @override
  Future<List<FoodOperation>> loadOperations(
    AuthSession session,
    int fridgeId, {
    int limit = 30,
  }) async => const <FoodOperation>[];

  @override
  Future<void> undoOperation(AuthSession session, FoodOperation operation) async {}

  @override
  Future<void> restoreOperation(
    AuthSession session,
    FoodOperation operation,
  ) async {}

  @override
  Future<void> cook(
    AuthSession session, {
    required int fridgeId,
    required int recipeId,
    required String recipeName,
    required int servings,
    required List<CookItemInput> items,
    required String requestId,
  }) async {}
}

class _FridgeFixtureFamilySource implements FamilyDataSource {
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => const [
    FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
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

class _FridgeFixtureSelectionStore implements FamilySelectionStore {
  @override
  Future<int?> read(int userId) async => 4;

  @override
  Future<void> write(int userId, int familyId) async {}

  @override
  Future<void> clear(int userId) async {}
}

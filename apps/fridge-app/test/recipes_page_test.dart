import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';
import 'package:smart_fridge_app/features/recipe/presentation/recipes_page.dart';

void main() {
  testWidgets('renders recipes returned by the recipe API', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RecipeSessionStore()),
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
        ingredients: [
          RecipeIngredient(name: '嫩豆腐', quantity: 1, unit: '盒'),
        ],
      ),
    ];
  }
}

class _RecipeFridgeSource implements FridgeDataSource {
  @override
  Future<FridgeWorkspaceData> load(AuthSession session) async {
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
}

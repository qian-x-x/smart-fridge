import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

void main() {
  test('ranks recipes by inventory coverage and reports missing ingredients', () {
    const recipe = Recipe(
      id: 1,
      name: '番茄滑蛋',
      summary: '家常菜',
      category: '家常菜',
      durationMinutes: 15,
      calories: 260,
      difficulty: '简单',
      servings: 2,
      coverEmoji: '🍅',
      steps: ['切番茄', '炒鸡蛋'],
      featured: true,
      ingredients: [
        RecipeIngredient(name: '西红柿', quantity: 2, unit: '个'),
        RecipeIngredient(name: '鸡蛋', quantity: 3, unit: '枚'),
        RecipeIngredient(name: '食用油', quantity: 10, unit: '毫升'),
        RecipeIngredient(name: '盐', quantity: 2, unit: '克'),
      ],
    );
    const foods = [
      FridgeFood(
        id: '1',
        name: '西红柿',
        emoji: '🍅',
        quantity: 2,
        unit: '个',
        expiresInDays: 2,
        zone: FridgeZoneId.fresh,
        category: '蔬菜',
        owner: '小满',
        tilt: 0,
      ),
      FridgeFood(
        id: '2',
        name: '鸡蛋',
        emoji: '🥚',
        quantity: 12,
        unit: '枚',
        expiresInDays: 10,
        zone: FridgeZoneId.fresh,
        category: '蛋奶',
        owner: '小满',
        tilt: 0,
      ),
      FridgeFood(
        id: '3',
        name: '食用油',
        emoji: '🫗',
        quantity: 2,
        unit: '升',
        expiresInDays: 200,
        zone: FridgeZoneId.pantry,
        category: '调料',
        owner: '小满',
        tilt: 0,
      ),
    ];

    final match = RecipeMatcher.rank([recipe], foods).single;

    expect(match.score, 75);
    expect(match.matchedCount, 3);
    expect(match.requiredCount, 4);
    expect(match.missingIngredients.single.name, '盐');
    expect(match.expiringMatches, 1);
  });
}

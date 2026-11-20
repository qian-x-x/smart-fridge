import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/domain/ingredient_stickers.dart';
import 'package:smart_fridge_app/features/recipe/data/home_recipe_catalog.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

void main() {
  test(
    'each home recipe can be made using whole portions from the catalog',
    () {
      final stock = [
        for (final item in ingredientStickers)
          _stock(item.name, unit: '份', quantity: 1, category: item.category),
      ];
      final matches = RecipeMatcher.rank(homeRecipes, stock);
      expect(
        matches
            .where((match) => !match.complete)
            .map((match) => match.recipe.name),
        isEmpty,
      );
      expect(
        matches
            .expand((match) => match.deductions)
            .every((row) => row.quantity == 1),
        isTrue,
      );
      for (final match in matches) {
        expect(match.deductions.length, match.requiredCount);
      }
    },
  );

  test(
    'exact ingredient names prevent similar items from satisfying a recipe',
    () {
      final recipe = homeRecipes.firstWhere((recipe) => recipe.name == '家常红烧肉');
      final stock = [
        for (final name in ['五花肉', '生姜', '料酒', '生抽', '白糖', '食用油', '冰块'])
          _stock(name, unit: '份', quantity: 1),
      ];
      final match = RecipeMatcher.match(recipe, stock);
      expect(match.missingIngredients.map((item) => item.name), ['老抽', '冰糖']);
      expect(RecipeMatcher.involves(recipe, stock.last), isFalse);
      expect(
        RecipeMatcher.involves(recipe, _stock('八角', unit: '份', quantity: 1)),
        isTrue,
      );
    },
  );

  test(
    'uses the clicked batch first and can aggregate compatible older units',
    () {
      final recipe = homeRecipes.firstWhere((recipe) => recipe.name == '清蒸南瓜');
      final quantity = recipe.ingredients.single.quantity!;
      final oldBatches = [
        _stock('南瓜', id: 'fresh', unit: '千克', quantity: quantity / 2000),
        _stock('南瓜', id: 'old', unit: '克', quantity: quantity / 2),
      ];
      final legacyPlan = RecipeMatcher.match(recipe, oldBatches);
      expect(legacyPlan.complete, isTrue);
      expect(legacyPlan.deductions.length, 2);
      final preferred = _stock('南瓜', id: 'clicked', unit: '份', quantity: 2);
      final plan = RecipeMatcher.match(recipe, [
        ...oldBatches,
        preferred,
      ], preferredFoodId: preferred.id);
      expect(plan.deductions.single.food.id, 'clicked');
      expect(plan.deductions.single.quantity, 1);
      expect(
        RecipeMatcher.match(recipe, [
          _stock('南瓜', unit: '份', quantity: .5),
        ]).complete,
        isFalse,
      );
    },
  );

  test(
    'expired and depleted stock cannot satisfy a recipe or expiry filter',
    () {
      const recipe = Recipe(
        id: 5,
        name: '牛奶饮品',
        summary: '',
        category: '饮品',
        durationMinutes: 5,
        calories: 50,
        difficulty: '简单',
        servings: 1,
        coverEmoji: '🥛',
        steps: [],
        featured: false,
        ingredients: [RecipeIngredient(name: '牛奶')],
      );
      FridgeFood milk(double quantity, int days) => FridgeFood(
        id: '$quantity/$days',
        name: '牛奶',
        emoji: '🥛',
        quantity: quantity,
        unit: '盒',
        expiresInDays: days,
        zone: FridgeZoneId.fresh,
        category: '蛋奶',
        owner: '小满',
        tilt: 0,
      );
      final invalid = RecipeMatcher.match(recipe, [milk(1, -1), milk(0, 2)]);
      expect(invalid.matchedCount, 0);
      expect(invalid.expiringMatches, 0);
      final valid = RecipeMatcher.match(recipe, [milk(1, -1), milk(1, 2)]);
      expect(valid.matchedCount, 1);
      expect(valid.matchedFoods.single.expiresInDays, 2);
    },
  );
  test(
    'ranks recipes by inventory coverage and reports missing ingredients',
    () {
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
          zone: FridgeZoneId.fresh,
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
    },
  );
}

FridgeFood _stock(
  String name, {
  String? id,
  required String unit,
  required double quantity,
  String category = '其他',
}) => FridgeFood(
  id: id ?? name,
  name: name,
  emoji: '',
  quantity: quantity,
  unit: unit,
  expiresInDays: 3,
  zone: FridgeZoneId.fresh,
  category: category,
  owner: '',
  tilt: 0,
);

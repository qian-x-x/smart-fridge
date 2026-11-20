import 'dart:math' as math;

import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantity,
    this.unit,
    this.optional = false,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final bool optional;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.summary,
    required this.category,
    required this.durationMinutes,
    required this.calories,
    required this.difficulty,
    required this.servings,
    required this.coverEmoji,
    required this.steps,
    required this.ingredients,
    required this.featured,
  });

  final int id;
  final String name;
  final String summary;
  final String category;
  final int durationMinutes;
  final int calories;
  final String difficulty;
  final int servings;
  final String coverEmoji;
  final List<String> steps;
  final List<RecipeIngredient> ingredients;
  final bool featured;
}

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.matchedCount,
    required this.requiredCount,
    required this.missingIngredients,
    required this.matchedFoods,
    required this.expiringMatches,
    this.deductions = const [],
  });

  final Recipe recipe;
  final int matchedCount;
  final int requiredCount;
  final List<RecipeIngredient> missingIngredients;
  final List<FridgeFood> matchedFoods;
  final int expiringMatches;
  final List<RecipeDeduction> deductions;

  int get score =>
      requiredCount == 0 ? 100 : ((matchedCount / requiredCount) * 100).round();

  bool get complete => missingIngredients.isEmpty;
}

class RecipeDeduction {
  const RecipeDeduction(this.food, this.quantity);

  final FridgeFood food;
  final double quantity;
}

abstract final class RecipeMatcher {
  static List<RecipeMatch> rank(
    List<Recipe> recipes,
    List<FridgeFood> foods, {
    String? preferredFoodId,
  }) {
    final matches = recipes
        .map((recipe) => match(recipe, foods, preferredFoodId: preferredFoodId))
        .toList();
    matches.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final expiring = right.expiringMatches.compareTo(left.expiringMatches);
      if (expiring != 0) return expiring;
      if (right.recipe.featured != left.recipe.featured) {
        return right.recipe.featured ? 1 : -1;
      }
      return left.recipe.durationMinutes.compareTo(
        right.recipe.durationMinutes,
      );
    });
    return matches;
  }

  static bool involves(Recipe recipe, FridgeFood food) {
    final name = _ingredientKey(food.name);
    return recipe.ingredients.any((item) => _ingredientKey(item.name) == name);
  }

  static RecipeMatch match(
    Recipe recipe,
    List<FridgeFood> foods, {
    String? preferredFoodId,
  }) {
    final required = recipe.ingredients
        .where((ingredient) => !ingredient.optional)
        .toList();
    final deductions = <String, RecipeDeduction>{};
    final missing = <RecipeIngredient>[];
    for (final ingredient in required) {
      final name = _ingredientKey(ingredient.name);
      final candidates =
          foods
              .where(
                (food) =>
                    name.isNotEmpty &&
                    _ingredientKey(food.name) == name &&
                    food.quantity > 0 &&
                    food.expiresInDays >= 0 &&
                    !deductions.containsKey(food.id),
              )
              .toList()
            ..sort((a, b) {
              final aPreferred = a.id == preferredFoodId;
              if (aPreferred != (b.id == preferredFoodId)) {
                return aPreferred ? -1 : 1;
              }
              final expiry = a.expiresInDays.compareTo(b.expiresInDays);
              return expiry != 0 ? expiry : a.id.compareTo(b.id);
            });
      final plan = _allocate(ingredient, candidates);
      if (plan.isEmpty) {
        missing.add(ingredient);
      }
      for (final item in plan) {
        deductions[item.food.id] = item;
      }
    }
    final matchedFoods = [for (final item in deductions.values) item.food];
    return RecipeMatch(
      recipe: recipe,
      matchedCount: required.length - missing.length,
      requiredCount: required.length,
      missingIngredients: List.unmodifiable(missing),
      matchedFoods: List.unmodifiable(matchedFoods),
      expiringMatches: matchedFoods.where((food) => food.isExpiring).length,
      deductions: List.unmodifiable(deductions.values),
    );
  }

  static List<RecipeDeduction> _allocate(
    RecipeIngredient ingredient,
    List<FridgeFood> candidates,
  ) {
    var remaining = ingredient.quantity ?? 1.0;
    final plan = <RecipeDeduction>[];
    for (final food in candidates) {
      if (food.unit.trim() == '份') {
        if (food.quantity >= 1) return [RecipeDeduction(food, 1)];
        continue;
      }
      final factor = _unitFactor(food.unit, ingredient.unit);
      if (factor == null) continue;
      // Amounts are sent in the stock row's unit, whose precision is 0.001.
      final available = math.min(food.quantity, remaining / factor);
      final quantity = ((available * 1000 + 1e-8).floor()) / 1000;
      if (quantity <= 0) continue;
      plan.add(RecipeDeduction(food, quantity));
      remaining -= quantity * factor;
      if (remaining <= 1e-8) return plan;
    }
    return const [];
  }

  static double? _unitFactor(String unit, String? requested) {
    final from = _normalize(unit);
    final to = _normalize(requested ?? '');
    if (to.isEmpty || from == to) return 1;
    for (final units in [
      const {
        '克': 1.0,
        'g': 1.0,
        '千克': 1000.0,
        '公斤': 1000.0,
        'kg': 1000.0,
        '斤': 500.0,
        '毫克': .001,
        'mg': .001,
      },
      const {'毫升': 1.0, 'ml': 1.0, '升': 1000.0, 'l': 1000.0, '公升': 1000.0},
      const {'枚': 1.0, '个': 1.0, '只': 1.0},
    ]) {
      if (units.containsKey(from) && units.containsKey(to)) {
        return units[from]! / units[to]!;
      }
    }
    return null;
  }

  static String _ingredientKey(String value) {
    final name = _normalize(value);
    const aliases = {
      '番茄': '西红柿',
      '盐': '食盐',
      '鲜牛奶': '牛奶',
      '面粉': '中筋面粉',
      '嫩豆腐': '豆腐',
      '猪里脊': '里脊肉',
      '猪肉馅': '猪肉末',
      '鸡翅中': '鸡翅',
      '鸡中翅': '鸡翅',
      '干木耳': '木耳',
      '鲜香菇': '香菇',
      '虾仁': '冷冻虾仁',
      '玉米粒': '速冻玉米粒',
      '香葱': '小葱',
      '黑胡椒粉': '黑胡椒',
    };
    return aliases[name] ?? name;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

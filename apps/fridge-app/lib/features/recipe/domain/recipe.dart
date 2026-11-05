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
  });

  final Recipe recipe;
  final int matchedCount;
  final int requiredCount;
  final List<RecipeIngredient> missingIngredients;
  final List<FridgeFood> matchedFoods;
  final int expiringMatches;

  int get score =>
      requiredCount == 0 ? 100 : ((matchedCount / requiredCount) * 100).round();

  bool get complete => missingIngredients.isEmpty;
}

abstract final class RecipeMatcher {
  static List<RecipeMatch> rank(List<Recipe> recipes, List<FridgeFood> foods) {
    final matches = recipes.map((recipe) => match(recipe, foods)).toList();
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

  static RecipeMatch match(Recipe recipe, List<FridgeFood> foods) {
    final required = recipe.ingredients
        .where((ingredient) => !ingredient.optional)
        .toList();
    final matchedFoods = <FridgeFood>[];
    final missing = <RecipeIngredient>[];
    for (final ingredient in required) {
      final food = foods
          .where(
            (candidate) =>
                candidate.quantity > 0 &&
                candidate.expiresInDays >= 0 &&
                (_matches(ingredient.name, candidate.name) ||
                    _matches(ingredient.name, candidate.category)),
          )
          .firstOrNull;
      if (food == null) {
        missing.add(ingredient);
      } else {
        matchedFoods.add(food);
      }
    }
    return RecipeMatch(
      recipe: recipe,
      matchedCount: matchedFoods.length,
      requiredCount: required.length,
      missingIngredients: List.unmodifiable(missing),
      matchedFoods: List.unmodifiable(matchedFoods),
      expiringMatches: matchedFoods.where((food) => food.isExpiring).length,
    );
  }

  static bool _matches(String ingredient, String inventoryValue) {
    final left = _normalize(ingredient);
    final right = _normalize(inventoryValue);
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    if (left.contains(right) || right.contains(left)) {
      return true;
    }
    const aliases = [
      {'番茄', '西红柿'},
      {'面粉', '中筋面粉'},
      {'虾仁', '冷冻虾仁'},
      {'玉米', '速冻玉米粒'},
    ];
    return aliases.any(
      (group) =>
          group.any((value) => left.contains(value)) &&
          group.any((value) => right.contains(value)),
    );
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}

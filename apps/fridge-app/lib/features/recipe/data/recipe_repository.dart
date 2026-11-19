import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';
import 'package:smart_fridge_app/features/recipe/data/home_recipe_catalog.dart';

final recipeDataSourceProvider = Provider<RecipeDataSource>((ref) {
  return ApiRecipeRepository(ref.watch(apiClientProvider));
});

abstract interface class RecipeDataSource {
  Future<List<Recipe>> load(AuthSession session);
}

class ApiRecipeRepository implements RecipeDataSource {
  ApiRecipeRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Recipe>> load(AuthSession session) async {
    if (session.isDemo) {
      return homeRecipes;
    }
    final body = await _api.get(
      '/api/v1/recipes',
      accessToken: session.accessToken,
    );
    final data = body['data'];
    if (data is! List) {
      throw const ApiFailure('菜谱列表格式不正确');
    }
    return data.map((value) => _recipe(_map(value))).toList(growable: false);
  }

  Recipe _recipe(Map<String, dynamic> json) {
    return Recipe(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      summary: json['summary'] as String,
      category: json['category'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      calories: (json['calories'] as num).toInt(),
      difficulty: json['difficulty'] as String,
      servings: (json['servings'] as num).toInt(),
      coverEmoji: json['coverEmoji'] as String,
      steps: _list(json['steps']).map((value) => value.toString()).toList(),
      ingredients: _list(json['ingredients'])
          .map((value) {
            final ingredient = _map(value);
            return RecipeIngredient(
              name: ingredient['name'] as String,
              quantity: (ingredient['quantity'] as num?)?.toDouble(),
              unit: ingredient['unit'] as String?,
              optional: ingredient['optional'] as bool? ?? false,
            );
          })
          .toList(growable: false),
      featured: json['featured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const ApiFailure('菜谱数据格式不正确');
  }

  List<dynamic> _list(Object? value) {
    if (value is List) {
      return value;
    }
    throw const ApiFailure('菜谱数据格式不正确');
  }
}

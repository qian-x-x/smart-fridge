import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

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
      return demoRecipes;
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

const demoRecipes = [
  Recipe(
    id: 1,
    name: '番茄滑蛋',
    summary: '酸甜番茄裹住嫩滑鸡蛋。',
    category: '家常菜',
    durationMinutes: 15,
    calories: 260,
    difficulty: '简单',
    servings: 2,
    coverEmoji: '🍅',
    steps: ['番茄切块，鸡蛋打散', '先炒鸡蛋，再与番茄翻匀'],
    featured: true,
    ingredients: [
      RecipeIngredient(name: '番茄', quantity: 2, unit: '个'),
      RecipeIngredient(name: '鸡蛋', quantity: 3, unit: '枚'),
      RecipeIngredient(name: '食用油', quantity: 10, unit: '毫升'),
    ],
  ),
  Recipe(
    id: 2,
    name: '蒜蓉生菜',
    summary: '大火快炒保留脆嫩口感。',
    category: '素菜',
    durationMinutes: 8,
    calories: 120,
    difficulty: '简单',
    servings: 2,
    coverEmoji: '🥬',
    steps: ['生菜洗净沥干', '炒香蒜末后大火快炒'],
    featured: false,
    ingredients: [
      RecipeIngredient(name: '生菜', quantity: 1, unit: '把'),
      RecipeIngredient(name: '大蒜', quantity: 3, unit: '瓣'),
      RecipeIngredient(name: '食用油', quantity: 10, unit: '毫升'),
    ],
  ),
  Recipe(
    id: 3,
    name: '青椒炒鸡胸',
    summary: '高蛋白低脂的快手小炒。',
    category: '快手菜',
    durationMinutes: 20,
    calories: 310,
    difficulty: '简单',
    servings: 2,
    coverEmoji: '🥩',
    steps: ['鸡胸切片腌制', '与青椒大火炒熟'],
    featured: true,
    ingredients: [
      RecipeIngredient(name: '青椒', quantity: 2, unit: '个'),
      RecipeIngredient(name: '鸡胸肉', quantity: 250, unit: '克'),
      RecipeIngredient(name: '生抽', quantity: 10, unit: '毫升'),
    ],
  ),
  Recipe(
    id: 4,
    name: '香煎三文鱼',
    summary: '外皮焦香、内部柔嫩。',
    category: '高蛋白',
    durationMinutes: 18,
    calories: 360,
    difficulty: '中等',
    servings: 2,
    coverEmoji: '🐟',
    steps: ['三文鱼擦干', '鱼皮朝下煎至金黄后翻面'],
    featured: false,
    ingredients: [
      RecipeIngredient(name: '三文鱼', quantity: 250, unit: '克'),
      RecipeIngredient(name: '黑胡椒', quantity: 2, unit: '克', optional: true),
      RecipeIngredient(name: '食用油', quantity: 8, unit: '毫升'),
    ],
  ),
  Recipe(
    id: 5,
    name: '虾仁玉米炒饭',
    summary: '冷冻食材也能快速完成。',
    category: '主食',
    durationMinutes: 25,
    calories: 480,
    difficulty: '中等',
    servings: 2,
    coverEmoji: '🍤',
    steps: ['虾仁解冻', '炒香配料后加入米饭'],
    featured: true,
    ingredients: [
      RecipeIngredient(name: '冷冻虾仁', quantity: 200, unit: '克'),
      RecipeIngredient(name: '速冻玉米粒', quantity: 150, unit: '克'),
      RecipeIngredient(name: '大米', quantity: 200, unit: '克'),
      RecipeIngredient(name: '鸡蛋', quantity: 2, unit: '枚'),
    ],
  ),
  Recipe(
    id: 6,
    name: '鲜蔬蛋饼',
    summary: '轻盈早餐。',
    category: '早餐',
    durationMinutes: 20,
    calories: 290,
    difficulty: '简单',
    servings: 2,
    coverEmoji: '🥚',
    steps: ['调面糊', '拌入黄瓜后煎熟'],
    featured: false,
    ingredients: [
      RecipeIngredient(name: '鸡蛋', quantity: 2, unit: '枚'),
      RecipeIngredient(name: '中筋面粉', quantity: 150, unit: '克'),
      RecipeIngredient(name: '黄瓜', quantity: 1, unit: '根'),
    ],
  ),
];

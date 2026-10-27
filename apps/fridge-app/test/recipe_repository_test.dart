import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';

void main() {
  test('loads recipe catalog through the gateway', () async {
    final api = _RecipeApiClient();
    final repository = ApiRecipeRepository(api);
    final session = AuthSession(
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

    final recipes = await repository.load(session);

    expect(api.path, '/api/v1/recipes');
    expect(api.accessToken, 'access');
    expect(recipes.single.name, '番茄滑蛋');
    expect(recipes.single.ingredients.single.name, '西红柿');
  });
}

class _RecipeApiClient extends ApiClient {
  _RecipeApiClient() : super(Dio());

  String? path;
  String? accessToken;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    this.path = path;
    this.accessToken = accessToken;
    return {
      'code': 'OK',
      'message': 'success',
      'data': [
        {
          'id': 1,
          'name': '番茄滑蛋',
          'summary': '家常菜',
          'category': '家常菜',
          'durationMinutes': 15,
          'calories': 260,
          'difficulty': '简单',
          'servings': 2,
          'coverEmoji': '🍅',
          'steps': ['切番茄', '炒鸡蛋'],
          'featured': true,
          'ingredients': [
            {
              'name': '西红柿',
              'quantity': 2,
              'unit': '个',
              'optional': false,
            },
          ],
        },
      ],
      'traceId': 'test',
    };
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';
import 'package:smart_fridge_app/features/recipe/presentation/recipe_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'demo has eighteen complete recipes with unique packaged photos',
    () async {
      final api = _RecipeApiClient();
      final recipes = await ApiRecipeRepository(api).load(AuthSession.demo());
      expect(api.path, isNull);
      expect(recipes, hasLength(18));
      expect(recipes.map((recipe) => recipe.id).toSet(), hasLength(18));
      final assets = <String>{};
      for (final recipe in recipes) {
        expect(
          recipe.steps.length,
          greaterThanOrEqualTo(4),
          reason: recipe.name,
        );
        expect(recipe.ingredients, isNotEmpty, reason: recipe.name);
        final image = RecipeArtwork.forName(recipe.name);
        expect(image, isNotNull, reason: recipe.name);
        assets.add(image!);
        final bytes = await rootBundle.load(image);
        expect(bytes.lengthInBytes, greaterThan(1000), reason: image);
        expect(
          recipe.ingredients.every(
            (i) =>
                (i.quantity ?? 0) > 0 && i.unit != null && i.unit!.isNotEmpty,
          ),
          isTrue,
        );
      }
      expect(assets, hasLength(18));
      expect(recipes.any((r) => r.name == '麻婆豆腐'), isTrue);
      expect(recipes.any((r) => r.name == '紫菜蛋花汤'), isTrue);
    },
  );

  test('unknown recipes never borrow another dish photo', () {
    expect(RecipeArtwork.forName('番茄鸡蛋面'), isNull);
    expect(RecipeArtwork.forName('香煎测试豆腐'), isNull);
  });

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
            {'name': '西红柿', 'quantity': 2, 'unit': '个', 'optional': false},
          ],
        },
      ],
      'traceId': 'test',
    };
  }
}

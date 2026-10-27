import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

final recipeBrowserProvider =
    AsyncNotifierProvider<RecipeBrowserController, List<RecipeMatch>>(
      RecipeBrowserController.new,
    );

class RecipeBrowserController extends AsyncNotifier<List<RecipeMatch>> {
  @override
  Future<List<RecipeMatch>> build() async {
    var session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    if (session.isAccessTokenExpiring) {
      session = await ref
          .read(authControllerProvider.notifier)
          .refreshAccessToken();
    }
    final workspace = await ref.watch(fridgeWorkspaceProvider.future);
    final recipes = await ref.read(recipeDataSourceProvider).load(session);
    return RecipeMatcher.rank(recipes, workspace.foods);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

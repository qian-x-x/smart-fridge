import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/domain/ingredient_stickers.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_sticker_image.dart';
import 'package:smart_fridge_app/features/recipe/application/recipe_controller.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';
import 'package:smart_fridge_app/features/recipe/presentation/recipe_artwork.dart';
import 'package:smart_fridge_app/shared/widgets/action_button.dart';

Future<void> showIngredientRecipes(
  BuildContext context, {
  required FridgeWorkspaceData workspace,
  required FridgeFood food,
  required void Function(FridgeWorkspaceData, FridgeFood) onInventoryDetails,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  enableDrag: false,
  backgroundColor: AppColors.paper,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (context) => _IngredientRecipesSheet(
    workspace: workspace,
    food: food,
    onInventoryDetails: onInventoryDetails,
  ),
);

typedef _CookAttempt = ({
  Recipe recipe,
  List<CookItemInput> items,
  String requestId,
});

class _IngredientRecipesSheet extends ConsumerStatefulWidget {
  const _IngredientRecipesSheet({
    required this.workspace,
    required this.food,
    required this.onInventoryDetails,
  });

  final FridgeWorkspaceData workspace;
  final FridgeFood food;
  final void Function(FridgeWorkspaceData, FridgeFood) onInventoryDetails;

  @override
  ConsumerState<_IngredientRecipesSheet> createState() =>
      _IngredientRecipesSheetState();
}

class _IngredientRecipesSheetState
    extends ConsumerState<_IngredientRecipesSheet> {
  _CookAttempt? _pending;
  String? _message;
  bool _saving = false;
  bool _failed = false;

  bool _sameFridge(FridgeWorkspaceData workspace) =>
      workspace.hasFridge &&
      workspace.familyId == widget.workspace.familyId &&
      workspace.fridgeId == widget.workspace.fridgeId &&
      workspace.isDemo == widget.workspace.isDemo;

  bool _canCook(FridgeWorkspaceData workspace, RecipeMatch match) =>
      _sameFridge(workspace) &&
      workspace.canEdit &&
      !workspace.isDemo &&
      match.complete &&
      match.deductions.isNotEmpty &&
      match.deductions.every((item) => item.food.serverId != null);

  Future<void> _start(Recipe recipe) async {
    final state = ref.read(fridgeWorkspaceProvider);
    final workspace = state.asData?.value;
    if (state.isLoading || workspace == null || _saving || _pending != null) {
      return;
    }
    final match = RecipeMatcher.match(
      recipe,
      workspace.foods,
      preferredFoodId: widget.food.id,
    );
    if (!_canCook(workspace, match)) return;
    final items = [
      for (final item in match.deductions)
        CookItemInput(
          foodItemId: item.food.serverId!,
          quantity: item.quantity,
          version: item.food.version,
        ),
    ]..sort((a, b) => a.foodItemId.compareTo(b.foodItemId));
    await _submit((
      recipe: recipe,
      items: items,
      requestId: newInventoryRequestId('cook'),
    ));
  }

  Future<void> _submit(_CookAttempt attempt) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _pending = attempt;
      _message = null;
    });
    final controller = ref.read(fridgeWorkspaceProvider.notifier);
    try {
      await controller.cook(
        familyId: widget.workspace.familyId,
        fridgeId: widget.workspace.fridgeId,
        recipeId: attempt.recipe.id,
        recipeName: attempt.recipe.name,
        servings: attempt.recipe.servings,
        requestId: attempt.requestId,
        items: attempt.items,
      );
      if (!mounted) return;
      setState(() {
        _pending = null;
        _saving = false;
        _failed = false;
        _message = '已制作「${attempt.recipe.name}」并扣减库存';
      });
    } on Object catch (error) {
      if (!mounted) return;
      final uncertain = error is ApiFailure && error.writeOutcomeUncertain;
      if (error is ApiFailure &&
          (error.statusCode == 409 || error.statusCode == 404)) {
        await controller.refresh();
        if (!mounted) return;
      }
      setState(() {
        if (!uncertain) _pending = null;
        _saving = false;
        _failed = true;
        _message = uncertain ? '暂时无法确认扣减结果，请重试本次制作。' : error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = ref.watch(fridgeWorkspaceProvider);
    final workspace = workspaceState.value;
    final same = workspace != null && _sameFridge(workspace);
    final current = same
        ? workspace.foods.where((item) => item.id == widget.food.id).firstOrNull
        : null;
    final food = current != null && current.version >= widget.food.version
        ? current
        : widget.food;
    final quantity = food.quantity % 1 == 0
        ? food.quantity.toInt().toString()
        : food.quantity.toString();
    final recipes = ref.watch(recipeBrowserProvider);
    final writable = same && workspace.canEdit && !workspace.isDemo;
    return PopScope(
      canPop: !_saving,
      child: FractionallySizedBox(
        heightFactor: .86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
              child: Row(
                children: [
                  IngredientStickerImage(
                    sticker: stickerForFood(food),
                    size: 58,
                    emoji: food.emoji,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (current != null)
                          Text(
                            '$quantity ${food.unit} · ${storageName(food.zone)}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        const Text(
                          '相关菜谱',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (current != null && workspace != null)
                    TextButton(
                      onPressed:
                          _saving ||
                              workspaceState.isLoading ||
                              workspaceState.hasError
                          ? null
                          : () => widget.onInventoryDetails(workspace, food),
                      child: const Text('库存详情'),
                    ),
                  IconButton(
                    tooltip: '关闭菜谱',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_message != null || _saving)
              Container(
                color: const Color(0xFFF0F4F6),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _saving ? '正在扣减库存…' : _message!,
                      style: TextStyle(
                        color: _failed && !_saving
                            ? AppColors.rose
                            : AppColors.ink,
                      ),
                    ),
                    if (_pending case final attempt? when !_saving)
                      TextButton(
                        onPressed: writable ? () => _submit(attempt) : null,
                        child: const Text('重试本次制作'),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: !same
                  ? Center(
                      child: Text(
                        workspaceState.isLoading ? '正在同步库存…' : '当前冰箱已切换或暂时不可用',
                      ),
                    )
                  : recipes.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => Center(
                        child: TextButton(
                          onPressed: () =>
                              ref.invalidate(recipeBrowserProvider),
                          child: const Text('菜谱加载失败，点击重试'),
                        ),
                      ),
                      data: (ranked) {
                        final matches = RecipeMatcher.rank(
                          [
                            for (final match in ranked)
                              if (RecipeMatcher.involves(match.recipe, food))
                                match.recipe,
                          ],
                          workspace.foods,
                          preferredFoodId: widget.food.id,
                        );
                        if (matches.isEmpty) {
                          return const Center(child: Text('现有菜谱暂未用到这项食材'));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: matches.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final match = matches[index];
                            final canCook =
                                _canCook(workspace, match) &&
                                !workspaceState.isLoading &&
                                !workspaceState.hasError &&
                                _pending == null;
                            return _IngredientRecipeCard(
                              match: match,
                              writable: writable,
                              onCook: canCook
                                  ? () => _start(match.recipe)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRecipeCard extends StatelessWidget {
  const _IngredientRecipeCard({
    required this.match,
    required this.writable,
    required this.onCook,
  });

  final RecipeMatch match;
  final bool writable;
  final VoidCallback? onCook;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final asset = RecipeArtwork.forName(recipe.name);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (asset != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      asset,
                      width: 72,
                      height: 58,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${recipe.durationMinutes} 分钟 · ${match.complete ? '食材齐备' : '缺少 ${match.missingIngredients.length} 种'}',
                        style: TextStyle(
                          color: match.complete
                              ? AppColors.muted
                              : AppColors.rose,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ingredient in recipe.ingredients)
                  _IngredientStatus(
                    ingredient: ingredient,
                    missing: match.missingIngredients.contains(ingredient),
                  ),
              ],
            ),
            if (recipe.steps.isNotEmpty)
              ExpansionTile(
                title: const Text('烹饪步骤', style: TextStyle(fontSize: 13)),
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final (index, step) in recipe.steps.indexed)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('${index + 1}. $step'),
                      ),
                    ),
                ],
              )
            else
              const SizedBox(height: 12),
            AppFilledButton.icon(
              key: ValueKey('cook-recipe-${recipe.id}'),
              onPressed: onCook,
              icon: const Icon(Icons.restaurant_outlined, size: 18),
              label: Text(
                !match.complete
                    ? '食材未齐'
                    : writable
                    ? '立即制作'
                    : '当前仅可查看菜谱',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientStatus extends StatelessWidget {
  const _IngredientStatus({required this.ingredient, required this.missing});

  final RecipeIngredient ingredient;
  final bool missing;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: missing ? const Color(0xFFFCEEEF) : const Color(0xFFF0F4F6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        '${ingredient.name} · ${ingredient.optional
            ? '可选'
            : missing
            ? '缺少'
            : '已备'}',
        style: TextStyle(
          color: missing ? AppColors.rose : AppColors.ink,
          fontSize: 12,
        ),
      ),
    ),
  );
}

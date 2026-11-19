import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/cook_confirm_sheet.dart';
import 'package:smart_fridge_app/features/recipe/application/recipe_controller.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';
import 'package:smart_fridge_app/features/recipe/presentation/recipe_artwork.dart';
import 'package:smart_fridge_app/shared/widgets/action_button.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});
  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  int _filter = 0;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(recipeBrowserProvider)
      .when(
        data: _buildRecipes,
        loading: () => const _RecipeLoading(),
        error: (error, stack) => _RecipeLoadError(
          message: error.toString(),
          onRetry: () => ref.read(recipeBrowserProvider.notifier).refresh(),
        ),
      );

  Widget _buildRecipes(List<RecipeMatch> matches) {
    final query = _search.text.trim().toLowerCase();
    final filtered = matches.where((match) {
      final matchesFilter = switch (_filter) {
        1 => match.expiringMatches > 0,
        2 => match.recipe.durationMinutes <= 20,
        _ => true,
      };
      return matchesFilter && match.recipe.name.toLowerCase().contains(query);
    }).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 950;
        final padding = desktop ? 32.0 : 18.0;
        final available = constraints.maxWidth - padding * 2;
        final columns = available >= 1120
            ? 3
            : available >= 660
            ? 2
            : 1;
        final cardWidth = (available - (columns - 1) * 20) / columns;
        final imageHeight = cardWidth * 0.62;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        return CustomScrollView(
          key: const PageStorageKey('recipe-page-scroll'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 26, padding, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'COOK WITH WHAT YOU HAVE',
                      style: TextStyle(
                        color: AppColors.muted,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '下一餐，就从冰箱开始。',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${matches.length} 道家常菜，按冰箱里的现有食材寻找下一餐。',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cool,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco_outlined,
                            size: 20,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              matches.any((m) => m.expiringMatches > 0)
                                  ? '有菜谱能用上临期食材，切换“临期优先”看看。'
                                  : '先看看已有原料，再补齐缺少的食材。',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 20,
                      runSpacing: 14,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in [
                              '全部菜谱',
                              '临期优先',
                              '20 分钟内',
                            ].indexed)
                              ChoiceChip(
                                label: Text(label.$2),
                                selected: _filter == label.$1,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  fontFamily: 'XiaoyiUI',
                                  color: _filter == label.$1
                                      ? Colors.white
                                      : AppColors.muted,
                                  fontSize: 13,
                                ),
                                onSelected: (_) =>
                                    setState(() => _filter = label.$1),
                              ),
                          ],
                        ),
                        SizedBox(
                          width: desktop ? 280 : available,
                          child: TextField(
                            key: const ValueKey('recipe-search-input'),
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: '搜索菜谱名称',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _search.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: '清除搜索',
                                      onPressed: () => setState(_search.clear),
                                      icon: const Icon(Icons.close, size: 18),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverToBoxAdapter(
                  child: _RecipeEmptyState(
                    onClear: _filter != 0 || query.isNotEmpty
                        ? () => setState(() {
                            _filter = 0;
                            _search.clear();
                          })
                        : null,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _RecipeCard(
                      match: filtered[index],
                      imageHeight: imageHeight,
                      onTap: () => _showDetails(filtered[index]),
                    ),
                    childCount: filtered.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: imageHeight + 244 * textScale,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showDetails(RecipeMatch match) {
    final workspace = _workspaceOrNull();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) => _RecipeDetailsSheet(
        match: match,
        canCook:
            workspace != null &&
            workspace.hasFridge &&
            workspace.canEdit &&
            !workspace.isDemo &&
            match.matchedFoods.isNotEmpty,
        onCook: () => _openCook(match, ModalRoute.of(sheetContext)),
      ),
    );
  }

  Future<void> _openCook(
    RecipeMatch match,
    Route<dynamic>? detailsRoute,
  ) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.hasFridge) {
      _notify('还没有可用的冰箱');
      return;
    }
    final cooked = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      builder: (context) => CookConfirmSheet(
        fridgeId: workspace.fridgeId,
        canEdit: workspace.canEdit && !workspace.isDemo,
        recipeId: match.recipe.id,
        recipeName: match.recipe.name,
        servings: match.recipe.servings,
        candidates: [
          for (final food in match.matchedFoods)
            if (food.serverId != null) food,
        ],
      ),
    );
    if (cooked != true || !mounted) {
      return;
    }
    // The sheets are pushed on the root navigator, while this page lives in a
    // go_router branch navigator, so the follow-up pop must target the root one.
    // Waiting one frame budget keeps the pop from hitting the closing cook sheet.
    final navigator = Navigator.of(context, rootNavigator: true);
    final message = '已记录「${match.recipe.name}」并扣减食材';
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) {
      return;
    }
    if (detailsRoute?.isCurrent == true) navigator.pop();
    _notify(message);
  }

  FridgeWorkspaceData? _workspaceOrNull() {
    final state = ref.read(fridgeWorkspaceProvider);
    return state is AsyncData<FridgeWorkspaceData> ? state.value : null;
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

String? _recipeImage(Recipe recipe) => RecipeArtwork.forName(recipe.name);

class _RecipeArtwork extends StatelessWidget {
  const _RecipeArtwork({required this.recipe, required this.height});
  final Recipe recipe;
  final double height;
  @override
  Widget build(BuildContext context) {
    final image = _recipeImage(recipe);
    final placeholder = Container(
      height: height,
      color: AppColors.cool,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_menu_outlined,
        color: AppColors.muted,
        size: 42,
      ),
    );
    if (image == null) return placeholder;
    return Image.asset(
      image,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      semanticLabel: '${recipe.name}成品参考图',
      cacheWidth: 900,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.match,
    required this.onTap,
    required this.imageHeight,
  });
  final RecipeMatch match;
  final VoidCallback onTap;
  final double imageHeight;
  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    return PressFeedback(
      child: Material(
        color: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RecipeArtwork(recipe: recipe, height: imageHeight),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${recipe.durationMinutes} 分钟 · ${recipe.category} · ${recipe.difficulty}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${match.score}% 匹配',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${match.matchedCount} / ${match.requiredCount} 食材已有',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.complete
                            ? '原料种类齐全'
                            : '缺少：${match.missingIngredients.map((i) => i.name).join('、')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: match.complete
                              ? AppColors.sage
                              : AppColors.muted,
                        ),
                      ),
                      if (match.expiringMatches > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '可用上 ${match.expiringMatches} 项临期食材',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '查看做法',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailsSheet extends StatelessWidget {
  const _RecipeDetailsSheet({
    required this.match,
    required this.canCook,
    required this.onCook,
  });

  final RecipeMatch match;
  final bool canCook;
  final VoidCallback onCook;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '菜谱详情',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: '关闭菜谱详情',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recipeImage(recipe) != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _RecipeArtwork(recipe: recipe, height: 210),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        '${recipe.durationMinutes} 分钟 · ${recipe.difficulty} · '
                        '${recipe.servings} 人份',
                        style: TextStyle(
                          color: AppColors.cocoa.withValues(alpha: 0.58),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${match.score}% 匹配',
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              recipe.summary,
              style: TextStyle(
                color: AppColors.cocoa.withValues(alpha: 0.72),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            Text('食材', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final ingredient in recipe.ingredients)
              _RecipeIngredientRow(
                ingredient: ingredient,
                available: !match.missingIngredients.contains(ingredient),
              ),
            const SizedBox(height: 18),
            const Text(
              '匹配按原料种类计算，用量请在做饭前确认。',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            AppFilledButton.icon(
              onPressed: canCook ? onCook : null,
              icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
              label: Text(canCook ? '用现有食材做这道菜' : '暂无可扣减的食材'),
            ),
            const SizedBox(height: 6),
            Text(
              '确认后会按清单扣减冰箱库存，并写入做饭记录。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 20),
            Text('做法', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (var index = 0; index < recipe.steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.cocoa,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recipe.steps[index],
                        style: const TextStyle(height: 1.6, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecipeIngredientRow extends StatelessWidget {
  const _RecipeIngredientRow({
    required this.ingredient,
    required this.available,
  });

  final RecipeIngredient ingredient;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final amount = [
      if (ingredient.quantity != null) _number(ingredient.quantity!),
      if (ingredient.unit != null) ingredient.unit,
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            ingredient.optional
                ? Icons.radio_button_unchecked
                : available
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline,
            color: ingredient.optional
                ? AppColors.muted
                : available
                ? AppColors.sage
                : AppColors.ink,
            semanticLabel: ingredient.optional
                ? '可选原料'
                : available
                ? '已备食材'
                : '缺少食材',
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              ingredient.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: AppColors.cocoa.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
          if (ingredient.optional)
            const Padding(
              padding: EdgeInsets.only(left: 7),
              child: Text(
                '可选',
                style: TextStyle(color: AppColors.sand, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }

  String _number(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}

class _RecipeLoading extends StatelessWidget {
  const _RecipeLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.cocoa),
          SizedBox(height: 16),
          Text('正在读取菜谱并匹配冰箱食材…'),
        ],
      ),
    );
  }
}

class _RecipeLoadError extends StatelessWidget {
  const _RecipeLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              color: AppColors.rose,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.cocoa),
            ),
            const SizedBox(height: 14),
            AppFilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeEmptyState extends StatelessWidget {
  const _RecipeEmptyState({this.onClear});
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            color: AppColors.sage,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text('当前筛选下没有菜谱'),
          if (onClear != null) ...[
            const SizedBox(height: 12),
            AppOutlinedButton(onPressed: onClear, child: const Text('查看全部菜谱')),
          ],
        ],
      ),
    );
  }
}

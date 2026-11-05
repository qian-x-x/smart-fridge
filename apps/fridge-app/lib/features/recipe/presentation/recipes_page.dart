import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/recipe/application/recipe_controller.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';
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
        return SingleChildScrollView(
          key: const PageStorageKey('recipe-page-scroll'),
          padding: EdgeInsets.fromLTRB(
            desktop ? 32 : 20,
            26,
            desktop ? 32 : 20,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'COOK WITH WHAT YOU HAVE',
                    style: TextStyle(
                      color: AppColors.muted,
                      letterSpacing: 2,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    desktop ? '好食材，值得好好做。' : '今天，吃点什么？',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '查查冰箱里的食材，让 ${matches.length} 道菜谱给下一餐一点灵感。',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.butter,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.eco_outlined,
                          size: 20,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            matches.any((m) => m.expiringMatches > 0)
                                ? '有菜谱能用上临期食材，切换“临期优先”看看。'
                                : '优先选择食材齐全的菜谱，少补一点，也能好好吃饭。',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
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
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  setState(() => _filter = label.$1),
                            ),
                        ],
                      ),
                      SizedBox(
                        width: desktop ? 280 : constraints.maxWidth - 40,
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
                  const SizedBox(height: 24),
                  if (filtered.isEmpty)
                    _RecipeEmptyState(
                      onClear: _filter != 0 || query.isNotEmpty
                          ? () => setState(() {
                              _filter = 0;
                              _search.clear();
                            })
                          : null,
                    )
                  else if (desktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _RecipeCard(
                            match: filtered.first,
                            hero: true,
                            onTap: () => _showDetails(filtered.first),
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              for (final match in filtered.skip(1))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _RecipeCard(
                                    match: match,
                                    onTap: () => _showDetails(match),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    for (final match in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _RecipeCard(
                          match: match,
                          onTap: () => _showDetails(match),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetails(RecipeMatch match) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    builder: (context) => _RecipeDetailsSheet(match: match),
  );
}

String? _recipeImage(Recipe recipe) {
  final name = recipe.name;
  if ((name.contains('番茄') || name.contains('西红柿')) && name.contains('蛋')) {
    return 'assets/images/recipe-tomato-eggs.jpg';
  }
  if (name.contains('西兰花')) return 'assets/images/recipe-broccoli.jpg';
  if (name.contains('南瓜') && name.contains('粥')) {
    return 'assets/images/recipe-pumpkin.jpg';
  }
  if (name.contains('蒸蛋') || name.contains('鸡蛋羹')) {
    return 'assets/images/recipe-steamed-eggs.jpg';
  }
  return null;
}

class _RecipeArtwork extends StatelessWidget {
  const _RecipeArtwork({required this.recipe, required this.height});
  final Recipe recipe;
  final double height;
  @override
  Widget build(BuildContext context) {
    final image = _recipeImage(recipe);
    return SizedBox(
      height: height,
      child: image != null
          ? Image.asset(
              image,
              fit: BoxFit.cover,
              width: double.infinity,
              semanticLabel: '${recipe.name}示意图',
            )
          : ColoredBox(
              color: AppColors.linen,
              child: Center(
                child: Text(
                  recipe.coverEmoji,
                  style: TextStyle(fontSize: height > 160 ? 94 : 46),
                ),
              ),
            ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.match,
    required this.onTap,
    this.hero = false,
  });
  final RecipeMatch match;
  final VoidCallback onTap;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final content = Padding(
      padding: EdgeInsets.all(hero ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  recipe.name,
                  style: TextStyle(
                    fontSize: hero ? 23 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.north_east, size: 18, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${recipe.durationMinutes} 分钟 · ${recipe.category}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (hero) ...[
            const SizedBox(height: 12),
            Text(
              recipe.summary,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.7,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: [
              Text(
                '${match.score}% 匹配',
                style: const TextStyle(
                  color: AppColors.terracotta,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                '${match.matchedCount} / ${match.requiredCount} 食材已有',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            match.complete
                ? '食材齐全'
                : '缺少：${match.missingIngredients.map((i) => i.name).join('、')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: match.complete ? AppColors.sage : AppColors.terracotta,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: match.score / 100,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: AppColors.linen,
            color: AppColors.terracotta,
            semanticsLabel: '食材匹配',
            semanticsValue: '${match.score}%',
          ),
          if (match.expiringMatches > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '优先消耗 ${match.expiringMatches} 项临期食材',
                style: const TextStyle(color: AppColors.warning, fontSize: 11),
              ),
            ),
        ],
      ),
    );
    return PressFeedback(
      child: Material(
        color: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: hero
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RecipeArtwork(recipe: recipe, height: 320),
                    content,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 104,
                      child: _RecipeArtwork(recipe: recipe, height: 186),
                    ),
                    Expanded(child: content),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RecipeDetailsSheet extends StatelessWidget {
  const _RecipeDetailsSheet({required this.match});

  final RecipeMatch match;

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
            if (_recipeImage(recipe) != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _RecipeArtwork(recipe: recipe, height: 210),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Text(recipe.coverEmoji, style: const TextStyle(fontSize: 54)),
                const SizedBox(width: 14),
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
                        '${recipe.calories} kcal',
                        style: TextStyle(
                          color: AppColors.cocoa.withValues(alpha: 0.58),
                          fontSize: 11,
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
            available ? Icons.check_circle_rounded : Icons.add_circle_outline,
            color: available ? AppColors.sage : AppColors.terracotta,
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

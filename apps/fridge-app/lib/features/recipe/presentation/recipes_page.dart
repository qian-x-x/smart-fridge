import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/recipe/application/recipe_controller.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipeBrowserProvider);
    return recipes.when(
      data: _buildRecipes,
      loading: () => const _RecipeLoading(),
      error: (error, stackTrace) => _RecipeLoadError(
        message: error.toString(),
        onRetry: () => ref.read(recipeBrowserProvider.notifier).refresh(),
      ),
    );
  }

  Widget _buildRecipes(List<RecipeMatch> matches) {
    final filtered = switch (_filter) {
      1 => matches.where((match) => match.expiringMatches > 0).toList(),
      2 => matches
          .where((match) => match.recipe.durationMinutes <= 20)
          .toList(),
      _ => matches,
    };
    final primary = filtered.firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1040;
        final compact = constraints.maxWidth < 620;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAF6EF), AppColors.cream],
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              desktop ? 34 : 20,
              desktop ? 24 : 22,
              desktop ? 34 : 20,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RecipeHeader(desktop: desktop, recipeCount: matches.length),
                    const SizedBox(height: 22),
                    if (primary == null)
                      const _RecipeEmptyState()
                    else if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _RecommendationHero(
                              match: primary,
                              onTap: () => _showDetails(primary),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _RecipeList(
                              matches: filtered.skip(1).toList(),
                              compact: compact,
                              selectedFilter: _filter,
                              onFilterSelected: (value) {
                                setState(() => _filter = value);
                              },
                              onRecipeTap: _showDetails,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _RecommendationHero(
                        match: primary,
                        onTap: () => _showDetails(primary),
                      ),
                      const SizedBox(height: 20),
                      _RecipeList(
                        matches: filtered.skip(1).toList(),
                        compact: compact,
                        selectedFilter: _filter,
                        onFilterSelected: (value) {
                          setState(() => _filter = value);
                        },
                        onRecipeTap: _showDetails,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetails(RecipeMatch match) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      builder: (context) => _RecipeDetailsSheet(match: match),
    );
  }
}

class _RecipeHeader extends StatelessWidget {
  const _RecipeHeader({required this.desktop, required this.recipeCount});

  final bool desktop;
  final int recipeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今晚吃什么',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: desktop ? 30 : 27,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '已从菜谱服务加载 $recipeCount 道菜，并按冰箱现有食材与临期状态排序。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.cocoa.withValues(alpha: 0.62)),
              ),
            ],
          ),
        ),
        if (desktop)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppColors.sage,
                ),
                SizedBox(width: 7),
                Text(
                  '按冰箱库存实时推荐',
                  style: TextStyle(
                    color: AppColors.cocoa,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({
    required this.matches,
    required this.compact,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onRecipeTap,
  });

  final List<RecipeMatch> matches;
  final bool compact;
  final int selectedFilter;
  final ValueChanged<int> onFilterSelected;
  final ValueChanged<RecipeMatch> onRecipeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          selected: selectedFilter,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: 22),
        Text('其他刚刚好的灵感', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (matches.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text('当前筛选下没有更多菜谱'),
          ),
        for (var index = 0; index < matches.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _RecipeTile(
            match: matches[index],
            color: _tileColors[index % _tileColors.length],
            onTap: () => onRecipeTap(matches[index]),
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded),
          label: const Text('按口味和耗时筛选'),
        ),
      ],
    );
  }

  static const _tileColors = [
    Color(0xFFE5EEE0),
    Color(0xFFF3E2D7),
    Color(0xFFF5ECD2),
  ];
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;
  static const _labels = ['全部食材', '临期优先', '20 分钟内'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _labels.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: _FilterChip(
                label: _labels[index],
                selected: selected == index,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecommendationHero extends StatelessWidget {
  const _RecommendationHero({required this.match, required this.onTap});

  final RecipeMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final coverage = '${match.matchedCount} / ${match.requiredCount}';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cocoa,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x245B4336),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.butter,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '今日首选 · ${match.score}% 匹配',
                  style: const TextStyle(
                    color: AppColors.cocoa,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.bookmark_border_rounded, color: AppColors.linen),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(recipe.coverEmoji, style: const TextStyle(fontSize: 66)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.cream),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${recipe.summary} · ${recipe.durationMinutes} 分钟 · '
                      '${recipe.category}',
                      style: TextStyle(
                        color: AppColors.cream.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(label: '已有', value: coverage),
              ),
              Expanded(
                child: _HeroMetric(
                  label: '热量',
                  value: '约 ${recipe.calories} kcal',
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('查看菜谱'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.cream.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.cocoa : AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.cocoa : AppColors.linen),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? AppColors.cream : AppColors.cocoa,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.match,
    required this.color,
    required this.onTap,
  });

  final RecipeMatch match;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final missingLabel = match.complete
        ? '食材齐全'
        : '缺少：${match.missingIngredients.map((item) => item.name).join('、')}';
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0x185B4336)),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  recipe.coverEmoji,
                  style: const TextStyle(fontSize: 38),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            recipe.name,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0E7),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${match.score}%',
                            style: const TextStyle(
                              color: AppColors.sage,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${recipe.durationMinutes} 分钟 · ${recipe.category}',
                      style: TextStyle(
                        color: AppColors.cocoa.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      missingLabel,
                      style: TextStyle(
                        color: match.complete
                            ? AppColors.sage
                            : AppColors.terracotta,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand),
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
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  recipe.coverEmoji,
                  style: const TextStyle(fontSize: 54),
                ),
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
                    color: AppColors.cocoa,
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
            const Icon(Icons.menu_book_rounded, color: AppColors.rose, size: 32),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.cocoa),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
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
  const _RecipeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: AppColors.sage, size: 34),
          SizedBox(height: 12),
          Text('当前筛选下没有菜谱'),
        ],
      ),
    );
  }
}

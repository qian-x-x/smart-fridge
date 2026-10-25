import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          sliver: SliverList.list(
            children: [
              Text(
                '今晚吃什么',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 7),
              Text(
                '根据冰箱现有食材与临期状态，为你排好了优先级。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.cocoa.withValues(alpha: 0.64)),
              ),
              const SizedBox(height: 20),
              const _RecommendationHero(),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: _FilterChip(label: '全部食材', selected: true)),
                  SizedBox(width: 8),
                  Expanded(child: _FilterChip(label: '临期优先')),
                  SizedBox(width: 8),
                  Expanded(child: _FilterChip(label: '20 分钟内')),
                ],
              ),
              const SizedBox(height: 22),
              Text('其他刚刚好的灵感', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const _RecipeTile(
                emoji: '🥬',
                title: '蒜蓉生菜',
                subtitle: '消耗生菜 · 8 分钟',
                match: '86%',
                missing: '食材齐全',
                color: Color(0xFFE5EEE0),
              ),
              const SizedBox(height: 10),
              const _RecipeTile(
                emoji: '🥩',
                title: '黑椒牛肉粒',
                subtitle: '优先用掉牛里脊 · 22 分钟',
                match: '79%',
                missing: '缺少：彩椒',
                color: Color(0xFFF3E2D7),
              ),
              const SizedBox(height: 10),
              const _RecipeTile(
                emoji: '🥟',
                title: '家常煎饺',
                subtitle: '从冷冻区直接开始 · 15 分钟',
                match: '74%',
                missing: '缺少：香醋',
                color: Color(0xFFF5ECD2),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.tune_rounded),
                label: const Text('按口味和耗时筛选'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationHero extends StatelessWidget {
  const _RecommendationHero();

  @override
  Widget build(BuildContext context) {
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
                child: const Text(
                  '今日首选 · 92% 匹配',
                  style: TextStyle(
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
              const Text('🍅', style: TextStyle(fontSize: 66)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '番茄滑蛋',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.cream),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '用掉 2 份临期食材 · 15 分钟 · 家常菜',
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
              const Expanded(
                child: _HeroMetric(label: '已有', value: '4 / 4'),
              ),
              const Expanded(
                child: _HeroMetric(label: '热量', value: '约 260 kcal'),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('开始做饭'),
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
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.match,
    required this.missing,
    required this.color,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String match;
  final String missing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
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
            child: Text(emoji, style: const TextStyle(fontSize: 38)),
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
                        title,
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
                        match,
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
                  subtitle,
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  missing,
                  style: TextStyle(
                    color: missing == '食材齐全'
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
    );
  }
}

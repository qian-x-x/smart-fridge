import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_scene.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_sheets.dart';

class FridgeHomePage extends ConsumerStatefulWidget {
  const FridgeHomePage({super.key});

  @override
  ConsumerState<FridgeHomePage> createState() => _FridgeHomePageState();
}

class _FridgeHomePageState extends ConsumerState<FridgeHomePage> {
  FridgeZoneId _selectedZone = FridgeZoneId.fresh;

  @override
  Widget build(BuildContext context) {
    final displayName =
        ref.watch(authControllerProvider).value?.user.displayName ?? '小满';
    final expiring = demoFoods.where((food) => food.isExpiring).toList();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9F3EA), AppColors.cream],
        ),
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            sliver: SliverList.list(
              children: [
                _HomeHeader(displayName: displayName),
                const SizedBox(height: 22),
                const _GreetingCard(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: '${demoFoods.length}',
                        label: '冰箱食材',
                        icon: Icons.eco_outlined,
                        accent: AppColors.sage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: '${expiring.length}',
                        label: '临期提醒',
                        icon: Icons.schedule_rounded,
                        accent: AppColors.rose,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: _StatCard(
                        value: '3',
                        label: '家人在线',
                        icon: Icons.people_alt_outlined,
                        accent: AppColors.terracotta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '我家的冰箱',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    _HeaderAction(
                      icon: Icons.table_rows_rounded,
                      label: '列表',
                      onPressed: () => showTablePreview(context),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '轻轻点开一层，看看今天适合先吃什么。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.cocoa.withValues(alpha: 0.64),
                  ),
                ),
                const SizedBox(height: 14),
                FridgeScene(
                  zones: demoZones,
                  foods: demoFoods,
                  selectedZone: _selectedZone,
                  onZoneSelected: (zone) {
                    setState(() => _selectedZone = zone);
                  },
                  onFoodTap: (food) => showFoodDetails(context, food),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '该先吃这些了',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => showTablePreview(context),
                      child: Text('全部 ${expiring.length} 项'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 142,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: expiring.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return _ExpiryCard(
                        food: expiring[index],
                        onTap: () => showFoodDetails(context, expiring[index]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 26),
                _RecipeSuggestion(onTap: () => context.go('/recipes')),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => showAddFoodPreview(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('放进一份新食材'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${now.month} 月 ${now.day} 日 · 星期${weekdays[now.weekday - 1]}',
                style: TextStyle(
                  color: AppColors.cocoa.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '早上好，$displayName',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 22),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.terracotta,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x25B85C45),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            displayName.isEmpty ? '住' : displayName.characters.first,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cocoa,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x265B4336),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    '家庭共享中',
                    style: TextStyle(
                      color: AppColors.linen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '今晚的番茄和牛奶，\n正好可以做一锅暖汤。',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.cream,
                    fontSize: 17,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '根据 10 份现有食材生成',
                  style: TextStyle(
                    color: AppColors.cream.withValues(alpha: 0.58),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _SoupIllustration(),
        ],
      ),
    );
  }
}

class _SoupIllustration extends StatelessWidget {
  const _SoupIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      height: 94,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFF826555),
              shape: BoxShape.circle,
            ),
          ),
          const Text('🍲', style: TextStyle(fontSize: 57)),
          Positioned(
            right: 2,
            top: 1,
            child: Container(
              width: 25,
              height: 25,
              decoration: const BoxDecoration(
                color: AppColors.butter,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.cocoa,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.cocoa.withValues(alpha: 0.58),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cocoa,
        backgroundColor: AppColors.paper.withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ExpiryCard extends StatelessWidget {
  const _ExpiryCard({required this.food, required this.onTap});

  final FridgeFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E5D9),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(food.emoji, style: const TextStyle(fontSize: 36)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '还剩 ${food.expiresInDays} 天',
                        style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '由 ${food.owner} 放入',
                        style: TextStyle(
                          color: AppColors.cocoa.withValues(alpha: 0.52),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeSuggestion extends StatelessWidget {
  const _RecipeSuggestion({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE7EEE2),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.paper.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('🍅', style: TextStyle(fontSize: 38)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '番茄滑蛋',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sage,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            '92% 匹配',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '食材齐全 · 15 分钟 · 优先用掉 2 份临期食材',
                      style: TextStyle(
                        color: AppColors.cocoa.withValues(alpha: 0.65),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.cocoa,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

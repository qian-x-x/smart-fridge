import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_scene.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_sheets.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_setup_panel.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_search_sheet.dart';

class FridgeHomePage extends ConsumerStatefulWidget {
  const FridgeHomePage({super.key});
  @override
  ConsumerState<FridgeHomePage> createState() => _FridgeHomePageState();
}

class _FridgeHomePageState extends ConsumerState<FridgeHomePage> {
  FridgeZoneId _selectedZone = FridgeZoneId.fresh;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(fridgeWorkspaceProvider);
    final families = ref.watch(familyControllerProvider);
    if (families.hasValue && families.requireValue.selectedFamily == null) {
      return const FridgeSetupPanel();
    }
    return workspace.when(
      data: (data) => data.hasFridge
          ? _home(context, data)
          : FridgeSetupPanel(
              key: ValueKey(data.familyId),
              family: families.value?.selectedFamily,
            ),
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在同步家庭冰箱…'),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 38,
                color: AppColors.muted,
              ),
              const SizedBox(height: 16),
              Text('冰箱暂时无法加载', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              AppFilledButton(
                onPressed: () =>
                    ref.read(fridgeWorkspaceProvider.notifier).refresh(),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _home(BuildContext context, FridgeWorkspaceData workspace) {
    final selected = workspace.zones.any((zone) => zone.id == _selectedZone)
        ? _selectedZone
        : workspace.zones.firstOrNull?.id ?? FridgeZoneId.fresh;
    final expiring = workspace.foods.where((food) => food.isExpiring).length;
    final expired = workspace.foods
        .where((food) => food.expiresInDays < 0)
        .length;
    final writable = workspace.canEdit && !workspace.isDemo;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final add = AppFilledButton.icon(
          onPressed: writable ? () => _openAddFood(context, workspace) : null,
          icon: const Icon(Icons.add, size: 19),
          label: const Text('放进一份新食材'),
        );
        final stock = _StockPanel(
          workspace: workspace,
          selected: selected,
          onFoodTap: (food) => _openFoodDetails(context, workspace, food),
          onOpenTable: () => _openTable(context, workspace),
        );
        final scene = FridgeScene(
          key: const ValueKey('family-fridge-scene'),
          zones: workspace.zones,
          selectedZone: selected,
          foods: workspace.foods,
          onZoneSelected: (zone) {
            if (mounted) setState(() => _selectedZone = zone);
          },
        );
        final priority = Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.terracotta,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.restaurant_menu, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expiring > 0 ? '$expiring 份食材，今天先安排。' : '好食材，值得好好做。',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (desktop) ...[
                      const SizedBox(height: 4),
                      Text(
                        expired > 0
                            ? '含 $expired 份已过期食材，请先检查库存。'
                            : '用冰箱里已有的食材，找到下一餐的灵感。',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.go('/recipes'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(desktop ? '看看菜谱 →' : '找菜谱'),
              ),
            ],
          ),
        );
        final content = SingleChildScrollView(
          key: PageStorageKey('fridge-home-${workspace.familyId}'),
          padding: EdgeInsets.fromLTRB(
            desktop ? 32 : 20,
            desktop ? 26 : 20,
            desktop ? 32 : 20,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EVERYDAY HARVEST',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2.4,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              workspace.fridgeName,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '${workspace.familyName} · ${_role(workspace.role)}${workspace.isDemo ? ' · 演示数据' : ''}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (desktop) ...[
                        AppOutlinedButton.icon(
                          onPressed: () => _openTable(context, workspace),
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('食材清单'),
                        ),
                        const SizedBox(width: 12),
                        add,
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        tooltip: '刷新冰箱',
                        onPressed: () => ref
                            .read(fridgeWorkspaceProvider.notifier)
                            .refresh(),
                        icon: const Icon(Icons.refresh, size: 22),
                      ),
                      if (!desktop)
                        IconButton(
                          tooltip: '冰箱清单',
                          onPressed: () => _openTable(context, workspace),
                          icon: const Icon(Icons.search, size: 22),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  priority,
                  const SizedBox(height: 22),
                  if (desktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: scene),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 310,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              stock,
                              const SizedBox(height: 16),
                              _InventoryStats(
                                count: workspace.foods.length,
                                expiring: expiring,
                                zones: workspace.zones.length,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: AppColors.linen,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.restaurant_menu,
                                      color: AppColors.terracotta,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '查完食材，下一餐也容易。',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      '按现有食材和临期情况，寻找刚刚好的菜谱。',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                        height: 1.7,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go('/recipes'),
                                      child: const Text('去看看菜谱 →'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    scene,
                    const SizedBox(height: 20),
                    _InventoryStats(
                      count: workspace.foods.length,
                      expiring: expiring,
                      zones: workspace.zones.length,
                    ),
                    const SizedBox(height: 18),
                    stock,
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '温度为储存参考，非传感器实测',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        );
        if (desktop) return content;
        return Column(
          children: [
            Expanded(child: content),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  add,
                  if (!writable) ...[
                    const SizedBox(height: 5),
                    Text(
                      workspace.isDemo ? '演示模式仅供浏览' : '只读权限 · 请联系家庭拥有者获取编辑权限',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAddFood(
    BuildContext context,
    FridgeWorkspaceData workspace,
  ) => showAddFoodPreview(
    context,
    zones: workspace.zones,
    canEdit: workspace.canEdit && !workspace.isDemo,
    onSave: (input) =>
        ref.read(fridgeWorkspaceProvider.notifier).addFood(input),
  );

  Future<void> _openFoodDetails(
    BuildContext context,
    FridgeWorkspaceData workspace,
    FridgeFood food,
  ) => showFoodDetails(
    context,
    food,
    zones: workspace.zones,
    canEdit: workspace.canEdit && !workspace.isDemo,
    onConsume: (quantity) =>
        ref.read(fridgeWorkspaceProvider.notifier).consume(food, quantity),
    onMove: (zone) =>
        ref.read(fridgeWorkspaceProvider.notifier).moveFood(food, zone),
    onDiscard: () => ref.read(fridgeWorkspaceProvider.notifier).discard(food),
  );

  Future<void> _openTable(BuildContext context, FridgeWorkspaceData workspace) {
    if (!workspace.isDemo) {
      return showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        constraints: const BoxConstraints(maxWidth: 960),
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FoodSearchSheet(
          workspace: workspace,
          onFoodTap: (food) => _openFoodDetails(context, workspace, food),
        ),
      );
    }
    return showTablePreview(
      context,
      workspace.foods,
      onFoodTap: (food) => _openFoodDetails(context, workspace, food),
    );
  }
}

String _role(String role) => switch (role) {
  'OWNER' => '拥有者',
  'EDITOR' => '编辑者',
  _ => '只读者',
};

class _InventoryStats extends StatelessWidget {
  const _InventoryStats({
    required this.count,
    required this.expiring,
    required this.zones,
  });
  final int count, expiring, zones;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.paper,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        for (final item in [
          ('$count', '份食材'),
          ('$expiring', '临期含过期'),
          ('$zones', '储存分区'),
        ])
          Expanded(
            child: Column(
              children: [
                Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    color: item.$2 == '临期含过期' ? AppColors.rose : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _StockPanel extends StatelessWidget {
  const _StockPanel({
    required this.workspace,
    required this.selected,
    required this.onFoodTap,
    required this.onOpenTable,
  });
  final FridgeWorkspaceData workspace;
  final FridgeZoneId selected;
  final ValueChanged<FridgeFood> onFoodTap;
  final VoidCallback onOpenTable;
  @override
  Widget build(BuildContext context) {
    final foods =
        workspace.foods.where((food) => food.zone == selected).toList()
          ..sort((a, b) => a.expiresInDays.compareTo(b.expiresInDays));
    final zone = workspace.zones
        .where((zone) => zone.id == selected)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '库存概览',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${foods.length} 项',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${zone?.name ?? '当前分区'} · 按到期时间排列',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (foods.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '这个分区还没有食材',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          for (final food in foods.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onFoodTap(food),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          food.expiresInDays < 0
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                          color: food.isExpiring
                              ? AppColors.rose
                              : AppColors.sage,
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${food.quantity % 1 == 0 ? food.quantity.toInt() : food.quantity} ${food.unit} · ${food.category}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          food.expiresInDays < 0
                              ? '已过期'
                              : food.expiresInDays == 0
                              ? '今天到期'
                              : '${food.expiresInDays} 天',
                          style: TextStyle(
                            fontSize: 11,
                            color: food.isExpiring
                                ? AppColors.rose
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          AppOutlinedButton.icon(
            onPressed: onOpenTable,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('全部食材与筛选'),
          ),
          if (workspace.role == 'VIEWER')
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                '只读权限 · 可查看与筛选',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_scene.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_sheets.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_setup_panel.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_search_sheet.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_timeline_sheet.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_picker_sheet.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_recipes_sheet.dart';

class FridgeHomePage extends ConsumerStatefulWidget {
  const FridgeHomePage({super.key});
  @override
  ConsumerState<FridgeHomePage> createState() => _FridgeHomePageState();
}

class _FridgeHomePageState extends ConsumerState<FridgeHomePage> {
  FridgeZoneId _selectedZone = FridgeZoneId.fresh;
  bool _ingredientRecipesOpen = false;

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
    final expiring = workspace.foods
        .where((food) => food.isExpiring && food.expiresInDays >= 0)
        .length;
    final expired = workspace.foods
        .where((food) => food.expiresInDays < 0)
        .length;
    final writable = workspace.canEdit && !workspace.isDemo;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final stats = _InventoryStats(
          count: workspace.foods.length,
          expiring: expiring,
          expired: expired,
        );
        final add = AppFilledButton.icon(
          onPressed: writable ? () => _openAddFood(context, workspace) : null,
          icon: const Icon(Icons.add, size: 19),
          label: const Text('添加食材'),
        );
        final stock = _StockPanel(
          workspace: workspace,
          selected: selected,
          onFoodTap: (food) => _openFoodDetails(context, workspace, food),
          onOpenTable: () => _openTable(context, workspace),
          onOpenTimeline: () => _openTimeline(context, workspace),
          onCleanExpired: () => _openExpiredCleanup(context, workspace),
        );
        final scene = FridgeScene(
          key: ValueKey((
            workspace.familyId,
            workspace.fridgeId,
            workspace.isDemo,
          )),
          zones: workspace.zones,
          selectedZone: selected,
          foods: workspace.foods,
          onFoodSelected: (food) =>
              _openIngredientRecipes(context, workspace, food),
          onZoneSelected: (zone) {
            if (mounted) setState(() => _selectedZone = zone);
          },
        );
        final content = SingleChildScrollView(
          key: PageStorageKey('fridge-home-${workspace.familyId}'),
          padding: EdgeInsets.fromLTRB(
            desktop ? 32 : 18,
            desktop ? 28 : 22,
            desktop ? 32 : 18,
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
                            Text(
                              workspace.fridgeName,
                              style: Theme.of(context).textTheme.headlineMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
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
                          icon: const Icon(
                            Icons.format_list_bulleted,
                            size: 18,
                          ),
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
                  if (desktop) ...[
                    const SizedBox(height: 22),
                    stats,
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: scene),
                        const SizedBox(width: 24),
                        SizedBox(width: 310, child: stock),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    scene,
                    const SizedBox(height: 18),
                    stats,
                    const SizedBox(height: 18),
                    stock,
                  ],
                ],
              ),
            ),
          ),
        );
        if (desktop) return content;
        // A dedicated footer reserves layout space; it cannot cover the 3D
        // controls or inventory rows, unlike a floating action button.
        return Column(
          children: [
            Expanded(child: content),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              decoration: const BoxDecoration(
                color: AppColors.paper,
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
                        fontSize: 12,
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
  ) => showIngredientPicker(
    context,
    zones: workspace.zones,
    onSave: (items, requestId) => ref
        .read(fridgeWorkspaceProvider.notifier)
        .addCatalogFoods(workspace, items, requestId),
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
    onEdit: () => showEditFood(
      context,
      zones: workspace.zones,
      canEdit: workspace.canEdit && !workspace.isDemo,
      food: food,
      onSave: (input) =>
          ref.read(fridgeWorkspaceProvider.notifier).updateFood(input),
    ),
  );

  Future<void> _openIngredientRecipes(
    BuildContext context,
    FridgeWorkspaceData workspace,
    FridgeFood food,
  ) async {
    if (_ingredientRecipesOpen) return;
    _ingredientRecipesOpen = true;
    try {
      final current = ref.read(fridgeWorkspaceProvider).asData?.value;
      // A searched record can be newer than the full inventory snapshot.
      if (!workspace.isDemo &&
          current != null &&
          current.familyId == workspace.familyId &&
          current.fridgeId == workspace.fridgeId &&
          !current.foods.any(
            (item) => item.id == food.id && item.version >= food.version,
          )) {
        unawaited(ref.read(fridgeWorkspaceProvider.notifier).refresh());
      }
      await showIngredientRecipes(
        context,
        workspace: workspace,
        food: food,
        onInventoryDetails: (current, item) =>
            _openFoodDetails(context, current, item),
      );
    } finally {
      _ingredientRecipesOpen = false;
    }
  }

  /// Bulk cleanup. Confirmation lives in a sheet so the user sees exactly what
  /// will leave the fridge before it happens.
  Future<void> _openExpiredCleanup(
    BuildContext context,
    FridgeWorkspaceData workspace,
  ) async {
    final expired =
        workspace.foods.where((food) => food.expiresInDays < 0).toList()
          ..sort((a, b) => a.expiresInDays.compareTo(b.expiresInDays));
    if (expired.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前没有已过期的食材'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!workspace.canEdit || workspace.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('只读成员不能清理库存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirmed = await showExpiredCleanupSheet(context, expired: expired);
    if (confirmed != true || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final removed = await ref
          .read(fridgeWorkspaceProvider.notifier)
          .discardExpired();
      messenger.showSnackBar(
        SnackBar(
          content: Text(removed > 0 ? '已清理 $removed 份过期食材' : '没有可清理的过期食材'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openTimeline(
    BuildContext context,
    FridgeWorkspaceData workspace,
  ) {
    if (workspace.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('演示模式没有真实的操作记录'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return Future.value();
    }
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      constraints: const BoxConstraints(maxWidth: 720),
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      builder: (context) => FoodTimelineSheet(workspace: workspace),
    );
  }

  Future<void> _openTable(BuildContext context, FridgeWorkspaceData workspace) {
    void openFood(FridgeFood food) =>
        _openIngredientRecipes(context, workspace, food);

    if (!workspace.isDemo) {
      return showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        constraints: const BoxConstraints(maxWidth: 960),
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) =>
            FoodSearchSheet(workspace: workspace, onFoodTap: openFood),
      );
    }
    return showTablePreview(context, workspace.foods, onFoodTap: openFood);
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
    required this.expired,
  });
  final int count, expiring, expired;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 17),
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.border),
        bottom: BorderSide(color: AppColors.border),
      ),
    ),
    child: Row(
      children: [
        for (final item in [
          (count, '项在库食材'),
          (expiring, '项即将到期'),
          (expired, '项已过期'),
        ])
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1.toString(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
    required this.onOpenTimeline,
    required this.onCleanExpired,
  });
  final FridgeWorkspaceData workspace;
  final FridgeZoneId selected;
  final ValueChanged<FridgeFood> onFoodTap;
  final VoidCallback onOpenTable;
  final VoidCallback onOpenTimeline;
  final VoidCallback onCleanExpired;
  @override
  Widget build(BuildContext context) {
    final foods =
        workspace.foods.where((food) => food.zone == selected).toList()
          ..sort((a, b) => a.expiresInDays.compareTo(b.expiresInDays));
    final zone = workspace.zones
        .where((zone) => zone.id == selected)
        .firstOrNull;
    final expiredCount = workspace.foods
        .where((food) => food.expiresInDays < 0)
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  zone == null ? '库存' : '${zone.name}库存',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${foods.length} 项',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onOpenTimeline,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        size: 14,
                        color: AppColors.terracotta,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '记录',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.terracotta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                          color: food.expiresInDays < 0
                              ? AppColors.rose
                              : food.isExpiring
                              ? AppColors.warning
                              : AppColors.muted,
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
                            color: food.expiresInDays < 0
                                ? AppColors.rose
                                : food.isExpiring
                                ? AppColors.warning
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
          if (expiredCount > 0) ...[
            AppOutlinedButton.icon(
              key: const ValueKey('clean-expired-button'),
              onPressed: workspace.canEdit && !workspace.isDemo
                  ? onCleanExpired
                  : null,
              icon: const Icon(Icons.cleaning_services_outlined, size: 16),
              label: Text('清理 $expiredCount 份过期食材'),
            ),
            const SizedBox(height: 8),
          ],
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

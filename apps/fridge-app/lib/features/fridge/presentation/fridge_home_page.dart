import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
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
    final workspace = ref.watch(fridgeWorkspaceProvider);
    final displayName =
        ref.watch(authControllerProvider).value?.user.displayName ?? '家人';

    return workspace.when(
      data: (data) => _buildHome(context, data, displayName),
      loading: () => _FridgeLoading(displayName: displayName),
      error: (error, stackTrace) => _FridgeLoadError(
        displayName: displayName,
        message: error.toString(),
        onRetry: () => ref.read(fridgeWorkspaceProvider.notifier).refresh(),
      ),
    );
  }

  Widget _buildHome(
    BuildContext context,
    FridgeWorkspaceData workspace,
    String displayName,
  ) {
    final expiring =
        workspace.foods.where((food) => food.isExpiring).toList();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAF6EF), AppColors.cream],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -160,
            right: -90,
            child: _AmbientOrb(size: 360, color: Color(0x35E2CBB5)),
          ),
          const Positioned(
            bottom: 80,
            left: -130,
            child: _AmbientOrb(size: 330, color: Color(0x2EDAE7DA)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1040;
              final compact = constraints.maxWidth < 620;
              final horizontalPadding = desktop ? 34.0 : 20.0;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  desktop ? 24 : 18,
                  horizontalPadding,
                  34,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HomeHeader(
                          displayName: displayName,
                          familyName: workspace.familyName,
                          role: workspace.role,
                          desktop: desktop,
                          onOpenTable: () =>
                              _openTable(context, workspace),
                        ),
                        SizedBox(height: desktop ? 24 : 18),
                        if (!desktop) ...[
                          _SummaryStrip(
                            foodCount: workspace.foods.length,
                            expiringCount: expiring.length,
                            role: workspace.role,
                            compact: compact,
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _FridgeWorkspace(
                                  title: workspace.fridgeName,
                                  zones: workspace.zones,
                                  selectedZone: _selectedZone,
                                  onZoneSelected: _selectZone,
                                  onOpenTable: () =>
                                      _openTable(context, workspace),
                                ),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 324,
                                child: _FridgeStatusPanel(
                                  selectedZone: _selectedZone,
                                  zones: workspace.zones,
                                  foods: workspace.foods,
                                  expiring: expiring,
                                  onZoneSelected: _selectZone,
                                  onFoodTap: (food) => _openFoodDetails(
                                    context,
                                    workspace,
                                    food,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _FridgeWorkspace(
                            title: workspace.fridgeName,
                            zones: workspace.zones,
                            selectedZone: _selectedZone,
                            onZoneSelected: _selectZone,
                            onOpenTable: () =>
                                _openTable(context, workspace),
                          ),
                          const SizedBox(height: 16),
                          _MobileStatusStrip(
                            selectedZone: _selectedZone,
                            zones: workspace.zones,
                            expiringCount: expiring.length,
                          ),
                        ],
                        SizedBox(height: desktop ? 30 : 26),
                        _ExpirySection(
                          expiring: expiring,
                          compact: compact,
                          onViewAll: () =>
                              _openTable(context, workspace),
                          onFoodTap: (food) =>
                              _openFoodDetails(context, workspace, food),
                        ),
                        SizedBox(height: desktop ? 24 : 20),
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _RecipeSuggestion(
                                  onTap: () => context.go('/recipes'),
                                ),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 324,
                                child: _AddFoodAction(
                                  onTap: () =>
                                      _openAddFood(context, workspace),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _RecipeSuggestion(
                            onTap: () => context.go('/recipes'),
                          ),
                          const SizedBox(height: 14),
                          _AddFoodAction(
                            onTap: () => _openAddFood(context, workspace),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _selectZone(FridgeZoneId zone) {
    if (_selectedZone == zone) {
      return;
    }
    setState(() => _selectedZone = zone);
  }

  Future<void> _openAddFood(
    BuildContext context,
    FridgeWorkspaceData workspace,
  ) {
    return showAddFoodPreview(
      context,
      zones: workspace.zones,
      canEdit: workspace.canEdit && !workspace.isDemo,
      onSave: (input) =>
          ref.read(fridgeWorkspaceProvider.notifier).addFood(input),
    );
  }

  Future<void> _openFoodDetails(
    BuildContext context,
    FridgeWorkspaceData workspace,
    FridgeFood food,
  ) {
    return showFoodDetails(
      context,
      food,
      zones: workspace.zones,
      canEdit: workspace.canEdit && !workspace.isDemo,
      onConsume: (quantity) =>
          ref.read(fridgeWorkspaceProvider.notifier).consume(food, quantity),
      onMove: (targetZone) =>
          ref.read(fridgeWorkspaceProvider.notifier).moveFood(food, targetZone),
      onDiscard: () =>
          ref.read(fridgeWorkspaceProvider.notifier).discard(food),
    );
  }

  Future<void> _openTable(
    BuildContext context,
    FridgeWorkspaceData workspace,
  ) {
    return showTablePreview(
      context,
      workspace.foods,
      onFoodTap: (food) => _openFoodDetails(context, workspace, food),
    );
  }
}

class _FridgeWorkspace extends StatelessWidget {
  const _FridgeWorkspace({
    required this.title,
    required this.zones,
    required this.selectedZone,
    required this.onZoneSelected,
    required this.onOpenTable,
  });

  final FridgeZoneId selectedZone;
  final String title;
  final List<FridgeZone> zones;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final VoidCallback onOpenTable;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    title,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 30, letterSpacing: -1),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '拖动旋转冰箱，点击门或抽屉查看分层食材。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.cocoa.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: onOpenTable,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cocoa,
                backgroundColor: AppColors.paper.withValues(alpha: 0.78),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.table_rows_rounded, size: 17),
              label: const Text('清单'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        FridgeScene(
          zones: zones,
          selectedZone: selectedZone,
          onZoneSelected: onZoneSelected,
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayName,
    required this.familyName,
    required this.role,
    required this.desktop,
    required this.onOpenTable,
  });

  final String displayName;
  final String familyName;
  final String role;
  final bool desktop;
  final VoidCallback onOpenTable;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final dateLabel =
        '${now.month} 月 ${now.day} 日 · 星期${weekdays[now.weekday - 1]}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  color: AppColors.cocoa.withValues(alpha: 0.52),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '早上好，$displayName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: desktop ? 28 : 23,
                  letterSpacing: -0.8,
                ),
              ),
              if (!desktop) ...[
                const SizedBox(height: 3),
                Text(
                  '$familyName · ${_roleLabel(role)}',
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (desktop) ...[
          _FamilyPresence(familyName: familyName, role: role),
          const SizedBox(width: 12),
          IconButton(
            tooltip: '冰箱清单',
            onPressed: onOpenTable,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.paper.withValues(alpha: 0.8),
              foregroundColor: AppColors.cocoa,
            ),
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
          ),
          const SizedBox(width: 10),
        ],
        Container(
          width: desktop ? 48 : 44,
          height: desktop ? 48 : 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.terracotta,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x25B85C45),
                blurRadius: 18,
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

  String _roleLabel(String value) {
    return switch (value) {
      'OWNER' => '拥有者',
      'EDITOR' => '编辑者',
      _ => '只读者',
    };
  }
}

class _FamilyPresence extends StatelessWidget {
  const _FamilyPresence({required this.familyName, required this.role});

  final String familyName;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.people_alt_outlined,
            size: 16,
            color: AppColors.sage,
          ),
          const SizedBox(width: 7),
          Text(
            '$familyName · ${_roleLabel(role)}',
            style: const TextStyle(
              color: AppColors.cocoa,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String value) {
    return switch (value) {
      'OWNER' => '拥有者',
      'EDITOR' => '编辑者',
      _ => '只读者',
    };
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.foodCount,
    required this.expiringCount,
    required this.role,
    required this.compact,
  });

  final int foodCount;
  final int expiringCount;
  final String role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 20,
        vertical: compact ? 13 : 15,
      ),
      decoration: BoxDecoration(
        color: AppColors.cocoa,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F5B4336),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryMetric(
            value: '$foodCount',
            label: '份食材',
            icon: Icons.eco_outlined,
          ),
          _SummaryDivider(),
          _SummaryMetric(
            value: '$expiringCount',
            label: '项临期',
            icon: Icons.schedule_rounded,
            alert: true,
          ),
          _SummaryDivider(),
          _SummaryMetric(
            value: switch (role) {
              'OWNER' => '拥有者',
              'EDITOR' => '编辑者',
              _ => '只读者',
            },
            label: '权限',
            icon: Icons.family_restroom_rounded,
          ),
          if (!compact) ...[
            const Spacer(),
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.butter,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                '今晚建议：番茄滑蛋',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.linen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.icon,
    this.alert = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 17,
            color: alert ? AppColors.peach : AppColors.butter,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 12),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' $label',
                    style: TextStyle(
                      color: AppColors.cream.withValues(alpha: 0.58),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.cream.withValues(alpha: 0.12),
    );
  }
}

class _FridgeStatusPanel extends StatelessWidget {
  const _FridgeStatusPanel({
    required this.selectedZone,
    required this.zones,
    required this.foods,
    required this.expiring,
    required this.onZoneSelected,
    required this.onFoodTap,
  });

  final FridgeZoneId selectedZone;
  final List<FridgeZone> zones;
  final List<FridgeFood> foods;
  final List<FridgeFood> expiring;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final ValueChanged<FridgeFood> onFoodTap;

  @override
  Widget build(BuildContext context) {
    final selected = zones.firstWhere((zone) => zone.id == selectedZone);
    final selectedFoods = foods.where((food) => food.zone == selectedZone).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x125B4336),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '冰箱状态',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EDE1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  '运行正常',
                  style: TextStyle(
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
            '${foods.length} 份食材 · ${expiring.length} 项临期',
            style: TextStyle(
              color: AppColors.cocoa.withValues(alpha: 0.52),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                selected.temperature,
                style: const TextStyle(
                  color: AppColors.cocoa,
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  selected.name,
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.58),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final zone in zones)
            _ZoneStatusRow(
              zone: zone,
              active: zone.id == selectedZone,
              onTap: () => onZoneSelected(zone.id),
            ),
          const SizedBox(height: 18),
          Container(height: 1, color: AppColors.cocoa.withValues(alpha: 0.09)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '临期优先',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${expiring.length} 项',
                style: const TextStyle(
                  color: AppColors.rose,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final food in expiring.take(3))
            InkWell(
              onTap: () => onFoodTap(food),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Text(food.emoji, style: const TextStyle(fontSize: 21)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        food.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${food.expiresInDays} 天',
                      style: const TextStyle(
                        color: AppColors.rose,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 7),
          Text(
            '${selected.description}，本层共 ${selectedFoods.length} 份。',
            style: TextStyle(
              color: AppColors.cocoa.withValues(alpha: 0.52),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneStatusRow extends StatelessWidget {
  const _ZoneStatusRow({
    required this.zone,
    required this.active,
    required this.onTap,
  });

  final FridgeZone zone;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? AppColors.sage : AppColors.sand,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                zone.name,
                style: TextStyle(
                  color: active ? AppColors.ink : AppColors.cocoa,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            Text(
              zone.temperature,
              style: TextStyle(
                color: active
                    ? AppColors.sage
                    : AppColors.cocoa.withValues(alpha: 0.42),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileStatusStrip extends StatelessWidget {
  const _MobileStatusStrip({
    required this.selectedZone,
    required this.zones,
    required this.expiringCount,
  });

  final FridgeZoneId selectedZone;
  final List<FridgeZone> zones;
  final int expiringCount;

  @override
  Widget build(BuildContext context) {
    final zone = zones.firstWhere((item) => item.id == selectedZone);
    return Row(
      children: [
        Expanded(
          child: _InlineStatus(
            icon: Icons.ac_unit_rounded,
            title: '${zone.name} ${zone.temperature}',
            subtitle: '点击模型可开门',
            color: AppColors.sage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InlineStatus(
            icon: Icons.schedule_rounded,
            title: '$expiringCount 项临期',
            subtitle: '优先安排到菜单',
            color: AppColors.rose,
          ),
        ),
      ],
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpirySection extends StatelessWidget {
  const _ExpirySection({
    required this.expiring,
    required this.compact,
    required this.onViewAll,
    required this.onFoodTap,
  });

  final List<FridgeFood> expiring;
  final bool compact;
  final VoidCallback onViewAll;
  final ValueChanged<FridgeFood> onFoodTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '该先吃这些了',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 20),
                  ),
                  if (!compact)
                    Text(
                      '按剩余天数排序，点开可记录使用或移动。',
                      style: TextStyle(
                        color: AppColors.cocoa.withValues(alpha: 0.52),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text('全部 ${expiring.length} 项'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: expiring.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final food = expiring[index];
              return _ExpiryTile(food: food, onTap: () => onFoodTap(food));
            },
          ),
        ),
      ],
    );
  }
}

class _ExpiryTile extends StatelessWidget {
  const _ExpiryTile({required this.food, required this.onTap});

  final FridgeFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 212,
      child: Material(
        color: AppColors.paper.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1E4D7),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(food.emoji, style: const TextStyle(fontSize: 34)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '还剩 ${food.expiresInDays} 天',
                        style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${food.owner} 放入',
                        style: TextStyle(
                          color: AppColors.cocoa.withValues(alpha: 0.5),
                          fontSize: 9,
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
      color: const Color(0xFFE2EBDD),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.paper.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Text('🍅', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            '番茄滑蛋',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
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
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '食材齐全 · 15 分钟 · 优先消耗 2 份临期食材',
                      style: TextStyle(
                        color: AppColors.cocoa.withValues(alpha: 0.64),
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

class _AddFoodAction extends StatelessWidget {
  const _AddFoodAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(74),
        backgroundColor: AppColors.cocoa,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      icon: const Icon(Icons.add_rounded),
      label: const Text('放进一份新食材'),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _FridgeLoading extends StatelessWidget {
  const _FridgeLoading({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.cocoa),
          const SizedBox(height: 18),
          Text(
            '正在打开 $displayName 的冰箱…',
            style: const TextStyle(
              color: AppColors.cocoa,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FridgeLoadError extends StatelessWidget {
  const _FridgeLoadError({
    required this.displayName,
    required this.message,
    required this.onRetry,
  });

  final String displayName;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.rose,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                '$displayName，冰箱数据暂时没有加载成功',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.cocoa.withValues(alpha: 0.62),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/webgl_fridge_view.dart';
import 'package:smart_fridge_app/shared/layout/scene_input_scope.dart';

class FridgeScene extends StatelessWidget {
  const FridgeScene({
    required this.zones,
    required this.selectedZone,
    required this.onZoneSelected,
    this.foods = const [],
    super.key,
  });
  final List<FridgeZone> zones;
  final FridgeZoneId selectedZone;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final List<FridgeFood> foods;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final selected = zones
          .where((zone) => zone.id == selectedZone)
          .firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              key: const ValueKey('fridge-zone-selector'),
              scrollDirection: Axis.horizontal,
              itemCount: zones.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final zone = zones[index];
                final active = zone.id == selectedZone;
                return Semantics(
                  selected: active,
                  button: true,
                  label: '${zone.name}区，${zone.temperature}',
                  child: Material(
                    color: active ? AppColors.terracotta : AppColors.paper,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onZoneSelected(zone.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: compact
                            ? ((constraints.maxWidth - 24) / 4)
                                  .clamp(76, 112)
                                  .toDouble()
                            : 112,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: active
                                ? AppColors.terracotta
                                : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              switch (zone.id) {
                                FridgeZoneId.fresh => Icons.kitchen_outlined,
                                FridgeZoneId.variable =>
                                  Icons.thermostat_outlined,
                                FridgeZoneId.freezer => Icons.ac_unit,
                                FridgeZoneId.pantry => Icons.shelves,
                              },
                              color: active ? Colors.white : AppColors.muted,
                              size: 18,
                            ),
                            SizedBox(width: compact ? 5 : 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    zone.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : AppColors.ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    zone.temperature,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white70
                                          : AppColors.muted,
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
              },
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: compact ? 290 : 500,
              child: WebGLFridgeView(
                zone: selectedZone,
                onZoneSelected: onZoneSelected,
                foods: foods,
                interactive:
                    (ModalRoute.isCurrentOf(context) ?? true) &&
                    SceneInputScope.isEnabled(context),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 5,
            children: [
              Text(
                selected == null
                    ? '暂无储存分区'
                    : '${selected.name} ${selected.temperature}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                selectedZone == FridgeZoneId.pantry
                    ? '常温储物位于厨房柜台'
                    : '拖动查看 · 点击门或抽屉开合',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      );
    },
  );
}

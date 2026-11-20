import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/webgl_fridge_view.dart';
import 'package:smart_fridge_app/shared/layout/scene_input_scope.dart';

class FridgeScene extends StatefulWidget {
  const FridgeScene({
    required this.zones,
    required this.selectedZone,
    required this.onZoneSelected,
    this.onFoodSelected,
    this.foods = const [],
    super.key,
  });
  final List<FridgeZone> zones;
  final FridgeZoneId selectedZone;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final ValueChanged<FridgeFood>? onFoodSelected;
  final List<FridgeFood> foods;

  @override
  State<FridgeScene> createState() => _FridgeSceneState();
}

class _FridgeSceneState extends State<FridgeScene> {
  ({FridgeZoneId zone, int request})? _focus;

  void _selectZone(FridgeZoneId zone) {
    setState(() => _focus = (zone: zone, request: (_focus?.request ?? 0) + 1));
    widget.onZoneSelected(zone);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final zones = widget.zones;
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
                final temperature = zone.temperature;
                final active = zone.id == widget.selectedZone;
                return Semantics(
                  selected: active,
                  button: true,
                  label: temperature.isEmpty
                      ? '${zone.name}区'
                      : '${zone.name}区，$temperature',
                  child: Material(
                    color: active ? AppColors.terracotta : AppColors.paper,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _selectZone(zone.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: compact
                            ? ((constraints.maxWidth - (zones.length - 1) * 8) /
                                      zones.length)
                                  .clamp(70, 120)
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              switch (zone.id) {
                                FridgeZoneId.fresh => Icons.kitchen_outlined,
                                FridgeZoneId.variable =>
                                  Icons.thermostat_outlined,
                                FridgeZoneId.freezer => Icons.ac_unit,
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
                                  if (temperature.isNotEmpty)
                                    Text(
                                      temperature,
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
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: compact ? 420 : 570,
              child: WebGLFridgeView(
                focus: _focus,
                onOverview: () => setState(() => _focus = null),
                onZoneSelected: widget.onZoneSelected,
                onFoodSelected: widget.onFoodSelected,
                foods: widget.foods,
                interactive:
                    (ModalRoute.isCurrentOf(context) ?? true) &&
                    SceneInputScope.isEnabled(context),
              ),
            ),
          ),
        ],
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/config/app_brand.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';

class WebGLFridgeView extends StatelessWidget {
  const WebGLFridgeView({
    required this.zone,
    required this.onZoneSelected,
    this.foods = const [],
    this.interactive = true,
    super.key,
  });
  final FridgeZoneId zone;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final List<FridgeFood> foods;
  final bool interactive;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '暖橙厨房外观参考图，非实时三维；食材以清单为准。',
    child: Stack(
      key: const ValueKey('webgl-fridge-fallback'),
      fit: StackFit.expand,
      children: [
        Image.asset(AppBrand.kitchenImage, fit: BoxFit.cover),
        Positioned(
          left: 12,
          right: 12,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '外观参考图 · 三维交互请在 Web 打开\n实际食材以冰箱清单为准',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.ink),
            ),
          ),
        ),
      ],
    ),
  );
}

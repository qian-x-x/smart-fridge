import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/config/app_brand.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/reference_sticker_layer.dart';

class WebGLFridgeView extends StatelessWidget {
  const WebGLFridgeView({
    required this.focus,
    required this.onOverview,
    required this.onZoneSelected,
    this.onFoodSelected,
    this.foods = const [],
    this.interactive = true,
    super.key,
  });
  final ({FridgeZoneId zone, int request})? focus;
  final VoidCallback onOverview;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final ValueChanged<FridgeFood>? onFoodSelected;
  final List<FridgeFood> foods;
  final bool interactive;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final zone = focus?.zone;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 400);
      final (zoom, center) = zone == FridgeZoneId.fresh
          ? (1.65, const Offset(0.50, 0.33))
          : (1.0, const Offset(0.50, 0.50));
      final imageSize = math.max(constraints.maxWidth, constraints.maxHeight);
      final maxX = (imageSize * zoom - constraints.maxWidth) / 2;
      final maxY = (imageSize * zoom - constraints.maxHeight) / 2;
      final translation = Offset(
        ((0.5 - center.dx) * imageSize * zoom).clamp(-maxX, maxX),
        ((0.5 - center.dy) * imageSize * zoom).clamp(-maxY, maxY),
      );
      final transform = Matrix4.diagonal3Values(zoom, zoom, 1)
        ..setTranslationRaw(translation.dx, translation.dy, 0);
      return Stack(
        key: const ValueKey('webgl-fridge-fallback'),
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            key: const ValueKey('fridge-reference-camera'),
            duration: duration,
            curve: Curves.easeInOutCubic,
            transform: transform,
            transformAlignment: Alignment.center,
            child: OverflowBox(
              minWidth: imageSize,
              maxWidth: imageSize,
              minHeight: imageSize,
              maxHeight: imageSize,
              child: Image.asset(
                zone == FridgeZoneId.fresh
                    ? AppBrand.kitchenInteriorImage
                    : AppBrand.kitchenImage,
                fit: BoxFit.cover,
                semanticLabel: '冰箱参考图',
                excludeFromSemantics:
                    zone == FridgeZoneId.variable ||
                    zone == FridgeZoneId.freezer,
              ),
            ),
          ),
          for (final (drawerZone, asset, label) in [
            (FridgeZoneId.variable, AppBrand.variableDrawerImage, '变温抽屉俯视'),
            (FridgeZoneId.freezer, AppBrand.freezerDrawerImage, '冷冻抽屉俯视'),
          ])
            AnimatedOpacity(
              key: ValueKey(drawerZone),
              opacity: zone == drawerZone ? 1 : 0,
              duration: duration,
              curve: Curves.easeInOutCubic,
              child: ColoredBox(
                color: const Color(0xFF738390),
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  semanticLabel: label,
                  excludeFromSemantics: zone != drawerZone,
                ),
              ),
            ),
          if (zone != null)
            ReferenceStickerLayer(
              key: ValueKey(('stickers', zone)),
              zone: zone,
              foods: foods
                  .where((food) => food.zone == zone && food.quantity > 0)
                  .toList(),
              photoSize: zone == FridgeZoneId.fresh
                  ? imageSize * zoom
                  : math.min(constraints.maxWidth, constraints.maxHeight),
              center:
                  Offset(constraints.maxWidth / 2, constraints.maxHeight / 2) +
                  translation,
              interactive: interactive,
              onFoodSelected: onFoodSelected,
            ),
          Positioned(
            right: 10,
            bottom: 10,
            child: IconButton.filledTonal(
              tooltip: '概览',
              onPressed: focus == null || !interactive ? null : onOverview,
              icon: const Icon(Icons.center_focus_strong),
              style: IconButton.styleFrom(backgroundColor: AppColors.paper),
            ),
          ),
        ],
      );
    },
  );
}

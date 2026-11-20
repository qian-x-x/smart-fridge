import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/ingredient_stickers.dart';

class IngredientStickerImage extends StatelessWidget {
  const IngredientStickerImage({
    required this.sticker,
    required this.size,
    this.emoji,
    super.key,
  });

  final IngredientSticker? sticker;
  final double size;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final asset = sticker?.asset;
    final fallback = Center(
      child: emoji != null
          ? Text(emoji!, style: TextStyle(fontSize: size * 0.53))
          : Icon(
              switch (sticker?.category) {
                '蔬菜' => Icons.eco_outlined,
                '调味品' => Icons.kitchen_outlined,
                _ => Icons.grain,
              },
              color: AppColors.terracotta,
              size: size * 0.52,
            ),
    );
    return SizedBox.square(
      dimension: size,
      child: ExcludeSemantics(
        child: asset == null
            ? fallback
            : Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

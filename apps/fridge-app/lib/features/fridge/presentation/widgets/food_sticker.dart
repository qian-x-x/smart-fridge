import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';

class FoodSticker extends StatelessWidget {
  const FoodSticker({required this.food, required this.onTap, super.key});

  final FridgeFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${food.name}，${_quantityLabel(food)}，'
          '${food.isExpiring ? '${food.expiresInDays} 天后到期' : '${food.expiresInDays} 天后到期'}',
      child: Transform.rotate(
        angle: food.tilt,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              width: 82,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: food.isExpiring
                        ? const Color(0x33B75B64)
                        : const Color(0x1F302822),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        food.emoji,
                        style: const TextStyle(fontSize: 34, height: 1.15),
                      ),
                      if (food.isExpiring)
                        Positioned(
                          right: -11,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.rose,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${food.expiresInDays}天',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _quantityLabel(food),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.cocoa.withValues(alpha: 0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _quantityLabel(FridgeFood value) {
    final quantity = value.quantity % 1 == 0
        ? value.quantity.toInt().toString()
        : value.quantity.toStringAsFixed(1);
    return '$quantity${value.unit}';
  }
}

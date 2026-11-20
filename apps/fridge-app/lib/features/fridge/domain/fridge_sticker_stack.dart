import 'dart:math' as math;

import 'fridge_data.dart';

class FridgeStickerStack {
  const FridgeStickerStack._(this.food, this.layers, this.portions);

  final FridgeFood food;
  final int layers;
  final double? portions;

  String? get portionCount {
    final count = portions;
    if (count == null || count <= 1) return null;
    return count.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String? get badge =>
      portions != null && portions! > 99 ? '99+' : portionCount;
}

List<FridgeStickerStack> groupFridgeStickers(Iterable<FridgeFood> foods) {
  final groups = <(FridgeZoneId, String), List<FridgeFood>>{};
  final spaces = RegExp(r'\s+');
  for (final food in foods) {
    if (!food.quantity.isFinite || food.quantity <= 0) continue;
    final name = food.name.trim().replaceAll(spaces, ' ').toLowerCase();
    if (name.isEmpty) continue;
    (groups[(food.zone, name)] ??= []).add(food);
  }
  return [for (final batches in groups.values) _stack(batches)];
}

FridgeStickerStack _stack(List<FridgeFood> batches) {
  final current = batches.where((food) => food.expiresInDays >= 0).firstOrNull;
  var lead = current ?? batches.first;
  double total = 0;
  var allPortions = true;
  for (final food in batches) {
    if (food.expiresInDays >= 0 && food.expiresInDays < lead.expiresInDays) {
      lead = food;
    }
    total += food.quantity;
    allPortions = allPortions && food.unit == '份';
  }
  final portions = allPortions && total.isFinite ? total : null;
  final layerCount = math.max(
    batches.length,
    (portions ?? 1.0).clamp(1, 3).ceil(),
  );
  return FridgeStickerStack._(lead, math.min(layerCount, 3), portions);
}

int fridgeStickerColumns(FridgeZoneId zone, int ingredientKinds) {
  if (zone == FridgeZoneId.fresh) return 6;
  return ingredientKinds > 16 ? 8 : 4;
}

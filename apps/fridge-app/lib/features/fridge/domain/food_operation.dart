/// A single entry of the fridge operation timeline.
class FoodOperation {
  const FoodOperation({
    required this.id,
    required this.foodItemId,
    required this.foodName,
    required this.action,
    required this.oldQuantity,
    required this.newQuantity,
    required this.note,
    required this.originalOperationId,
    required this.undone,
    required this.undoable,
    required this.createdAt,
  });

  final int id;
  final int foodItemId;
  final String foodName;
  final String action;
  final double? oldQuantity;
  final double? newQuantity;
  final String? note;
  final int? originalOperationId;
  final bool undone;
  final bool undoable;
  final DateTime? createdAt;

  bool get canUndo => undoable;

  /// Only an original operation that is currently undone can be re-applied.
  bool get canRestore => undone && originalOperationId == null;

  String get actionLabel => switch (action) {
    'ADD' => '新增',
    'UPDATE' => '编辑',
    'MOVE' => '移动',
    'CONSUME' => '使用',
    'COOK' => '做饭',
    'DISCARD' => '丢弃',
    'UNDO' => '撤销',
    'RESTORE' => '恢复',
    _ => action,
  };

  String get summary {
    if (note != null && note!.trim().isNotEmpty) {
      return note!.trim();
    }
    return switch (action) {
      'ADD' => '新增入库',
      'UPDATE' => '修改了食材信息',
      'MOVE' => '调整了存放区域',
      'CONSUME' || 'COOK' => _quantityChange('使用'),
      'DISCARD' => '从冰箱丢弃',
      _ => actionLabel,
    };
  }

  String _quantityChange(String verb) {
    final before = _formatQuantity(oldQuantity);
    final after = _formatQuantity(newQuantity);
    if (before == null || after == null) {
      return verb;
    }
    return '$verb $before → $after';
  }

  static String? _formatQuantity(double? value) {
    if (value == null) {
      return null;
    }
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  static FoodOperation fromApi(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String?;
    return FoodOperation(
      id: (json['id'] as num).toInt(),
      foodItemId: (json['foodItemId'] as num).toInt(),
      foodName: json['foodName'] as String? ?? '已删除的食材',
      action: json['action'] as String? ?? 'UPDATE',
      oldQuantity: (json['oldQuantity'] as num?)?.toDouble(),
      newQuantity: (json['newQuantity'] as num?)?.toDouble(),
      note: json['note'] as String?,
      originalOperationId: (json['originalOperationId'] as num?)?.toInt(),
      undone: json['undone'] as bool? ?? false,
      undoable: json['undoable'] as bool? ?? false,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt)?.toLocal(),
    );
  }
}

/// One line of the deduction list sent when confirming a cooking session.
class CookItemInput {
  const CookItemInput({
    required this.foodItemId,
    required this.quantity,
    required this.version,
  });

  final int foodItemId;
  final double quantity;
  final int version;
}

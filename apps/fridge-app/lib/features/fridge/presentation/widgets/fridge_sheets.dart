import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:flutter/material.dart';
import 'package:smart_fridge_app/shared/widgets/form_exit_guard.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_category_options.dart';

Future<void> showFoodDetails(
  BuildContext context,
  FridgeFood food, {
  required List<FridgeZone> zones,
  required bool canEdit,
  required Future<void> Function(double quantity) onConsume,
  required Future<void> Function(FridgeZone targetZone) onMove,
  required Future<void> Function() onDiscard,
  Future<bool?> Function()? onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    builder: (context) => _FoodDetailsSheet(
      food: food,
      zones: zones,
      canEdit: canEdit,
      onConsume: onConsume,
      onMove: onMove,
      onDiscard: onDiscard,
      onEdit: onEdit,
    ),
  );
}

Future<void> showTablePreview(
  BuildContext context,
  List<FridgeFood> foods, {
  required ValueChanged<FridgeFood> onFoodTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    builder: (context) =>
        _TablePreviewSheet(foods: foods, onFoodTap: onFoodTap),
  );
}

Future<void> showAddFoodPreview(
  BuildContext context, {
  required List<FridgeZone> zones,
  required bool canEdit,
  required Future<void> Function(NewFoodInput input) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    enableDrag: false,
    builder: (context) =>
        _FoodFormSheet(zones: zones, canEdit: canEdit, onSave: onSave),
  );
}

/// Opens the same form pre-filled with an existing item so a wrong category,
/// unit or date can be corrected instead of re-adding the food.
Future<bool?> showEditFood(
  BuildContext context, {
  required List<FridgeZone> zones,
  required bool canEdit,
  required FridgeFood food,
  required Future<void> Function(FoodEditInput input) onSave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    enableDrag: false,
    builder: (context) => _FoodFormSheet(
      zones: zones,
      canEdit: canEdit,
      editing: food,
      onUpdate: onSave,
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _FoodDetailsSheet extends StatefulWidget {
  const _FoodDetailsSheet({
    required this.food,
    required this.zones,
    required this.canEdit,
    required this.onConsume,
    required this.onMove,
    required this.onDiscard,
    this.onEdit,
  });

  final FridgeFood food;
  final List<FridgeZone> zones;
  final bool canEdit;
  final Future<void> Function(double quantity) onConsume;
  final Future<void> Function(FridgeZone targetZone) onMove;
  final Future<void> Function() onDiscard;
  final Future<bool?> Function()? onEdit;

  @override
  State<_FoodDetailsSheet> createState() => _FoodDetailsSheetState();
}

class _FoodDetailsSheetState extends State<_FoodDetailsSheet> {
  late FridgeZone? _targetZone;
  bool _busy = false;
  String? _error;
  late final TextEditingController _amount;

  FridgeFood get food => widget.food;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: food.quantity >= 1 ? '1' : food.quantity.toString(),
    );
    _targetZone = widget.zones
        .where((zone) => zone.id != food.zone)
        .firstOrNull;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _stepAmount(int direction) {
    if (food.quantity < .001) return;
    final current = double.tryParse(_amount.text) ?? 1;
    if (!current.isFinite) return;
    final next = (current + direction).clamp(0.001, food.quantity);
    setState(
      () => _amount.text = next
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'\.?0+$'), ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quantity = food.quantity % 1 == 0
        ? food.quantity.toInt().toString()
        : food.quantity.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(food.emoji, style: const TextStyle(fontSize: 43)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${food.category} · ${_zoneName(food.zone)}',
                      style: TextStyle(
                        color: AppColors.cocoa.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (food.isExpiring)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: food.expiresInDays < 0
                        ? AppColors.rose
                        : AppColors.warning,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    food.expiresInDays < 0 ? '已过期' : '临期优先',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _DetailMetric(
                label: '剩余',
                value: '${food.expiresInDays} 天',
                alert: food.isExpiring,
              ),
              _DetailMetric(label: '数量', value: '$quantity ${food.unit}'),
              _DetailMetric(label: '记录人', value: food.owner),
            ],
          ),
          const SizedBox(height: 22),
          if (widget.canEdit) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '这次使用多少？',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '减少用量',
                  onPressed: _busy || food.quantity < .001
                      ? null
                      : () => _stepAmount(-1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 82,
                  child: TextField(
                    key: const ValueKey('consume-quantity-input'),
                    controller: _amount,
                    enabled: !_busy && food.quantity >= .001,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: food.unit,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  tooltip: '增加用量',
                  onPressed: _busy || food.quantity < .001
                      ? null
                      : () => _stepAmount(1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppFilledButton.icon(
              key: const ValueKey('consume-food-button'),
              onPressed: _busy || food.quantity < .001 ? null : _consume,
              icon: const Icon(Icons.restaurant_rounded),
              label: Text('使用 ${_consumeQuantityLabel()} ${food.unit}'),
            ),
            if (_targetZone != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FridgeZone>(
                      initialValue: _targetZone,
                      decoration: const InputDecoration(labelText: '移动到'),
                      items: [
                        for (final zone in widget.zones)
                          if (zone.id != food.zone)
                            DropdownMenuItem(
                              value: zone,
                              child: Text(zone.name),
                            ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _targetZone = value);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    key: const ValueKey('move-food-button'),
                    onPressed: _busy ? null : _move,
                    child: const Text('移动'),
                  ),
                ],
              ),
            ],
            if (widget.onEdit != null) ...[
              const SizedBox(height: 6),
              AppOutlinedButton.icon(
                key: const ValueKey('edit-food-button'),
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('修改分类与信息'),
              ),
            ],
            const SizedBox(height: 9),
            TextButton(
              key: const ValueKey('discard-food-button'),
              onPressed: _busy ? null : _discard,
              child: const Text('丢弃这份食材'),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('当前账号只有查看权限'),
            ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: AppColors.cocoa),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.rose, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  double get _consumeQuantity =>
      double.tryParse(_amount.text.trim()) ?? double.nan;

  String _consumeQuantityLabel() {
    final value = _consumeQuantity;
    if (!value.isFinite) return '所填';
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  Future<void> _consume() async {
    final quantity = _consumeQuantity;
    if (!RegExp(r'^(?:\d+(?:\.\d{0,3})?|\.\d{1,3})$')
            .hasMatch(_amount.text.trim()) ||
        !quantity.isFinite ||
        quantity < .001 ||
        quantity > food.quantity ||
        (quantity * 1000 - (quantity * 1000).round()).abs() > .00001) {
      setState(() => _error = '用量至少 0.001，最多为当前库存，且最多 3 位小数。');
      return;
    }
    await _run(() => widget.onConsume(_consumeQuantity), '已记录使用');
  }

  Future<void> _move() async {
    final target = _targetZone;
    if (target != null) {
      await _run(() => widget.onMove(target), '已移动到${target.name}');
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('丢弃这份食材？'),
        content: Text(
          '${food.name} · ${food.quantity} ${food.unit}\n\n将移除这份库存并保留操作记录，当前尚无撤销入口。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          AppFilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('确认丢弃'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(widget.onDiscard, '已丢弃并保留操作记录');
  }

  Future<void> _edit() async {
    final handler = widget.onEdit;
    if (handler == null) return;
    // Closing the details sheet is only correct when the form actually saved;
    // the form itself shows the confirmation message.
    final saved = await handler();
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  String _zoneName(FridgeZoneId zone) {
    return switch (zone) {
      FridgeZoneId.fresh => '冷藏',
      FridgeZoneId.variable => '变温',
      FridgeZoneId.freezer => '冷冻',
      FridgeZoneId.pantry => '常温',
    };
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    this.alert = false,
  });

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paper.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.cocoa.withValues(alpha: 0.52),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: alert ? AppColors.rose : AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodFormSheet extends StatefulWidget {
  const _FoodFormSheet({
    required this.zones,
    required this.canEdit,
    this.onSave,
    this.editing,
    this.onUpdate,
  }) : assert(
         onSave != null || onUpdate != null,
         'a food form needs either onSave or onUpdate',
       );

  final List<FridgeZone> zones;
  final bool canEdit;
  final Future<void> Function(NewFoodInput input)? onSave;
  final FridgeFood? editing;
  final Future<void> Function(FoodEditInput input)? onUpdate;

  bool get isEditing => editing != null;

  @override
  State<_FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends State<_FoodFormSheet> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: '份');
  String _category = '其他';
  FridgeZone? _zone;
  DateTime _productionDate = DateUtils.dateOnly(DateTime.now());
  DateTime _expiresOn = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 7)),
  );
  bool _saving = false;
  String? _error;
  late DateTime _initialProductionDate;
  late DateTime _initialExpiresOn;
  late String _initialName;
  late String _initialQuantity;
  late String _initialUnit;
  late String _initialCategory;
  late FridgeZoneId? _initialZoneId;
  int? _containerId;

  bool get _hasChanges =>
      _nameController.text != _initialName ||
      _quantityController.text != _initialQuantity ||
      _unitController.text != _initialUnit ||
      _category != _initialCategory ||
      _zone?.id != _initialZoneId ||
      !DateUtils.isSameDay(_productionDate, _initialProductionDate) ||
      !DateUtils.isSameDay(_expiresOn, _initialExpiresOn);

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _nameController.text = editing.name;
      _quantityController.text = _formatQuantity(editing.quantity);
      _unitController.text = editing.unit;
      _category = foodCategoryOptions.contains(editing.category)
          ? editing.category
          : '其他';
      _zone =
          widget.zones.where((zone) => zone.id == editing.zone).firstOrNull ??
          widget.zones.firstOrNull;
      _containerId = editing.containerId;
      _productionDate =
          _parseDate(editing.productionDate) ?? _productionDate;
      _expiresOn = _parseDate(editing.expiresOn) ?? _productionDate;
    } else {
      _zone = widget.zones.firstOrNull;
    }
    _initialName = _nameController.text;
    _initialQuantity = _quantityController.text;
    _initialUnit = _unitController.text;
    _initialCategory = _category;
    _initialZoneId = _zone?.id;
    _initialProductionDate = _productionDate;
    _initialExpiresOn = _expiresOn;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    return FormExitGuard(
      hasChanges: () => _hasChanges,
      busy: () => _saving,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          16,
          22,
          28 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? '修改食材信息' : '放进一份新食材',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: isEditing ? '关闭修改' : '关闭新增',
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.canEdit
                  ? isEditing
                        ? '分类、数量、单位和日期都可以改，保存后立即同步到家庭冰箱。'
                        : '保存后会同步到家庭冰箱，并记录当前操作人。'
                  : '当前账号为只读成员或演示账号，不能写入真实冰箱。',
              style: TextStyle(
                color: widget.canEdit
                    ? AppColors.cocoa.withValues(alpha: 0.62)
                    : AppColors.rose,
              ),
            ),
            if (widget.zones.isNotEmpty) ...[
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('food-name-input'),
                controller: _nameController,
                enabled: widget.canEdit && !_saving,
                decoration: const InputDecoration(
                  labelText: '食材名称',
                  hintText: '例如：西兰花',
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('food-quantity-input'),
                      controller: _quantityController,
                      enabled: widget.canEdit && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '数量'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('food-unit-input'),
                      controller: _unitController,
                      enabled: widget.canEdit && !_saving,
                      decoration: const InputDecoration(labelText: '单位'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('food-category-input'),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '分类'),
                items: [
                  for (final category in foodCategoryOptions)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: widget.canEdit && !_saving
                    ? (value) {
                        if (value != null) setState(() => _category = value);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FridgeZone>(
                initialValue: _zone,
                decoration: const InputDecoration(labelText: '存放区域'),
                items: [
                  for (final zone in widget.zones)
                    DropdownMenuItem(value: zone, child: Text(zone.name)),
                ],
                onChanged: widget.canEdit && !_saving
                    ? (value) {
                        if (value != null) {
                          setState(() {
                            _zone = value;
                          });
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: '生产日期',
                      value: _productionDate,
                      enabled: widget.canEdit && !_saving,
                      onTap: () => _pickDate(production: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: '到期日期',
                      value: _expiresOn,
                      enabled: widget.canEdit && !_saving,
                      onTap: () => _pickDate(production: false),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.rose, fontSize: 11),
                ),
              ],
              const SizedBox(height: 18),
              AppFilledButton.icon(
                key: const ValueKey('save-food-button'),
                onPressed: widget.canEdit && !_saving ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isEditing ? Icons.save_outlined : Icons.add_rounded,
                      ),
                label: Text(
                  _saving
                      ? (isEditing ? '正在保存' : '正在保存')
                      : (isEditing ? '保存修改' : '保存食材'),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text('当前冰箱没有可写入的分区。'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool production}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: production ? _productionDate : _expiresOn,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (production) {
        _productionDate = selected;
      } else {
        _expiresOn = selected;
      }
    });
  }

  Future<void> _save() async {
    final quantity = double.tryParse(_quantityController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _unitController.text.trim().isEmpty ||
        quantity == null ||
        !quantity.isFinite ||
        quantity < 0.001 ||
        quantity > 999999999.999 ||
        !RegExp(r'^\d+(?:\.\d{1,3})?$')
            .hasMatch(_quantityController.text.trim())) {
      setState(() => _error = '请填写名称和单位；数量至少 0.001，最多 9 位整数和 3 位小数');
      return;
    }
    if (_nameController.text.trim().length > 80 ||
        _unitController.text.trim().length > 20) {
      setState(() => _error = '名称最多 80 字、单位最多 20 字');
      return;
    }
    if (_expiresOn.isBefore(_productionDate)) {
      setState(() => _error = '到期日期不能早于生产日期');
      return;
    }
    final zone = _zone!;
    // Keep the original container when the zone is unchanged; otherwise the
    // old container would no longer belong to the selected zone.
    final containerId = zone.id == _initialZoneId
        ? _containerId ?? zone.containers.firstOrNull?.id
        : zone.containers.firstOrNull?.id;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final editing = widget.editing;
      if (editing != null) {
        await widget.onUpdate!(
          FoodEditInput(
            foodId: editing.serverId!,
            version: editing.version,
            zone: zone,
            containerId: containerId,
            name: _nameController.text.trim(),
            category: _category,
            quantity: quantity,
            unit: _unitController.text.trim(),
            productionDate: _productionDate,
            expiresOn: _expiresOn,
            tags: editing.tags,
            modelKey: editing.modelKey,
          ),
        );
      } else {
        await widget.onSave!(
          NewFoodInput(
            zone: zone,
            name: _nameController.text.trim(),
            category: _category,
            quantity: quantity,
            unit: _unitController.text.trim(),
            productionDate: _productionDate,
            expiresOn: _expiresOn,
          ),
        );
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(content: Text(editing != null ? '食材信息已更新' : '食材已保存')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  static String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static DateTime? _parseDate(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          '${value.year}-${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

class _TablePreviewSheet extends StatelessWidget {
  const _TablePreviewSheet({required this.foods, required this.onFoodTap});

  final List<FridgeFood> foods;
  final ValueChanged<FridgeFood> onFoodTap;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.74,
      maxChildSize: 0.94,
      minChildSize: 0.56,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const _SheetHandle(),
            const SizedBox(height: 22),
            Text('冰箱清单', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 5),
            Text(
              'WebGL 场景不可用时，也可以在这里查看完整数据。',
              style: TextStyle(color: AppColors.cocoa.withValues(alpha: 0.62)),
            ),
            const SizedBox(height: 16),
            if (foods.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('冰箱里还没有食材'),
              ),
            for (final food in foods)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Material(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onFoodTap(food),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          Text(
                            food.emoji,
                            style: const TextStyle(fontSize: 27),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${food.category} · ${food.owner}',
                                  style: TextStyle(
                                    color: AppColors.cocoa.withValues(
                                      alpha: 0.55,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${food.expiresInDays} 天',
                            style: TextStyle(
                              color: food.isExpiring
                                  ? AppColors.rose
                                  : AppColors.sage,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Confirms a bulk cleanup and lists every item that will be discarded.
///
/// Returns `true` when the user confirms; the caller performs the write so the
/// sheet stays free of data-access concerns.
Future<bool?> showExpiredCleanupSheet(
  BuildContext context, {
  required List<FridgeFood> expired,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    builder: (context) => _ExpiredCleanupSheet(expired: expired),
  );
}

class _ExpiredCleanupSheet extends StatelessWidget {
  const _ExpiredCleanupSheet({required this.expired});

  final List<FridgeFood> expired;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '清理过期食材',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: '关闭清理',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '将丢弃 ${expired.length} 份已过期食材。清理会写入操作记录，需要时可以逐条撤销。',
              style: TextStyle(
                color: AppColors.cocoa.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.linen,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final food in expired)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(food.emoji, style: const TextStyle(fontSize: 20)),
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
                                const SizedBox(height: 2),
                                Text(
                                  '${food.category} · ${_quantityLabel(food.quantity)} ${food.unit}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '过期 ${-food.expiresInDays} 天',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.rose,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppFilledButton.icon(
              key: const ValueKey('confirm-expired-cleanup'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: Text('清理 ${expired.length} 份过期食材'),
            ),
            const SizedBox(height: 6),
            AppOutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('先不清理'),
            ),
          ],
        ),
      ),
    );
  }

  static String _quantityLabel(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

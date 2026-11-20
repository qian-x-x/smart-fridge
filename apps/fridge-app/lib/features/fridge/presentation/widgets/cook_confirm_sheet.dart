import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/shared/widgets/action_button.dart';

/// Confirms a cooking session and deducts the selected inventory in one request.
/// The batch is submitted only after every row is chosen and validated locally;
/// the server still re-checks quantities and versions.
class CookConfirmSheet extends ConsumerStatefulWidget {
  const CookConfirmSheet({
    super.key,
    required this.fridgeId,
    required this.canEdit,
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.candidates,
    this.plan,
    this.familyId,
  });

  final int fridgeId;
  final bool canEdit;
  final int recipeId;
  final String recipeName;
  final int servings;
  final List<FridgeFood> candidates;
  final List<CookItemInput>? plan;
  final int? familyId;

  @override
  ConsumerState<CookConfirmSheet> createState() => _CookConfirmSheetState();
}

class _CookConfirmSheetState extends ConsumerState<CookConfirmSheet> {
  final Map<int, double> _quantities = {};
  final Set<int> _selected = {};
  bool _saving = false;
  String? _error;
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();
    for (final food in widget.candidates) {
      _selected.add(food.serverId!);
      _quantities[food.serverId!] =
          widget.plan
              ?.where((item) => item.foodItemId == food.serverId)
              .firstOrNull
              ?.quantity ??
          (food.quantity >= 1 ? 1 : food.quantity);
    }
  }

  double _quantityOf(FridgeFood food) {
    final value = _quantities[food.serverId!] ?? 1;
    return value > food.quantity ? food.quantity : value;
  }

  void _step(FridgeFood food, double delta) {
    final next = (_quantityOf(food) + delta).clamp(0.001, food.quantity);
    setState(() {
      _quantities[food.serverId!] = (next * 1000).round() / 1000;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final items =
        widget.plan ??
        [
          for (final food in widget.candidates)
            if (_selected.contains(food.serverId!))
              CookItemInput(
                foodItemId: food.serverId!,
                quantity: _quantityOf(food),
                version: food.version,
              ),
        ];
    if (items.isEmpty) {
      setState(() => _error = '请至少选择一种要扣减的食材');
      return;
    }
    final requestId = _pendingRequestId ?? newInventoryRequestId('cook');
    setState(() {
      _pendingRequestId = requestId;
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(fridgeWorkspaceProvider.notifier)
          .cook(
            fridgeId: widget.fridgeId,
            familyId: widget.familyId,
            recipeId: widget.recipeId,
            recipeName: widget.recipeName,
            servings: widget.servings,
            items: items,
            requestId: requestId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is! ApiFailure || !error.writeOutcomeUncertain) {
          _pendingRequestId = null;
        }
        _saving = false;
        _error = '扣减失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.canEdit && widget.candidates.isNotEmpty;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '做「${widget.recipeName}」',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '确认要扣减的食材和数量，提交后写入做饭记录。',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: widget.candidates.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '冰箱里还没有这道菜需要的食材',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(12, 6, 16, 12),
                      itemCount: widget.candidates.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 12),
                      itemBuilder: (context, index) {
                        final food = widget.candidates[index];
                        return _CookRow(
                          food: food,
                          selected: _selected.contains(food.serverId!),
                          quantity: _quantityOf(food),
                          enabled:
                              editable &&
                              !_saving &&
                              widget.plan == null &&
                              _pendingRequestId == null,
                          onToggle: (value) => setState(() {
                            if (value) {
                              _selected.add(food.serverId!);
                            } else {
                              _selected.remove(food.serverId!);
                            }
                          }),
                          onDecrease: () => _step(food, -0.5),
                          onIncrease: () => _step(food, 0.5),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: AppFilledButton.icon(
                        onPressed: editable && !_saving ? _submit : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.soup_kitchen_outlined, size: 18),
                        label: Text(
                          _saving
                              ? '正在扣减…'
                              : _pendingRequestId != null
                              ? '重试本次制作'
                              : widget.canEdit
                              ? '确认做饭并扣减'
                              : '当前账号没有编辑权限',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CookRow extends StatelessWidget {
  const _CookRow({
    required this.food,
    required this.selected,
    required this.quantity,
    required this.enabled,
    required this.onToggle,
    required this.onDecrease,
    required this.onIncrease,
  });

  final FridgeFood food;
  final bool selected;
  final double quantity;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: enabled ? (value) => onToggle(value ?? false) : null,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${food.emoji} ${food.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '库存 ${_format(food.quantity)} ${food.unit}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove,
            onPressed: enabled && selected && quantity > 0.1
                ? onDecrease
                : null,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${_format(quantity)} ${food.unit}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.cocoa : AppColors.muted,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onPressed: enabled && selected && quantity < food.quantity
                ? onIncrease
                : null,
          ),
        ],
      ),
    );
  }

  static String _format(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
      ),
    );
  }
}

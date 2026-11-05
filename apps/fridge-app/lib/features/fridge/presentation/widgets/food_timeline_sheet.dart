import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

/// Bottom sheet listing the newest fridge operations with undo and restore
/// actions. Reads its own snapshot so a failed write never hides the list.
class FoodTimelineSheet extends ConsumerStatefulWidget {
  const FoodTimelineSheet({super.key, required this.workspace});

  final FridgeWorkspaceData workspace;

  @override
  ConsumerState<FoodTimelineSheet> createState() => _FoodTimelineSheetState();
}

class _FoodTimelineSheetState extends ConsumerState<FoodTimelineSheet> {
  late Future<List<FoodOperation>> _operations;
  int? _pendingOperationId;

  bool get _canEdit => widget.workspace.canEdit && !widget.workspace.isDemo;

  @override
  void initState() {
    super.initState();
    _operations = _load();
  }

  Future<List<FoodOperation>> _load() {
    return ref
        .read(fridgeWorkspaceProvider.notifier)
        .loadOperations(widget.workspace.fridgeId);
  }

  Future<void> _act(FoodOperation operation, {required bool undo}) async {
    if (_pendingOperationId != null) {
      return;
    }
    setState(() => _pendingOperationId = operation.id);
    try {
      final controller = ref.read(fridgeWorkspaceProvider.notifier);
      if (undo) {
        await controller.undoOperation(operation);
      } else {
        await controller.restoreOperation(operation);
      }
      if (!mounted) return;
      setState(() => _operations = _load());
      _notify(undo ? '已撤销「${operation.foodName}」的这次操作' : '已恢复这次操作');
    } on Object catch (error) {
      if (!mounted) return;
      _notify('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() => _pendingOperationId = null);
      }
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
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
              padding: const EdgeInsets.fromLTRB(22, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '操作记录',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '最近 30 条，可撤销移动、使用、做饭与丢弃',
                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<FoodOperation>>(
                future: _operations,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _TimelineMessage(
                      icon: Icons.cloud_off_outlined,
                      title: '操作记录暂时无法加载',
                      detail: '${snapshot.error}',
                      actionLabel: '重新加载',
                      onAction: () => setState(() => _operations = _load()),
                    );
                  }
                  final operations = snapshot.data ?? const <FoodOperation>[];
                  if (operations.isEmpty) {
                    return const _TimelineMessage(
                      icon: Icons.history_toggle_off,
                      title: '还没有操作记录',
                      detail: '新增、移动或使用食材后，这里会留下可撤销的记录。',
                    );
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: operations.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (context, index) => _TimelineRow(
                      operation: operations[index],
                      canEdit: _canEdit,
                      busy: _pendingOperationId != null,
                      pending: _pendingOperationId == operations[index].id,
                      onUndo: () => _act(operations[index], undo: true),
                      onRestore: () => _act(operations[index], undo: false),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.operation,
    required this.canEdit,
    required this.busy,
    required this.pending,
    required this.onUndo,
    required this.onRestore,
  });

  final FoodOperation operation;
  final bool canEdit;
  final bool busy;
  final bool pending;
  final VoidCallback onUndo;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final showUndo = canEdit && operation.canUndo;
    final showRestore = canEdit && operation.canRestore;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _tint(operation.action),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon(operation.action), size: 18, color: AppColors.cocoa),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        operation.foodName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: operation.actionLabel,
                      undone: operation.undone,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  operation.summary,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeLabel(operation.createdAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          if (pending)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 6),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (showUndo || showRestore)
            TextButton(
              onPressed: busy ? null : (showUndo ? onUndo : onRestore),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.terracotta,
              ),
              child: Text(showUndo ? '撤销' : '恢复'),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  static String _timeLabel(DateTime? value) {
    if (value == null) {
      return '';
    }
    final now = DateTime.now();
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '今天 $time';
    }
    return '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} $time';
  }

  static IconData _icon(String action) => switch (action) {
    'ADD' => Icons.add_circle_outline,
    'UPDATE' => Icons.edit_note,
    'MOVE' => Icons.swap_horiz,
    'CONSUME' => Icons.restaurant,
    'COOK' => Icons.soup_kitchen_outlined,
    'DISCARD' => Icons.delete_outline,
    'UNDO' => Icons.undo,
    'RESTORE' => Icons.redo,
    _ => Icons.history,
  };

  static Color _tint(String action) => switch (action) {
    'DISCARD' || 'UNDO' => AppColors.rose.withValues(alpha: 0.12),
    'COOK' || 'CONSUME' => AppColors.terracotta.withValues(alpha: 0.12),
    _ => AppColors.sage.withValues(alpha: 0.16),
  };
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.undone});

  final String label;
  final bool undone;

  @override
  Widget build(BuildContext context) {
    final color = undone ? AppColors.muted : AppColors.cocoa;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (undone ? AppColors.muted : AppColors.sand).withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        undone ? '$label · 已撤销' : label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }
}

class _TimelineMessage extends StatelessWidget {
  const _TimelineMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

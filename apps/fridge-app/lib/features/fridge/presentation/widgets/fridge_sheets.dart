import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';

Future<void> showFoodDetails(BuildContext context, FridgeFood food) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    builder: (context) => _FoodDetailsSheet(food: food),
  );
}

Future<void> showTablePreview(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    builder: (context) => const _TablePreviewSheet(),
  );
}

Future<void> showAddFoodPreview(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    builder: (context) => const _AddFoodPreviewSheet(),
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

class _FoodDetailsSheet extends StatelessWidget {
  const _FoodDetailsSheet({required this.food});

  final FridgeFood food;

  @override
  Widget build(BuildContext context) {
    final quantity = food.quantity % 1 == 0
        ? food.quantity.toInt().toString()
        : food.quantity.toString();

    return Padding(
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
                  borderRadius: BorderRadius.circular(23),
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
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    '临期优先',
                    style: TextStyle(
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
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('记录使用或移动'),
          ),
          const SizedBox(height: 9),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('把这一份标记为已吃完'),
          ),
        ],
      ),
    );
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

class _AddFoodPreviewSheet extends StatelessWidget {
  const _AddFoodPreviewSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text('放进一份新食材', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            '先完成交互与字段布局，S2 接入 fridge-service 后即可真实保存。',
            style: TextStyle(color: AppColors.cocoa.withValues(alpha: 0.62)),
          ),
          const SizedBox(height: 20),
          const TextField(
            decoration: InputDecoration(
              labelText: '食材名称',
              hintText: '例如：西兰花',
              prefixIcon: Icon(Icons.eco_outlined),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: '数量'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: TextField(decoration: InputDecoration(labelText: '单位')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('表单节点已完成，下一阶段接入真实保存')),
              );
            },
            child: const Text('选择贴纸并保存'),
          ),
        ],
      ),
    );
  }
}

class _TablePreviewSheet extends StatelessWidget {
  const _TablePreviewSheet();

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
              '2.5D 素材异常时，也可以在这里查看完整数据。',
              style: TextStyle(color: AppColors.cocoa.withValues(alpha: 0.62)),
            ),
            const SizedBox(height: 16),
            for (final food in demoFoods)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Text(food.emoji, style: const TextStyle(fontSize: 27)),
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
                                color: AppColors.cocoa.withValues(alpha: 0.55),
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
          ],
        );
      },
    );
  }
}

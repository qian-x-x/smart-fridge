import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/fridge_sheets.dart';

void main() {
  testWidgets('editing a food pre-fills the form and saves the new category', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    FoodEditInput? captured;
    await tester.pumpWidget(
      _host(
        onEdit: (context) => showEditFood(
          context,
          zones: _zones,
          canEdit: true,
          food: _broccoli,
          onSave: (input) async => captured = input,
        ),
      ),
    );

    await tester.tap(find.text('details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-food-button')));
    await tester.pumpAndSettle();

    expect(find.text('修改食材信息'), findsOneWidget);
    // Pre-filled from the existing item instead of starting from a blank form.
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('food-name-input')),
    );
    expect(nameField.controller?.text, '西兰花');
    expect(find.text('水果'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('food-category-input')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('蔬菜'), findsWidgets);
    await tester.tap(find.text('蔬菜').last);
    // The dropdown route keeps animating a caret frame, so settle with pumps
    // instead of waiting for an idle frame that never arrives.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const ValueKey('save-food-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(captured, isNotNull);
    expect(captured!.category, '蔬菜');
    expect(captured!.foodId, 31);
    expect(captured!.version, 3);
    expect(captured!.zone.serverId, 11);
    expect(captured!.containerId, 21);
    expect(captured!.name, '西兰花');
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only members see no edit entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        canEdit: false,
        onEdit: (context) => showEditFood(
          context,
          zones: _zones,
          canEdit: false,
          food: _broccoli,
          onSave: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('details'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-food-button')), findsNothing);
    expect(find.text('当前账号只有查看权限'), findsOneWidget);
  });

  testWidgets('cleanup sheet lists expired items and confirms', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool? confirmed;
    await tester.pumpWidget(
      _host(
        onCleanup: (context) async {
          confirmed = await showExpiredCleanupSheet(
            context,
            expired: const [_expiredMilk, _expiredEgg],
          );
        },
      ),
    );

    await tester.tap(find.text('cleanup'));
    await tester.pumpAndSettle();

    expect(find.text('清理过期食材'), findsOneWidget);
    expect(find.text('过期牛奶'), findsOneWidget);
    expect(find.text('过期鸡蛋'), findsOneWidget);
    expect(find.text('过期 3 天'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-expired-cleanup')));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

const _zones = [
  FridgeZone(
    id: FridgeZoneId.fresh,
    serverId: 11,
    name: '冷藏',
    description: '蔬果 · 饮品',
    temperature: '4°C',
    emoji: '🥬',
    containers: [FridgeContainer(id: 21, name: '上层', type: 'SHELF')],
  ),
  FridgeZone(
    id: FridgeZoneId.freezer,
    serverId: 12,
    name: '冷冻',
    description: '速冻',
    temperature: '-18°C',
    emoji: '🧊',
    containers: [FridgeContainer(id: 22, name: '抽屉', type: 'DRAWER')],
  ),
];

const _broccoli = FridgeFood(
  id: '31',
  serverId: 31,
  name: '西兰花',
  emoji: '🥦',
  quantity: 1,
  unit: '颗',
  expiresInDays: 4,
  zone: FridgeZoneId.fresh,
  category: '水果',
  owner: '测试',
  tilt: 0,
  containerId: 21,
  version: 3,
  tags: ['清淡'],
  productionDate: '2026-11-01',
  expiresOn: '2026-11-10',
);

const _expiredMilk = FridgeFood(
  id: '40',
  serverId: 40,
  name: '过期牛奶',
  emoji: '🥛',
  quantity: 2,
  unit: '盒',
  expiresInDays: -3,
  zone: FridgeZoneId.fresh,
  category: '奶制品',
  owner: '测试',
  tilt: 0,
  version: 1,
);

const _expiredEgg = FridgeFood(
  id: '41',
  serverId: 41,
  name: '过期鸡蛋',
  emoji: '🥚',
  quantity: 4,
  unit: '个',
  expiresInDays: -1,
  zone: FridgeZoneId.fresh,
  category: '蛋类',
  owner: '测试',
  tilt: 0,
  version: 1,
);

Widget _host({
  bool canEdit = true,
  Future<bool?> Function(BuildContext context)? onEdit,
  Future<void> Function(BuildContext context)? onCleanup,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => showFoodDetails(
                  context,
                  _broccoli,
                  zones: _zones,
                  canEdit: canEdit,
                  onConsume: (_) async {},
                  onMove: (_) async {},
                  onDiscard: () async {},
                  onEdit: canEdit && onEdit != null
                      ? () => onEdit(context)
                      : null,
                ),
                child: const Text('details'),
              ),
              if (onCleanup != null)
                TextButton(
                  onPressed: () => onCleanup(context),
                  child: const Text('cleanup'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_sticker_stack.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/reference_sticker_layer.dart';

void main() {
  test('stacks merge only the same food name in the same zone', () {
    final stacks = groupFridgeStickers([
      _food('old-oil', '食用油', portions: 2, days: -1),
      _food('fresh-oil', '食用油', portions: 4, days: 5),
      _food('use-first', ' 食用油 ', days: 2),
      _food('freezer-oil', '食用油', zone: FridgeZoneId.freezer),
      _food('soy-one', '生抽'),
      _food('soy-two', '老抽'),
      _food('finished', '牛奶', portions: 0),
    ]);
    expect(stacks.map((stack) => stack.food.id), [
      'use-first',
      'freezer-oil',
      'soy-one',
      'soy-two',
    ]);
    expect(stacks.first.portions, 7);
    expect(stacks.first.badge, '7');
    expect(stacks.first.layers, 3);
  });

  test('old batches can stack without adding incomparable amounts', () {
    final stack = groupFridgeStickers([
      _food('oil-ml', '食用油', portions: 100, unit: '毫升'),
      _food('oil-portions', '食用油', portions: 2),
    ]).single;
    expect(stack.layers, 2);
    expect(stack.badge, isNull);
    expect(stack.portions, isNull);
  });

  testWidgets(
    'drawer shrinks its stacks at 17 kinds and clamps the final page',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 440));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final foods = [
        _food('oil', '食用油'),
        _food('oil-batch-2', '食用油', portions: 2),
        for (var index = 1; index <= 32; index++)
          _food('other-$index', '库存$index'),
      ];
      FridgeFood? selected;
      Future<void> show(int rows) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ReferenceStickerLayer(
                zone: FridgeZoneId.variable,
                foods: foods.take(rows).toList(),
                photoSize: 320,
                center: const Offset(160, 220),
                interactive: true,
                onFoodSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      );

      await show(17);
      await tester.pumpAndSettle();
      final oil = find.byKey(const ValueKey('oil'));
      final denseOverflow = find.byKey(const ValueKey('other-16'));
      final defaultWidth = tester.getSize(oil).width;
      expect(find.byKey(const ValueKey('oil-batch-2')), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('下一组食材'), findsNothing);

      await show(18);
      await tester.pumpAndSettle();
      expect(denseOverflow, findsOneWidget);
      expect(tester.getSize(oil).width, lessThan(defaultWidth));
      expect(find.byTooltip('下一组食材'), findsNothing);
      await tester.tap(oil);
      expect(selected?.id, 'oil');

      await show(34);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('下一组食材'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('other-32')), findsOneWidget);
      expect(oil, findsNothing);

      await show(17);
      await tester.pumpAndSettle();
      expect(tester.getSize(oil).width, closeTo(defaultWidth, .01));
      expect(find.byTooltip('下一组食材'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

FridgeFood _food(
  String id,
  String name, {
  double portions = 1,
  int days = 7,
  String unit = '份',
  FridgeZoneId zone = FridgeZoneId.variable,
}) => FridgeFood(
  id: id,
  name: name,
  emoji: '🍽️',
  quantity: portions,
  unit: unit,
  expiresInDays: days,
  zone: zone,
  category: '调味品',
  owner: '',
  tilt: 0,
);

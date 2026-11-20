import 'dart:async';

import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/application/food_search_provider.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/fridge_home_page.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_sticker_image.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/webgl_fridge_view.dart';
import 'package:smart_fridge_app/features/recipe/data/home_recipe_catalog.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

void main() {
  testWidgets(
    'sticker recipes show missing ingredients and deduct complete stock once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ingredients = _tomatoEggStock('西红柿');
      final source = _RemoteFridgeSource()..foodsOverride = ingredients;
      await tester.pumpWidget(_realApp(source, recipes: _HomeRecipeSource()));
      await tester.pumpAndSettle();
      final view = tester.widget<WebGLFridgeView>(find.byType(WebGLFridgeView));
      view.onFoodSelected!(ingredients.first);
      await tester.pumpAndSettle();
      expect(find.text('番茄滑蛋'), findsOneWidget);
      expect(find.text('清蒸南瓜'), findsNothing);
      expect(find.text('鸡蛋 · 已备'), findsOneWidget);
      expect(find.text('盐 · 已备'), findsOneWidget);
      final cook = find.byKey(const ValueKey('cook-recipe-1'));
      source.loseCookResponse = true;
      await tester.tap(cook);
      await tester.pumpAndSettle();
      expect(find.text('重试本次制作'), findsOneWidget);
      await tester.tap(find.text('重试本次制作'));
      await tester.pumpAndSettle();
      expect(source.cookRequests.toSet().length, 1);
      expect(source.cookRequests.length, 2);
      expect(source.cookItems.last.map((item) => item.foodItemId), [
        100,
        101,
        102,
        103,
      ]);
      expect(source.cookItems.last.every((item) => item.quantity == 1), isTrue);
      expect(find.textContaining('已制作「番茄滑蛋」'), findsOneWidget);
      expect(find.text('鸡蛋 · 缺少'), findsOneWidget);
      expect(find.text('食材未齐'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('filtered list opens sticker, inventory details and cooking', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource()..foodsOverride = _tomatoEggStock('番茄');
    await tester.pumpWidget(_realApp(source, recipes: _HomeRecipeSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食材清单'));
    await tester.pumpAndSettle();
    final query = find.widgetWithText(TextField, '食材名称');
    await tester.enterText(query, '番茄');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('找到 1 份食材'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '番茄'));
    await tester.pumpAndSettle();
    final sticker = find.byWidgetPredicate(
      (widget) =>
          widget is IngredientStickerImage &&
          widget.size == 58 &&
          widget.sticker?.imageName == '西红柿',
    );
    expect(sticker, findsOneWidget);
    expect(find.text('相关菜谱'), findsOneWidget);
    expect(find.text('1 份 · 冷藏'), findsOneWidget);
    expect(find.text('鸡蛋 · 已备'), findsOneWidget);
    expect(find.text('清蒸南瓜'), findsNothing);

    await tester.tap(find.text('库存详情'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IngredientStickerImage &&
            widget.size == 78 &&
            widget.sticker?.imageName == '西红柿',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('edit-food-button')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cook-recipe-1')));
    await tester.pumpAndSettle();
    expect(source.cookRequests, hasLength(1));
    expect(source.cookItems.single.map((item) => item.foodItemId), [
      100,
      101,
      102,
      103,
    ]);
    expect(source.cookItems.single.every((item) => item.quantity == 1), isTrue);
    expect(find.textContaining('已制作「番茄滑蛋」'), findsOneWidget);
    expect(find.text('食材未齐'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭菜谱'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(query).controller!.text, '番茄');
    expect(find.text('找到 0 份食材'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only members can open list recipes and stock details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource()..foodsOverride = _tomatoEggStock('番茄');
    await tester.pumpWidget(
      _realApp(source, recipes: _HomeRecipeSource(), role: 'VIEWER'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('冰箱清单'));
    await tester.pumpAndSettle();
    final row = find.widgetWithText(ListTile, '番茄');
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('番茄滑蛋'), findsOneWidget);
    expect(find.text('当前仅可查看菜谱'), findsWidgets);
    expect(find.text('立即制作'), findsNothing);
    await tester.tap(find.text('库存详情'));
    await tester.pumpAndSettle();
    expect(find.text('当前账号只有查看权限'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-food-button')), findsNothing);
    expect(source.cookRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer list result refreshes the stock used by recipes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stock = _tomatoEggStock('番茄');
    final source = _RemoteFridgeSource()
      ..foodsOverride = stock.take(3).toList();
    await tester.pumpWidget(_realApp(source, recipes: _HomeRecipeSource()));
    await tester.pumpAndSettle();

    source.foodsOverride = stock;
    await tester.tap(find.text('食材清单'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '食盐'));
    await tester.pumpAndSettle();
    expect(find.text('库存详情'), findsOneWidget);
    expect(find.text('番茄滑蛋'), findsOneWidget);
    expect(find.text('立即制作'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects multiple stickers, whole portions and storage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource();
    await tester.pumpWidget(_realApp(source));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加食材'));
    await tester.pumpAndSettle();
    final query = find.byKey(const ValueKey('ingredient-picker-search'));
    expect(find.byKey(const ValueKey('food-name-input')), findsNothing);

    await tester.enterText(query, '西红柿');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ingredient-西红柿')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('增加西红柿份量'));
    await tester.enterText(query, '三文鱼');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ingredient-三文鱼')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('长期 · 冷冻'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-catalog-foods')));
    await tester.pumpAndSettle();

    expect(source.catalogSelections.single.map((input) => input.sticker.name), [
      '西红柿',
      '三文鱼',
    ]);
    expect(source.catalogSelections.single.map((input) => input.portions), [
      2,
      1,
    ]);
    expect(source.catalogSelections.single.map((input) => input.zone), [
      FridgeZoneId.fresh,
      FridgeZoneId.freezer,
    ]);
    expect(
      find.byKey(const ValueKey('ingredient-picker-search')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('protects a selected but unsaved sticker list on close', (
    tester,
  ) async {
    final source = _RemoteFridgeSource();
    await tester.pumpWidget(_realApp(source));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加食材'));
    await tester.pumpAndSettle();
    final query = find.byKey(const ValueKey('ingredient-picker-search'));
    await tester.enterText(query, '红茶');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ingredient-红茶')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭添加'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的内容？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.textContaining('共 1 份'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭添加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃填写'));
    await tester.pumpAndSettle();
    expect(source.catalogSelections, isEmpty);
    expect(query, findsNothing);
  });

  testWidgets(
    'food usage validates the selected amount and supports fractions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _RemoteFridgeSource();
      await tester.pumpWidget(_realApp(source));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('测试牛奶'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('测试牛奶'));
      await tester.pumpAndSettle();
      for (final amount in ['3', 'NaN', '0.0001', '1.2345', '1.000000001']) {
        await tester.enterText(
          find.byKey(const ValueKey('consume-quantity-input')),
          amount,
        );
        await tester.tap(find.byKey(const ValueKey('consume-food-button')));
        await tester.pumpAndSettle();
        expect(source.consumedFood, isNull);
        expect(find.textContaining('用量至少 0.001'), findsOneWidget);
      }
      await tester.enterText(
        find.byKey(const ValueKey('consume-quantity-input')),
        '0.5',
      );
      await tester.tap(find.byKey(const ValueKey('consume-food-button')));
      await tester.pumpAndSettle();
      expect(source.consumedQuantity, .5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('modal routes suspend scene input until they close', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_realApp(_RemoteFridgeSource()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<WebGLFridgeView>(find.byType(WebGLFridgeView)).interactive,
      isTrue,
    );
    await tester.ensureVisible(find.text('添加食材'));
    await tester.tap(find.text('添加食材'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<WebGLFridgeView>(find.byType(WebGLFridgeView)).interactive,
      isFalse,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      tester.widget<WebGLFridgeView>(find.byType(WebGLFridgeView)).interactive,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries the same catalog request after a lost response', (
    tester,
  ) async {
    final source = _RemoteFridgeSource()..loseCatalogResponse = true;
    await tester.pumpWidget(_realApp(source));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加食材'));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-catalog-foods'));
    final query = find.byKey(const ValueKey('ingredient-picker-search'));
    await tester.enterText(query, '豆浆');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ingredient-豆浆')));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('重试本次添加'), findsOneWidget);
    final increment = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == '增加豆浆份量',
    );
    expect(tester.widget<IconButton>(increment).onPressed, isNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(source.catalogRequests.length, 2);
    expect(source.catalogRequests.toSet().length, 1);
    expect(source.catalogSelections.map((inputs) => inputs.single.portions), [
      1,
      1,
    ]);
    expect(source.catalogSelections.map((inputs) => inputs.single.zone), [
      FridgeZoneId.variable,
      FridgeZoneId.variable,
    ]);
    expect(query, findsNothing);
  });
  testWidgets('pending fridge creation prevents duplicate submissions', (
    tester,
  ) async {
    final source = _SetupFridgeSource()..gate = Completer<void>();
    await tester.pumpWidget(_setupApp(source));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('create-fridge-button'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(source.createCount, 1);
    expect(find.text('正在创建…'), findsOneWidget);
    source.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('测试牛奶'), findsOneWidget);
  });
  testWidgets('owner creates a fridge from the empty state on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _SetupFridgeSource();
    await tester.pumpWidget(_setupApp(source));
    await tester.pumpAndSettle();
    expect(find.text('小满的家尚未创建冰箱'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('fridge-name-input')),
      ' 厨房冰箱 ',
    );
    await tester.tap(find.byKey(const ValueKey('create-fridge-button')));
    await tester.pumpAndSettle();
    expect(source.createdFamilyId, 4);
    expect(source.createdName, '厨房冰箱');
    expect(find.text('测试牛奶'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty name does not send a request and API rejection allows retry',
    (tester) async {
      final source = _SetupFridgeSource()..reject = true;
      await tester.pumpWidget(_setupApp(source));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('fridge-name-input'));
      final button = find.byKey(const ValueKey('create-fridge-button'));
      await tester.enterText(input, '   ');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(source.createdFamilyId, isNull);
      expect(find.textContaining('请输入 1 至 80'), findsOneWidget);
      await tester.enterText(input, '新冰箱');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('服务暂不可用'), findsOneWidget);
      expect(find.text('新冰箱'), findsOneWidget);
      source.reject = false;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('测试牛奶'), findsOneWidget);
    },
  );

  for (final role in ['EDITOR', 'VIEWER']) {
    testWidgets('$role cannot create a missing fridge', (tester) async {
      await tester.pumpWidget(_setupApp(_SetupFridgeSource(), role: role));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create-fridge-button')), findsNothing);
      expect(find.textContaining('请联系家庭拥有者'), findsOneWidget);
    });
  }

  testWidgets('account without family sees family setup entry', (tester) async {
    await tester.pumpWidget(_setupApp(_SetupFridgeSource(), empty: true));
    await tester.pumpAndSettle();
    expect(find.text('先创建或加入一个家庭'), findsOneWidget);
    expect(find.text('前往家庭页'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-fridge-button')), findsNothing);
  });
  testWidgets(
    'home exposes accessible fridge zones and switches compartments',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: FridgeHomePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我家的冰箱'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('webgl-fridge-fallback')),
        findsOneWidget,
      );
      expect(find.text('冷藏'), findsOneWidget);
      expect(find.text('变温'), findsOneWidget);
      expect(find.text('冷冻'), findsOneWidget);
      expect(find.text('常温'), findsNothing);
      expect(find.text('番茄'), findsOneWidget);

      final cameraTransform = find.descendant(
        of: find.byKey(const ValueKey('fridge-reference-camera')),
        matching: find.byType(Transform),
      );
      double zoom() =>
          tester.widget<Transform>(cameraTransform.first).transform.entry(0, 0);
      double drawerOpacity(FridgeZoneId zone) => tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byKey(ValueKey(zone)),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
      for (final zone in [FridgeZoneId.variable, FridgeZoneId.freezer]) {
        final drawer = tester.widget<Image>(
          find.descendant(
            of: find.byKey(ValueKey(zone)),
            matching: find.byType(Image),
          ),
        );
        expect(drawer.fit, BoxFit.contain);
      }

      await tester.tap(find.text('冷藏'));
      await tester.pump();
      expect(zoom(), closeTo(1, 0.001));
      await tester.pump(const Duration(milliseconds: 200));
      expect(zoom(), allOf(greaterThan(1), lessThan(1.65)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(zoom(), closeTo(1.65, 0.001));

      await tester.tap(find.text('变温'));
      await tester.pump();
      expect(drawerOpacity(FridgeZoneId.variable), 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(drawerOpacity(FridgeZoneId.variable), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(drawerOpacity(FridgeZoneId.variable), 1);
      expect(drawerOpacity(FridgeZoneId.freezer), 0);
      expect(find.text('变温库存'), findsOneWidget);

      await tester.tap(find.text('冷冻'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(drawerOpacity(FridgeZoneId.freezer), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('冷冻库存'), findsOneWidget);
      expect(drawerOpacity(FridgeZoneId.freezer), 1);
      expect(drawerOpacity(FridgeZoneId.variable), 0);
    },
  );

  testWidgets('desktop home shows the 3D stage and status panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: FridgeHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('冷藏库存'), findsOneWidget);
    expect(find.byKey(const ValueKey('webgl-fridge-fallback')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real session renders backend foods instead of demo data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RealSessionStore()),
          familyDataSourceProvider.overrideWithValue(
            _FridgeFixtureFamilySource(),
          ),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeFixtureSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(_RemoteFridgeSource()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: FridgeHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试牛奶'), findsOneWidget);
    expect(find.text('番茄'), findsNothing);
    expect(find.textContaining('小满的家'), findsAtLeastNWidgets(1));
  });

  testWidgets('editor saves a real food from the add sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RealSessionStore()),
          familyDataSourceProvider.overrideWithValue(
            _FridgeFixtureFamilySource(),
          ),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeFixtureSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: FridgeHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('添加食材'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('添加食材'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('ingredient-picker-search')),
      '西兰花',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ingredient-西兰花')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('增加西兰花份量'));
    await tester.tap(find.byKey(const ValueKey('save-catalog-foods')));
    await tester.pumpAndSettle();

    final added = source.catalogSelections.single.single;
    expect(added.sticker.name, '西兰花');
    expect(added.portions, 2);
    expect(added.sticker.category, '蔬菜');
  });

  testWidgets('editor consumes food with its current version', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RealSessionStore()),
          familyDataSourceProvider.overrideWithValue(
            _FridgeFixtureFamilySource(),
          ),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeFixtureSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: FridgeHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('测试牛奶').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('测试牛奶').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consume-food-button')));
    await tester.pumpAndSettle();

    expect(source.consumedFood?.serverId, 31);
    expect(source.consumedQuantity, 1);
  });

  testWidgets('editor moves food to another real zone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RealSessionStore()),
          familyDataSourceProvider.overrideWithValue(
            _FridgeFixtureFamilySource(),
          ),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeFixtureSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: FridgeHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('测试牛奶').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('测试牛奶').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-food-button')));
    await tester.pumpAndSettle();

    expect(source.movedFood?.serverId, 31);
    expect(source.movedZone?.serverId, 12);
  });

  testWidgets('editor discards food through the details sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_RealSessionStore()),
          familyDataSourceProvider.overrideWithValue(
            _FridgeFixtureFamilySource(),
          ),
          familySelectionStoreProvider.overrideWithValue(
            _FridgeFixtureSelectionStore(),
          ),
          fridgeDataSourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: FridgeHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('测试牛奶').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('测试牛奶').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discard-food-button')));
    await tester.pumpAndSettle();

    expect(source.discardedFood, isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.discardedFood, isNull);
    await tester.tap(find.byKey(const ValueKey('discard-food-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认丢弃'));
    await tester.pumpAndSettle();

    expect(source.discardedFood?.serverId, 31);
  });
}

Widget _realApp(
  _RemoteFridgeSource source, {
  RecipeDataSource? recipes,
  String role = 'OWNER',
}) => ProviderScope(
  overrides: [
    sessionStoreProvider.overrideWithValue(_RealSessionStore()),
    familyDataSourceProvider.overrideWithValue(
      _FridgeFixtureFamilySource(role: role),
    ),
    familySelectionStoreProvider.overrideWithValue(
      _FridgeFixtureSelectionStore(),
    ),
    fridgeDataSourceProvider.overrideWithValue(source),
    foodSearchProvider.overrideWith((ref, request) async {
      final workspace = await ref.watch(fridgeWorkspaceProvider.future);
      final query = request.filter.query.trim();
      return (source.foodsOverride ?? workspace.foods)
          .where((food) => food.name.contains(query))
          .toList();
    }),
    if (recipes != null) recipeDataSourceProvider.overrideWithValue(recipes),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: FridgeHomePage()),
  ),
);

List<FridgeFood> _tomatoEggStock(String tomatoName) => [
  for (final (index, name) in [tomatoName, '鸡蛋', '食用油', '食盐'].indexed)
    FridgeFood(
      id: '${index + 100}',
      serverId: index + 100,
      name: name,
      emoji: '',
      quantity: 1,
      unit: '份',
      expiresInDays: 4,
      zone: FridgeZoneId.fresh,
      category: '其他',
      owner: '',
      tilt: 0,
    ),
];

class _HomeRecipeSource implements RecipeDataSource {
  @override
  Future<List<Recipe>> load(AuthSession session) async => homeRecipes;
}

class _FakeSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => AuthSession.demo();

  @override
  Future<void> write(AuthSession session) async {}
}

class _RealSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc(),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {}
}

class _RemoteFridgeSource implements FridgeDataSource {
  @override
  Future<void> createFridge(
    AuthSession session,
    int familyId,
    String name,
  ) async {}

  final catalogSelections = <List<CatalogFoodInput>>[];
  final catalogRequests = <String>[];
  bool loseCatalogResponse = false;
  final cookRequests = <String>[];
  final cookItems = <List<CookItemInput>>[];
  bool loseCookResponse = false;
  List<FridgeFood>? foodsOverride;
  FridgeFood? consumedFood;
  double? consumedQuantity;
  FridgeFood? movedFood;
  FridgeZone? movedZone;
  FridgeFood? discardedFood;

  static const workspace = FridgeWorkspaceData(
    familyId: 4,
    familyName: '小满的家',
    role: 'OWNER',
    fridgeId: 1,
    fridgeName: '厨房冰箱',
    timezone: 'Asia/Shanghai',
    zones: [
      FridgeZone(
        id: FridgeZoneId.fresh,
        serverId: 11,
        name: '冷藏',
        description: '蔬果 · 饮品 · 熟食',
        temperature: '4°C',
        emoji: '🥬',
        containers: [FridgeContainer(id: 21, name: '上层隔层', type: 'SHELF')],
      ),
      FridgeZone(
        id: FridgeZoneId.variable,
        serverId: 12,
        name: '变温',
        description: '鲜肉 · 海鲜',
        temperature: '0°C',
        emoji: '🥩',
        containers: [FridgeContainer(id: 22, name: '变温抽屉', type: 'DRAWER')],
      ),
      FridgeZone(
        id: FridgeZoneId.freezer,
        serverId: 13,
        name: '冷冻',
        description: '速冻',
        temperature: '-18°C',
        emoji: '',
      ),
    ],
    foods: [
      FridgeFood(
        id: '31',
        serverId: 31,
        containerId: 21,
        name: '测试牛奶',
        emoji: '🥛',
        quantity: 2,
        unit: '盒',
        expiresInDays: 2,
        zone: FridgeZoneId.fresh,
        category: '蛋奶',
        owner: '小满',
        tilt: 0,
      ),
    ],
  );

  @override
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async {
    final foods = foodsOverride;
    return foods == null
        ? workspace
        : FridgeWorkspaceData(
            familyId: workspace.familyId,
            familyName: workspace.familyName,
            role: workspace.role,
            fridgeId: workspace.fridgeId,
            fridgeName: workspace.fridgeName,
            timezone: workspace.timezone,
            zones: workspace.zones,
            foods: foods,
          );
  }

  @override
  Future<void> addFood(
    AuthSession session,
    FridgeWorkspaceData workspace,
    NewFoodInput input,
  ) async {}

  @override
  Future<void> addCatalogFoods(
    AuthSession session,
    FridgeWorkspaceData workspace,
    List<CatalogFoodInput> items,
    String requestId,
  ) async {
    catalogSelections.add(items);
    catalogRequests.add(requestId);
    if (loseCatalogResponse) {
      loseCatalogResponse = false;
      throw const ApiFailure('网络请求失败');
    }
  }

  @override
  Future<void> consume(
    AuthSession session,
    FridgeFood food,
    double quantity,
  ) async {
    consumedFood = food;
    consumedQuantity = quantity;
  }

  @override
  Future<void> discardFood(AuthSession session, FridgeFood food) async {
    discardedFood = food;
  }

  @override
  Future<void> moveFood(
    AuthSession session,
    FridgeFood food,
    FridgeZone targetZone,
  ) async {
    movedFood = food;
    movedZone = targetZone;
  }

  @override
  Future<List<FoodOperation>> loadOperations(
    AuthSession session,
    int fridgeId, {
    int limit = 30,
  }) async => const <FoodOperation>[];

  @override
  Future<void> undoOperation(
    AuthSession session,
    FoodOperation operation,
  ) async {}

  @override
  Future<void> restoreOperation(
    AuthSession session,
    FoodOperation operation,
  ) async {}

  @override
  Future<void> updateFood(AuthSession session, FoodEditInput input) async {}

  @override
  Future<int> discardExpired(AuthSession session, int fridgeId) async => 0;

  @override
  Future<void> cook(
    AuthSession session, {
    required int fridgeId,
    required int recipeId,
    required String recipeName,
    required int servings,
    required List<CookItemInput> items,
    required String requestId,
  }) async {
    cookRequests.add(requestId);
    cookItems.add(items);
    if (loseCookResponse) {
      loseCookResponse = false;
      throw const ApiFailure('网络请求失败');
    }
    foodsOverride = const [];
  }
}

class _FridgeFixtureFamilySource implements FamilyDataSource {
  _FridgeFixtureFamilySource({this.role = 'OWNER', this.empty = false});
  final String role;
  final bool empty;
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => empty
      ? []
      : [
          FamilyInfo(
            id: 4,
            name: '小满的家',
            inviteCode: 'TEST2026',
            ownerUserId: 7,
            role: role,
          ),
        ];

  @override
  Future<FamilyInfo> create(AuthSession session, String name) {
    throw UnimplementedError();
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async => const [];

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {}

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) {
    throw UnimplementedError();
  }
}

Widget _setupApp(
  _SetupFridgeSource source, {
  String role = 'OWNER',
  bool empty = false,
}) => ProviderScope(
  overrides: [
    sessionStoreProvider.overrideWithValue(_RealSessionStore()),
    familyDataSourceProvider.overrideWithValue(
      _FridgeFixtureFamilySource(role: role, empty: empty),
    ),
    familySelectionStoreProvider.overrideWithValue(
      _FridgeFixtureSelectionStore(),
    ),
    fridgeDataSourceProvider.overrideWithValue(source),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: FridgeHomePage()),
  ),
);

class _SetupFridgeSource extends _RemoteFridgeSource {
  Completer<void>? gate;
  int createCount = 0;
  bool created = false;
  bool reject = false;
  int? createdFamilyId;
  String? createdName;

  @override
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async =>
      created
      ? _RemoteFridgeSource.workspace
      : FridgeWorkspaceData.empty(familyId);

  @override
  Future<void> createFridge(
    AuthSession session,
    int familyId,
    String name,
  ) async {
    createCount++;
    await gate?.future;
    createdFamilyId = familyId;
    createdName = name;
    if (reject) throw const ApiFailure('服务暂不可用', statusCode: 503);
    created = true;
  }
}

class _FridgeFixtureSelectionStore implements FamilySelectionStore {
  @override
  Future<int?> read(int userId) async => 4;

  @override
  Future<void> write(int userId, int familyId) async {}

  @override
  Future<void> clear(int userId) async {}
}

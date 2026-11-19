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
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/fridge_home_page.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/webgl_fridge_view.dart';

void main() {
  testWidgets(
    'changing only the selected category protects the unsaved draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _RemoteFridgeSource();
      await tester.pumpWidget(_realApp(source));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增食材'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('food-category-input'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      for (final category in ['肉类', '奶制品', '蔬菜', '水果', '调味品']) {
        expect(find.text(category), findsWidgets);
      }
      await tester.tap(find.text('奶制品').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('关闭新增'));
      await tester.tap(find.byTooltip('关闭新增'));
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的内容？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.text('奶制品'), findsOneWidget);
      expect(source.addedFood, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'focusing an unchanged food field does not create a dirty draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_realApp(_RemoteFridgeSource()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增食材'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('food-name-input')));
      await tester.pump();
      await tester.tap(find.byTooltip('关闭新增'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('food-name-input')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsaved food can be kept or explicitly discarded on close', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource();
    await tester.pumpWidget(_realApp(source));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增食材'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('food-name-input')),
      '未保存的牛奶',
    );
    await tester.tap(find.byTooltip('关闭新增'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的内容？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('未保存的牛奶'), findsOneWidget);
    expect(source.addedFood, isNull);
    await tester.tap(find.byTooltip('关闭新增'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃填写'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('food-name-input')), findsNothing);
    expect(source.addedFood, isNull);
    expect(tester.takeException(), isNull);
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
    await tester.ensureVisible(find.text('新增食材'));
    await tester.tap(find.text('新增食材'));
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

  testWidgets('add form rejects nonfinite and excessive precision quantities', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _RemoteFridgeSource();
    await tester.pumpWidget(_realApp(source));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('新增食材'));
    await tester.tap(find.text('新增食材'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('food-name-input')),
      '测试食材',
    );
    for (final value in ['NaN', 'Infinity', '1.2345', '1000000000', '0.0001']) {
      await tester.enterText(
        find.byKey(const ValueKey('food-quantity-input')),
        value,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-food-button')),
      );
      await tester.tap(find.byKey(const ValueKey('save-food-button')));
      await tester.pumpAndSettle();
      expect(source.addedFood, isNull);
      expect(find.textContaining('数量至少 0.001'), findsOneWidget);
    }
    await tester.enterText(
      find.byKey(const ValueKey('food-quantity-input')),
      '0.001',
    );
    await tester.tap(find.byKey(const ValueKey('save-food-button')));
    await tester.pumpAndSettle();
    expect(source.addedFood?.quantity, 0.001);
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
      expect(find.text('番茄'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('fridge-zone-selector')),
        const Offset(-130, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('常温'), findsOneWidget);

      await tester.tap(find.text('冷冻'));
      await tester.pumpAndSettle();

      expect(find.text('冷冻 -18°C'), findsOneWidget);
      expect(find.text('拖动查看 · 点击门或抽屉开合'), findsOneWidget);
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

    expect(find.text('库存概览'), findsOneWidget);
    expect(find.text('拖动查看 · 点击门或抽屉开合'), findsOneWidget);
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
      find.text('新增食材'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('新增食材'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('food-name-input')),
      '西兰花',
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-quantity-input')),
      '2',
    );
    await tester.enterText(find.byKey(const ValueKey('food-unit-input')), '颗');
    final categoryField = find.byKey(const ValueKey('food-category-input'));
    expect(
      tester.widget(categoryField),
      isA<DropdownButtonFormField<String>>(),
    );
    expect(
      find.descendant(of: categoryField, matching: find.byType(TextField)),
      findsNothing,
    );
    await tester.ensureVisible(categoryField);
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('蔬菜').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('save-food-button')));
    await tester.tap(find.byKey(const ValueKey('save-food-button')));
    await tester.pumpAndSettle();

    expect(source.addedFood?.name, '西兰花');
    expect(source.addedFood?.quantity, 2);
    expect(source.addedFood?.category, '蔬菜');
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

Widget _realApp(_RemoteFridgeSource source) => ProviderScope(
  overrides: [
    sessionStoreProvider.overrideWithValue(_RealSessionStore()),
    familyDataSourceProvider.overrideWithValue(_FridgeFixtureFamilySource()),
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

  NewFoodInput? addedFood;
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
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async =>
      workspace;

  @override
  Future<void> addFood(
    AuthSession session,
    FridgeWorkspaceData workspace,
    NewFoodInput input,
  ) async {
    addedFood = input;
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
  }) async {}
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

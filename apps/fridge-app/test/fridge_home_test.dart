import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/fridge_home_page.dart';

void main() {
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
      expect(find.text('点击模型可开门'), findsOneWidget);
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

    expect(find.text('冰箱状态'), findsOneWidget);
    expect(find.text('WEBGL 真 3D'), findsOneWidget);
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
      find.text('放进一份新食材'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('放进一份新食材'));
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
    await tester.enterText(
      find.byKey(const ValueKey('food-category-input')),
      '蔬菜',
    );
    await tester.tap(find.byKey(const ValueKey('save-food-button')));
    await tester.pumpAndSettle();

    expect(source.addedFood?.name, '西兰花');
    expect(source.addedFood?.quantity, 2);
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

    expect(source.discardedFood?.serverId, 31);
  });
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
}

class _FridgeFixtureFamilySource implements FamilyDataSource {
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => const [
    FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
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

class _FridgeFixtureSelectionStore implements FamilySelectionStore {
  @override
  Future<int?> read(int userId) async => 4;

  @override
  Future<void> write(int userId, int familyId) async {}

  @override
  Future<void> clear(int userId) async {}
}

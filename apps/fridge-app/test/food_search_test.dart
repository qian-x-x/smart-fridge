import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/application/food_search_provider.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_filter.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_search_sheet.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_sticker_image.dart';

void main() {
  testWidgets('category, zone and expiry state update results on selection', (
    tester,
  ) async {
    final api = _Harness();
    await _openSheet(tester, api);
    expect(find.text('找到 5 份食材'), findsOneWidget);
    expect(find.text('应用筛选'), findsNothing);
    expect(find.textContaining('到期起日'), findsNothing);
    expect(find.textContaining('到期止日'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('标签'), findsNothing);

    await _select(tester, '全部分类', '蔬菜');
    expect(api.requests.last.uri.queryParameters['category'], '蔬菜');
    expect(
      api.requests.last.uri.queryParametersAll.containsKey('tags'),
      isFalse,
    );
    expect(find.text('找到 2 份食材'), findsOneWidget);
    expect(find.text('番茄'), findsOneWidget);

    await _select(tester, '全部分区', '冷冻');
    expect(api.requests.last.uri.queryParameters['zoneId'], '12');
    expect(find.text('找到 1 份食材'), findsOneWidget);
    expect(find.text('西兰花'), findsOneWidget);
    expect(find.text('番茄'), findsNothing);

    await _select(tester, '全部状态', '新鲜（超过 3 天）');
    expect(api.requests.last.uri.queryParameters['expiryState'], 'FRESH');
    expect(find.text('找到 0 份食材'), findsOneWidget);

    await tester.ensureVisible(find.text('重置'));
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    final reset = api.requests.last.uri.queryParameters;
    expect(reset['category'], isNull);
    expect(reset['zoneId'], isNull);
    expect(reset['expiryState'], 'ALL');
    expect(find.text('全部分类'), findsOneWidget);
    expect(find.text('找到 5 份食材'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset ranges update instantly and resolve sticker artwork', (
    tester,
  ) async {
    final api = _Harness();
    await _openSheet(tester, api);

    await _select(tester, '全部期限', '3日内');
    expect(find.text('找到 1 份食材'), findsOneWidget);
    expect(_sticker(tester, '查询牛奶').sticker?.name, '牛奶');
    expect(find.text('番茄'), findsNothing);

    await _select(tester, '3日内', '7日内');
    expect(find.text('找到 2 份食材'), findsOneWidget);
    expect(_sticker(tester, '番茄').sticker?.name, '西红柿');
    expect(find.text('西兰花'), findsNothing);

    await _select(tester, '7日内', '30日内');
    expect(find.text('找到 3 份食材'), findsOneWidget);
    expect(_sticker(tester, '水饺').sticker?.name, '饺子');

    await _select(tester, '30日内', '半年内');
    expect(find.text('找到 3 份食材'), findsOneWidget);
    expect(find.text('自制果酱'), findsNothing);

    await _select(tester, '半年内', '长期');
    expect(find.text('找到 1 份食材'), findsOneWidget);
    expect(_sticker(tester, '自制果酱').sticker, isNull);
    expect(api.requests, hasLength(1));

    await tester.ensureVisible(find.text('重置'));
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(find.text('全部期限'), findsOneWidget);
    expect(find.text('找到 5 份食材'), findsOneWidget);
  });

  test(
    'preset limits include today and the last day in the fridge calendar',
    () {
      final today = DateTime.utc(2026, 8, 31);
      FridgeFood expiresAfter(int days) =>
          _expiresOn(today, today.add(Duration(days: days)));
      for (final (window, limit) in [
        (FoodExpiryWindow.threeDays, 3),
        (FoodExpiryWindow.sevenDays, 7),
        (FoodExpiryWindow.thirtyDays, 30),
      ]) {
        expect(window.includes(expiresAfter(-1)), isFalse);
        expect(window.includes(expiresAfter(0)), isTrue);
        expect(window.includes(expiresAfter(limit)), isTrue);
        expect(window.includes(expiresAfter(limit + 1)), isFalse);
      }

      for (final year in [2026, 2027]) {
        final start = DateTime.utc(year, 8, 31);
        final endOfFebruary = DateTime.utc(year + 1, 3, 0);
        final cutoff = _expiresOn(start, endOfFebruary);
        final later = _expiresOn(start, DateTime.utc(year + 1, 3, 1));
        expect(FoodExpiryWindow.sixMonths.includes(cutoff), isTrue);
        expect(FoodExpiryWindow.longTerm.includes(cutoff), isFalse);
        expect(FoodExpiryWindow.sixMonths.includes(later), isFalse);
        expect(FoodExpiryWindow.longTerm.includes(later), isTrue);
      }
    },
  );

  test(
    'query uses repeated tags, authorization and separate result snapshot',
    () async {
      final api = _Harness();
      final container = _container(api);
      addTearDown(container.dispose);
      final results = await container.read(
        foodSearchProvider((
          fridgeId: 2,
          filter: const FoodFilter(
            query: ' 牛奶 ',
            category: ' 蛋奶 ',
            tags: ['早餐', '高蛋白', '早餐'],
            zoneId: 11,
            expiryState: 'EXPIRING',
            expiresFrom: '2026-10-30',
            expiresTo: '2026-11-02',
            sort: 'NAME_ASC',
          ),
        )).future,
      );
      final request = api.requests.single;
      expect(request.uri.queryParametersAll['tags'], ['早餐', '高蛋白']);
      expect(request.uri.queryParametersAll.containsKey('tags[]'), isFalse);
      expect(request.uri.queryParameters['query'], '牛奶');
      expect(request.uri.queryParameters['category'], '蛋奶');
      expect(request.uri.queryParameters['zoneId'], '11');
      expect(request.uri.queryParameters['expiresFrom'], '2026-10-30');
      expect(request.uri.queryParameters['expiresTo'], '2026-11-02');
      expect(request.uri.queryParameters['sort'], 'NAME_ASC');
      expect(request.headers['Authorization'], 'Bearer test-access');
      expect(results.single.serverId, 31);
      expect(results.single.zone, FridgeZoneId.fresh);
      expect(
        (await container.read(fridgeWorkspaceProvider.future)).foods,
        isEmpty,
      );
    },
  );

  test('old fridge requests are rejected after a family switch', () async {
    final api = _Harness();
    final container = _container(api);
    addTearDown(container.dispose);
    await expectLater(
      container.read(
        foodSearchProvider((fridgeId: 99, filter: const FoodFilter())).future,
      ),
      throwsStateError,
    );
    expect(api.requests, isEmpty);
  });

  testWidgets(
    'mobile sheet debounces text, resets and retries failed searches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _Harness();
      await _openSheet(tester, api);
      await _select(tester, '全部状态', '临期（今天至 3 天内）');
      final nameInput = find.widgetWithText(TextField, '食材名称');
      await tester.ensureVisible(nameInput);
      await tester.enterText(nameInput, 'mis');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(nameInput, 'missing');
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.requests, hasLength(2));
      await tester.pumpAndSettle();
      expect(api.requests.last.uri.queryParameters['query'], 'missing');
      expect(find.textContaining('没有符合条件'), findsOneWidget);
      await tester.ensureVisible(find.text('重置'));
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(api.requests.last.uri.queryParameters['query'], isNull);
      expect(api.requests.last.uri.queryParameters['expiryState'], 'ALL');
      expect(find.text('查询牛奶'), findsOneWidget);
      api.fail = true;
      await _select(tester, '全部状态', '临期（今天至 3 天内）');
      expect(find.text('重试查询'), findsOneWidget);
      api.fail = false;
      await tester.ensureVisible(find.text('重试查询'));
      await tester.tap(find.text('重试查询'));
      await tester.pumpAndSettle();
      expect(find.text('查询牛奶'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending name search is cancelled when the list closes', (
    tester,
  ) async {
    final api = _Harness();
    await _openSheet(tester, api);
    await tester.enterText(find.widgetWithText(TextField, '食材名称'), '待发送');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('late old search cannot replace the newest query result', (
    tester,
  ) async {
    final api = _Harness()..slow = Completer<void>();
    await _openSheet(tester, api);
    final nameInput = find.widgetWithText(TextField, '食材名称');
    await tester.enterText(nameInput, 'slow');
    await tester.pump(const Duration(milliseconds: 250));
    // Wait for the request to start while its progress indicator is active.
    for (
      var i = 0;
      i < 10 && api.requests.last.uri.queryParameters['query'] != 'slow';
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(api.requests.last.uri.queryParameters['query'], 'slow');
    await tester.enterText(nameInput, 'missing');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('找到 0 份食材'), findsOneWidget);
    api.slow!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('没有符合条件'), findsOneWidget);
    expect(find.text('查询牛奶'), findsNothing);
  });
}

Future<void> _openSheet(WidgetTester tester, _Harness api) async {
  final container = _container(api);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: FoodSearchSheet(workspace: _workspace, onFoodTap: (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String current, String next) async {
  final field = find.text(current);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await tester.pumpAndSettle();
}

IngredientStickerImage _sticker(WidgetTester tester, String name) =>
    tester.widget<IngredientStickerImage>(
      find.descendant(
        of: find.widgetWithText(ListTile, name),
        matching: find.byType(IngredientStickerImage),
      ),
    );

FridgeFood _expiresOn(DateTime today, DateTime expiry) => FridgeFood(
  id: '1',
  name: '食材',
  emoji: '🥬',
  quantity: 1,
  unit: '份',
  expiresInDays: expiry.difference(today).inDays,
  zone: FridgeZoneId.fresh,
  category: '蔬菜',
  owner: '测试',
  tilt: 0,
  expiresOn: expiry.toIso8601String().substring(0, 10),
);

ProviderContainer _container(_Harness api) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_Auth.new),
    fridgeWorkspaceProvider.overrideWith(_Workspace.new),
    dioProvider.overrideWithValue(api.dio),
  ],
);

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async => AuthSession(
    accessToken: 'test-access',
    refreshToken: 'refresh',
    expiresIn: 1800,
    issuedAt: DateTime.now().toUtc(),
    user: const UserProfile(
      id: 7,
      username: 'test',
      displayName: '测试',
      role: 'USER',
    ),
  );
}

class _Workspace extends FridgeWorkspaceController {
  @override
  Future<FridgeWorkspaceData> build() async => _workspace;
}

const _workspace = FridgeWorkspaceData(
  familyId: 4,
  familyName: '测试家庭',
  role: 'VIEWER',
  fridgeId: 2,
  fridgeName: '测试冰箱',
  timezone: 'Asia/Shanghai',
  zones: [
    FridgeZone(
      id: FridgeZoneId.fresh,
      serverId: 11,
      name: '冷藏',
      description: '',
      temperature: '4°C',
      emoji: '🥬',
    ),
    FridgeZone(
      id: FridgeZoneId.freezer,
      serverId: 12,
      name: '冷冻',
      description: '',
      temperature: '-18°C',
      emoji: '🧊',
    ),
  ],
  foods: [],
);

class _Harness {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
  final requests = <RequestOptions>[];
  bool fail = false;
  Completer<void>? slow;

  static final _foods = [
    _row(31, '查询牛奶', '蛋奶', 2, modelKey: 'sticker:牛奶'),
    _row(32, '番茄', '蔬菜', 7),
    _row(33, '西兰花', '蔬菜', -1, zone: 12),
    _row(34, '水饺', '速冻食品', 30, zone: 12),
    _row(35, '自制果酱', '其他', 183),
  ];

  static Map<String, dynamic> _row(
    int id,
    String name,
    String category,
    int days, {
    int zone = 11,
    String? modelKey,
  }) => {
    'id': id,
    'fridgeId': 2,
    'zoneId': zone,
    'name': name,
    'category': category,
    'quantity': 2,
    'unit': '份',
    'productionDate': '2026-10-29',
    'expiresOn': DateTime.utc(
      2026,
      10,
      30 + days,
    ).toIso8601String().substring(0, 10),
    'remainingDays': days,
    'tags': ['早餐', '高蛋白'],
    'createdBy': 7,
    'modelKey': modelKey,
    'version': 0,
  };

  _Harness() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          final filters = options.queryParameters;
          final query = filters['query'] as String?;
          if (query == 'slow') await slow?.future;
          if (fail) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'code': 'OK',
                'data': _foods.where((food) {
                  final days = food['remainingDays'] as int;
                  return (query == null ||
                          query == 'slow' ||
                          (food['name'] as String).contains(query)) &&
                      (filters['category'] == null ||
                          filters['category'] == food['category']) &&
                      (filters['zoneId'] == null ||
                          filters['zoneId'] == food['zoneId']) &&
                      (switch (filters['expiryState']) {
                        'FRESH' => days > 3,
                        'EXPIRING' => days >= 0 && days <= 3,
                        'EXPIRED' => days < 0,
                        _ => true,
                      });
                }).toList(),
              },
            ),
          );
        },
      ),
    );
  }
}

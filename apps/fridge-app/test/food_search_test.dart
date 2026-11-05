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

void main() {
  testWidgets('category selection is sent to the API and reset clears it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Harness();
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
    final category = find.byKey(const ValueKey('search-category-'));
    expect(
      find.descendant(of: category, matching: find.byType(TextField)),
      findsNothing,
    );
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('奶制品').last);
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(api.requests.last.uri.queryParameters['category'], '奶制品');
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(
      api.requests.last.uri.queryParameters.containsKey('category'),
      isFalse,
    );
    expect(find.byKey(const ValueKey('search-category-')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('mobile sheet filters, resets and keeps query errors retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Harness();
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
    await tester.ensureVisible(find.text('全部状态'));
    await tester.tap(find.text('全部状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('临期（今天至 3 天内）').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, '食材名称'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '食材名称'),
      'missing',
    );
    await _apply(tester);
    expect(find.textContaining('没有符合条件'), findsOneWidget);
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(api.requests.last.uri.queryParameters['query'], isNull);
    expect(api.requests.last.uri.queryParameters['expiryState'], 'ALL');
    expect(find.text('查询牛奶'), findsOneWidget);
    api.fail = true;
    await _apply(tester);
    expect(find.text('重试查询'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('重试查询'));
    await tester.pumpAndSettle();
    expect(find.text('查询牛奶'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid date ranges do not send search requests', (
    tester,
  ) async {
    final api = _Harness();
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
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, '到期起日 YYYY-MM-DD'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '到期起日 YYYY-MM-DD'),
      '2026-02-30',
    );
    await _apply(tester);
    expect(api.requests.length, 1);
    expect(find.text('请输入有效日期 YYYY-MM-DD'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '到期起日 YYYY-MM-DD'),
      '2026-11-02',
    );
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, '到期止日 YYYY-MM-DD'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '到期止日 YYYY-MM-DD'),
      '2026-11-01',
    );
    await _apply(tester);
    expect(api.requests.length, 1);
    expect(find.text('止日不能早于起日'), findsOneWidget);
  });

  testWidgets('late old search cannot replace the newest query result', (
    tester,
  ) async {
    final api = _Harness()..slow = Completer<void>();
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
    await tester.enterText(find.widgetWithText(TextFormField, '食材名称'), 'slow');
    await _apply(tester, settleResponse: false);
    for (
      var attempt = 0;
      attempt < 20 &&
          !api.requests.any(
            (request) => request.uri.queryParameters['query'] == 'slow',
          );
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(api.requests.last.uri.queryParameters['query'], 'slow');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, '食材名称'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '食材名称'),
      'missing',
    );
    await _apply(tester);
    api.slow!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('没有符合条件'), findsOneWidget);
    expect(find.text('查询牛奶'), findsNothing);
  });
}

Future<void> _apply(WidgetTester tester, {bool settleResponse = true}) async {
  // Scroll until the action is actually clickable, rather than merely built in
  // a lazy viewport. Do not settle an unrelated pending query's progress ticker.
  for (var attempt = 0;
      attempt < 20 && find.text('应用筛选').hitTestable().evaluate().isEmpty;
      attempt++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(find.text('应用筛选').hitTestable(), findsOneWidget);
  await tester.tap(find.text('应用筛选'));
  if (settleResponse) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

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
  ],
  foods: [],
);

class _Harness {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
  final requests = <RequestOptions>[];
  bool fail = false;
  Completer<void>? slow;
  _Harness() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          if (options.queryParameters['query'] == 'slow') await slow?.future;
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
                'data': options.queryParameters['query'] == 'missing'
                    ? []
                    : [
                        {
                          'id': 31,
                          'fridgeId': 2,
                          'zoneId': 11,
                          'name': '查询牛奶',
                          'category': '蛋奶',
                          'quantity': 2,
                          'unit': '盒',
                          'productionDate': '2026-10-29',
                          'expiresOn': '2026-11-01',
                          'remainingDays': 2,
                          'tags': ['早餐', '高蛋白'],
                          'createdBy': 7,
                          'version': 0,
                        },
                      ],
              },
            ),
          );
        },
      ),
    );
  }
}

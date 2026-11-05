import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_operation.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';

void main() {
  const session = AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresIn: 900,
    user: UserProfile(
      id: 7,
      displayName: '小满',
      username: 'manman',
      role: 'USER',
    ),
  );

  test(
    'loads the selected family fridge and foods through the gateway',
    () async {
      final api = _FakeApiClient();
      final repository = ApiFridgeRepository(api);

      final workspace = await repository.load(session, 4);

      expect(workspace.familyId, 4);
      expect(workspace.fridgeId, 1);
      expect(workspace.foods.single.name, '测试牛奶');
      expect(api.getCalls.map((call) => call.$1), [
        '/api/v1/fridges',
        '/api/v1/foods',
      ]);
      expect(api.getCalls[0].$2?['familyId'], 4);
      expect(api.tokens, everyElement('access-token'));
    },
  );

  test('consume sends the food version and quantity', () async {
    final api = _FakeApiClient();
    final repository = ApiFridgeRepository(api);
    const food = FridgeFood(
      id: '31',
      serverId: 31,
      name: '测试牛奶',
      emoji: '🥛',
      quantity: 2,
      unit: '盒',
      expiresInDays: 5,
      zone: FridgeZoneId.fresh,
      category: '蛋奶',
      owner: '小满',
      tilt: 0,
      version: 3,
    );

    await repository.consume(session, food, 0.5);

    expect(api.postCalls.single.$1, '/api/v1/foods/31/consume');
    expect(api.postCalls.single.$2, {'quantity': 0.5, 'version': 3});
    expect(api.postCalls.single.$3, 'access-token');
  });

  test(
    'missing fridge is an empty workspace; other errors remain errors',
    () async {
      final api = _FakeApiClient()
        ..fridgeFailure = const ApiFailure('尚未创建', statusCode: 404);
      final repository = ApiFridgeRepository(api);
      final workspace = await repository.load(session, 4);
      expect(workspace.hasFridge, isFalse);
      expect(workspace.canEdit, isFalse);
      expect(api.getCalls.length, 1);
      api.fridgeFailure = const ApiFailure('无权访问', statusCode: 403);
      await expectLater(
        repository.load(session, 4),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test('create fridge sends selected family, trimmed name and token', () async {
    final api = _FakeApiClient();
    await ApiFridgeRepository(api).createFridge(session, 4, ' 厨房冰箱 ');
    expect(api.postCalls.single.$1, '/api/v1/fridges');
    expect(api.postCalls.single.$2, {'familyId': 4, 'name': '厨房冰箱'});
    expect(api.postCalls.single.$3, 'access-token');
  });

  test('loads the timeline with a bounded limit and maps undo state', () async {
    final api = _FakeApiClient();
    final operations = await ApiFridgeRepository(
      api,
    ).loadOperations(session, 1, limit: 30);

    expect(operations, hasLength(2));
    expect(operations.first.foodName, '测试牛奶');
    expect(operations.first.action, 'CONSUME');
    expect(operations.first.oldQuantity, 4);
    expect(operations.first.newQuantity, 2);
    expect(operations.first.canUndo, isTrue);
    expect(operations.first.canRestore, isFalse);
    expect(operations.first.summary, '使用 4 → 2');
    expect(operations.last.action, 'ADD');
    expect(operations.last.canUndo, isFalse);

    final undone = await ApiFridgeRepository(
      api,
    ).loadOperations(session, 1);
    expect(undone, isNotEmpty);
    expect(api.getCalls.last.$1, '/api/v1/fridges/1/operations');
    expect(api.getCalls.last.$2?['limit'], 30);
  });

  test('undo and restore post to the operation endpoints', () async {
    final api = _FakeApiClient();
    final repository = ApiFridgeRepository(api);
    const operation = FoodOperation(
      id: 101,
      foodItemId: 31,
      foodName: '测试牛奶',
      action: 'CONSUME',
      oldQuantity: 4,
      newQuantity: 2,
      note: null,
      originalOperationId: null,
      undone: false,
      undoable: true,
      createdAt: null,
    );

    await repository.undoOperation(session, operation);
    await repository.restoreOperation(session, operation);

    expect(api.postCalls[0].$1, '/api/v1/foods/31/operations/101/undo');
    expect(api.postCalls[1].$1, '/api/v1/foods/31/operations/101/restore');
    expect(api.postCalls[0].$3, 'access-token');
  });

  test('cook sends the recipe, servings and versioned items', () async {
    final api = _FakeApiClient();

    await ApiFridgeRepository(api).cook(
      session,
      fridgeId: 1,
      recipeId: 1,
      recipeName: '番茄滑蛋',
      servings: 2,
      items: const [
        CookItemInput(foodItemId: 31, quantity: 1.5, version: 3),
        CookItemInput(foodItemId: 32, quantity: 2, version: 0),
      ],
      requestId: 'cook-12345678',
    );

    expect(api.postCalls.single.$1, '/api/v1/fridges/1/cook-records');
    expect(api.postCalls.single.$2, {
      'recipeId': 1,
      'recipeName': '番茄滑蛋',
      'servings': 2,
      'requestId': 'cook-12345678',
      'items': [
        {'foodItemId': 31, 'quantity': 1.5, 'version': 3},
        {'foodItemId': 32, 'quantity': 2, 'version': 0},
      ],
    });
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  final List<(String, Map<String, dynamic>?, String?)> getCalls = [];
  final List<(String, Map<String, dynamic>, String?)> postCalls = [];
  final List<String?> tokens = [];
  ApiFailure? fridgeFailure;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    getCalls.add((path, queryParameters, accessToken));
    tokens.add(accessToken);
    if (path == '/api/v1/fridges' && fridgeFailure != null) {
      throw fridgeFailure!;
    }
    return switch (path) {
      '/api/v1/fridges' => _envelope({
        'id': 1,
        'familyId': 4,
        'name': '厨房冰箱',
        'timezone': 'Asia/Shanghai',
        'zones': [
          {
            'id': 11,
            'code': 'FRESH',
            'name': '冷藏',
            'temperatureC': 4,
            'sortOrder': 10,
            'containers': [
              {'id': 21, 'name': '上层隔层', 'type': 'SHELF', 'sortOrder': 10},
            ],
          },
        ],
      }),
      '/api/v1/fridges/1/operations' => _envelope([
        {
          'id': 101,
          'fridgeId': 1,
          'foodItemId': 31,
          'foodName': '测试牛奶',
          'actorUserId': 7,
          'action': 'CONSUME',
          'oldQuantity': 4,
          'newQuantity': 2,
          'undone': false,
          'undoable': true,
          'createdAt': '2026-11-05T10:00:00Z',
        },
        {
          'id': 100,
          'fridgeId': 1,
          'foodItemId': 31,
          'foodName': '测试牛奶',
          'actorUserId': 7,
          'action': 'ADD',
          'oldQuantity': null,
          'newQuantity': 4,
          'undone': false,
          'undoable': false,
          'createdAt': '2026-11-05T09:00:00Z',
        },
      ]),
      '/api/v1/foods' => _envelope([
        {
          'id': 31,
          'fridgeId': 1,
          'zoneId': 11,
          'containerId': 21,
          'name': '测试牛奶',
          'category': '蛋奶',
          'quantity': 2,
          'unit': '盒',
          'productionDate': '2026-10-27',
          'expiresOn': '2026-11-02',
          'remainingDays': 5,
          'expiring': false,
          'tags': ['早餐'],
          'modelKey': 'milk',
          'createdBy': 7,
          'updatedBy': 7,
          'version': 0,
        },
      ]),
      _ => throw StateError('Unexpected GET $path'),
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    postCalls.add((path, body, accessToken));
    return _envelope({'id': 31, 'quantity': 1.5, 'version': 4});
  }

  Map<String, dynamic> _envelope(Object? data) {
    return {
      'code': 'OK',
      'message': 'success',
      'data': data,
      'traceId': 'test',
    };
  }
}

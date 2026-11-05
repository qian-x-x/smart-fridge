import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_timeline_sheet.dart';

void main() {
  testWidgets('timeline lists operations and only offers valid actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _TimelineHarness();
    final container = _container(harness);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('操作记录'), findsOneWidget);
    expect(find.text('测试牛奶'), findsWidgets);
    expect(find.text('使用 4 → 2'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);
    expect(find.text('恢复'), findsNothing);
    // The ADD record is not revertible and must not expose a button.
    expect(find.text('新增'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo posts to the operation endpoint and refreshes the list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _TimelineHarness();
    final container = _container(harness);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(harness.undoPaths, ['/api/v1/foods/31/operations/101/undo']);
    expect(harness.getCount, 2);
    expect(find.text('恢复'), findsOneWidget);
    expect(find.text('撤销'), findsNothing);
    expect(find.textContaining('已撤销'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected undo keeps the list and reports the failure', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _TimelineHarness()..failUndo = true;
    final container = _container(harness);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(find.textContaining('操作失败'), findsOneWidget);
    expect(find.text('测试牛奶'), findsWidgets);
    expect(harness.getCount, 1);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: FoodTimelineSheet(workspace: _workspace),
    ),
  ),
);

ProviderContainer _container(_TimelineHarness harness) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_Auth.new),
    fridgeWorkspaceProvider.overrideWith(_Workspace.new),
    dioProvider.overrideWithValue(harness.dio),
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
  role: 'OWNER',
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

class _TimelineHarness {
  _TimelineHarness() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST') {
            if (failUndo) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 409,
                    data: {
                      'code': 'CONFLICT',
                      'message': '该操作已撤销',
                    },
                  ),
                ),
              );
              return;
            }
            undoPaths.add(options.path);
            undone = true;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'code': 'OK',
                  'data': {'id': 31, 'quantity': 4, 'version': 2},
                },
              ),
            );
            return;
          }
          getCount += 1;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'code': 'OK', 'data': _operations()},
            ),
          );
        },
      ),
    );
  }

  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
  final undoPaths = <String>[];
  var getCount = 0;
  var undone = false;
  var failUndo = false;

  List<Map<String, dynamic>> _operations() => [
    {
      'id': 101,
      'fridgeId': 2,
      'foodItemId': 31,
      'foodName': '测试牛奶',
      'actorUserId': 7,
      'action': 'CONSUME',
      'oldQuantity': 4,
      'newQuantity': 2,
      'undone': undone,
      'undoable': !undone,
      'revertedByOperationId': undone ? 102 : null,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    },
    {
      'id': 100,
      'fridgeId': 2,
      'foodItemId': 31,
      'foodName': '测试牛奶',
      'actorUserId': 7,
      'action': 'ADD',
      'oldQuantity': null,
      'newQuantity': 4,
      'undone': false,
      'undoable': false,
      'createdAt': DateTime.now().subtract(
        const Duration(hours: 2),
      ).toUtc().toIso8601String(),
    },
  ];
}

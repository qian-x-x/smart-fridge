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
import 'package:smart_fridge_app/features/fridge/presentation/widgets/cook_confirm_sheet.dart';

void main() {
  testWidgets('confirming a cooking session posts one versioned batch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _CookHarness();
    final container = _container(harness);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('做「番茄滑蛋」'), findsOneWidget);
    await tester.tap(find.text('确认做饭并扣减'));
    await tester.pumpAndSettle();

    expect(harness.requests.single.path, '/api/v1/fridges/2/cook-records');
    final body = harness.requests.single.data as Map<String, dynamic>;
    expect(body['recipeId'], 1);
    expect(body['recipeName'], '番茄滑蛋');
    expect(body['servings'], 2);
    expect(
      body['requestId'],
      matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')),
    );
    final items = body['items'] as List<dynamic>;
    expect(items.single, {'foodItemId': 31, 'quantity': 1.0, 'version': 3});
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected batch keeps the sheet open with the reason', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _CookHarness()..fail = true;
    final container = _container(harness);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认做饭并扣减'));
    await tester.pumpAndSettle();

    expect(find.textContaining('扣减失败'), findsOneWidget);
    expect(find.text('做「番茄滑蛋」'), findsOneWidget);
    expect(harness.requests.single.path, '/api/v1/fridges/2/cook-records');
    expect(tester.takeException(), isNull);
  });
}

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => const CookConfirmSheet(
                fridgeId: 2,
                canEdit: true,
                recipeId: 1,
                recipeName: '番茄滑蛋',
                servings: 2,
                candidates: [
                  FridgeFood(
                    id: '31',
                    serverId: 31,
                    name: '番茄',
                    emoji: '🍅',
                    quantity: 4,
                    unit: '个',
                    expiresInDays: 3,
                    zone: FridgeZoneId.fresh,
                    category: '蔬菜',
                    owner: '测试',
                    tilt: 0,
                    version: 3,
                  ),
                ],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

ProviderContainer _container(_CookHarness harness) => ProviderContainer(
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

class _CookHarness {
  _CookHarness() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (fail) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {'code': 'CONFLICT', 'message': '库存不足'},
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'code': 'OK',
                'data': {'id': 9, 'recipeName': '番茄滑蛋'},
              },
            ),
          );
        },
      ),
    );
  }

  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
  final requests = <RequestOptions>[];
  var fail = false;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_filter.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

typedef FoodSearchRequest = ({int fridgeId, FoodFilter filter});

final foodSearchProvider = FutureProvider.autoDispose
    .family<List<FridgeFood>, FoodSearchRequest>((ref, request) async {
      var session = await ref.watch(authControllerProvider.future);
      if (session == null) {
        throw StateError('当前没有登录会话');
      }
      if (session.isAccessTokenExpiring) {
        session = await ref
            .read(authControllerProvider.notifier)
            .refreshAccessToken();
      }
      final workspace = await ref.watch(fridgeWorkspaceProvider.future);
      if (workspace.fridgeId != request.fridgeId) {
        throw StateError('家庭已切换，请重新打开冰箱清单');
      }
      if (session.isDemo) {
        throw StateError('组合筛选请使用真实账号，演示清单仅供预览');
      }
      final body = await ref
          .watch(apiClientProvider)
          .get(
            '/api/v1/foods',
            queryParameters: {
              ...request.filter.toQuery(workspace.fridgeId),
              // Spring binds repeated `tags` parameters; Dio's bracket format is incompatible.
              if (request.filter.tags.isNotEmpty)
                'tags': ListParam<String>(
                  request.filter.tags.map((tag) => tag.trim()).toSet().toList(),
                  ListFormat.multi,
                ),
            },
            accessToken: session.accessToken,
          );
      final data = body['data'];
      if (data is! List) throw const ApiFailure('服务返回的数据格式不正确');
      return workspace.foodsFromApi(data, session.user);
    });

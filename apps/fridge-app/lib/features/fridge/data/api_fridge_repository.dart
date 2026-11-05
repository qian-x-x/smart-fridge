import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

final fridgeDataSourceProvider = Provider<FridgeDataSource>((ref) {
  return ApiFridgeRepository(ref.watch(apiClientProvider));
});

abstract interface class FridgeDataSource {
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId);

  Future<void> createFridge(AuthSession session, int familyId, String name);

  Future<void> addFood(
    AuthSession session,
    FridgeWorkspaceData workspace,
    NewFoodInput input,
  );

  Future<void> moveFood(
    AuthSession session,
    FridgeFood food,
    FridgeZone targetZone,
  );

  Future<void> consume(AuthSession session, FridgeFood food, double quantity);

  Future<void> discardFood(AuthSession session, FridgeFood food);
}

class NewFoodInput {
  const NewFoodInput({
    required this.zone,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.productionDate,
    required this.expiresOn,
    this.tags = const [],
    this.modelKey,
  });

  final FridgeZone zone;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final DateTime productionDate;
  final DateTime expiresOn;
  final List<String> tags;
  final String? modelKey;
}

class ApiFridgeRepository implements FridgeDataSource {
  ApiFridgeRepository(this._api);

  final ApiClient _api;

  @override
  Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async {
    if (session.isDemo) {
      return FridgeWorkspaceData.demo(session.user);
    }

    late final Map<String, dynamic> fridgeBody;
    try {
      fridgeBody = await _api.get(
        '/api/v1/fridges',
        queryParameters: {'familyId': familyId},
        accessToken: session.accessToken,
      );
    } on ApiFailure catch (error) {
      if (error.statusCode == 404) {
        return FridgeWorkspaceData.empty(familyId);
      }
      rethrow;
    }
    final fridge = _map(fridgeBody['data']);
    final fridgeId = (fridge['id'] as num).toInt();

    final foodsBody = await _api.get(
      '/api/v1/foods',
      queryParameters: {'fridgeId': fridgeId},
      accessToken: session.accessToken,
    );
    return FridgeWorkspaceData.fromApi(
      familyData: {'id': familyId, 'name': '当前家庭', 'currentUserRole': 'VIEWER'},
      fridgeData: fridge,
      foodsData: _list(foodsBody['data']),
      currentUser: session.user,
    );
  }

  @override
  Future<void> createFridge(
    AuthSession session,
    int familyId,
    String name,
  ) async {
    await _api.post('/api/v1/fridges', {
      'familyId': familyId,
      'name': name.trim(),
    }, accessToken: session.accessToken);
  }

  @override
  Future<void> addFood(
    AuthSession session,
    FridgeWorkspaceData workspace,
    NewFoodInput input,
  ) async {
    final container = input.zone.containers.firstOrNull;
    await _api.post('/api/v1/foods', {
      'fridgeId': workspace.fridgeId,
      'zoneId': input.zone.serverId,
      'containerId': container?.id,
      'name': input.name,
      'category': input.category,
      'quantity': input.quantity,
      'unit': input.unit,
      'productionDate': _date(input.productionDate),
      'expiresOn': _date(input.expiresOn),
      'tags': input.tags,
      'modelKey': input.modelKey,
    }, accessToken: session.accessToken);
  }

  @override
  Future<void> moveFood(
    AuthSession session,
    FridgeFood food,
    FridgeZone targetZone,
  ) async {
    await _api.post('/api/v1/foods/${food.serverId}/move', {
      'zoneId': targetZone.serverId,
      'containerId': targetZone.containers.firstOrNull?.id,
      'version': food.version,
    }, accessToken: session.accessToken);
  }

  @override
  Future<void> consume(
    AuthSession session,
    FridgeFood food,
    double quantity,
  ) async {
    await _api.post('/api/v1/foods/${food.serverId}/consume', {
      'quantity': quantity,
      'version': food.version,
    }, accessToken: session.accessToken);
  }

  @override
  Future<void> discardFood(AuthSession session, FridgeFood food) {
    return _api.delete(
      '/api/v1/foods/${food.serverId}',
      queryParameters: {'version': food.version},
      accessToken: session.accessToken,
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const ApiFailure('服务返回的数据格式不正确');
  }

  List<dynamic> _list(Object? value) {
    if (value is List) {
      return value;
    }
    throw const ApiFailure('服务返回的数据格式不正确');
  }

  String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

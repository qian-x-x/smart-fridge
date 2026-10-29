import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';

import 'fridge_data.dart';

export 'fridge_data.dart';

class FridgeWorkspaceData {
  FridgeWorkspaceData withFamilyIdentity({
    required int familyId,
    required String familyName,
    required String role,
  }) {
    return FridgeWorkspaceData(
      familyId: familyId,
      familyName: familyName,
      role: role,
      fridgeId: fridgeId,
      fridgeName: fridgeName,
      timezone: timezone,
      zones: zones,
      foods: foods,
    );
  }

  const FridgeWorkspaceData({
    required this.familyId,
    required this.familyName,
    required this.role,
    required this.fridgeId,
    required this.fridgeName,
    required this.timezone,
    required this.zones,
    required this.foods,
    this.isDemo = false,
  });

  final int familyId;
  final String familyName;
  final String role;
  final int fridgeId;
  final String fridgeName;
  final String timezone;
  final List<FridgeZone> zones;
  final List<FridgeFood> foods;
  final bool isDemo;

  bool get canEdit => role == 'OWNER' || role == 'EDITOR';

  factory FridgeWorkspaceData.demo(UserProfile user) {
    return FridgeWorkspaceData(
      familyId: 0,
      familyName: '小满的家',
      role: 'OWNER',
      fridgeId: 0,
      fridgeName: '我家的冰箱',
      timezone: 'Asia/Shanghai',
      zones: demoZones,
      foods: demoFoods,
      isDemo: true,
    );
  }

  factory FridgeWorkspaceData.fromApi({
    required Map<String, dynamic> familyData,
    required Map<String, dynamic> fridgeData,
    required List<dynamic> foodsData,
    required UserProfile currentUser,
  }) {
    final zones = _asList(fridgeData['zones'])
        .map((value) => _zoneFromApi(_asMap(value)))
        .toList(growable: false);
    final zoneById = {
      for (final zone in zones)
        if (zone.serverId != null) zone.serverId!: zone.id,
    };
    final foods = foodsData
        .map((value) => _foodFromApi(_asMap(value), currentUser, zoneById))
        .toList(growable: false);

    return FridgeWorkspaceData(
      familyId: (familyData['id'] as num).toInt(),
      familyName: familyData['name'] as String,
      role: familyData['currentUserRole'] as String,
      fridgeId: (fridgeData['id'] as num).toInt(),
      fridgeName: fridgeData['name'] as String,
      timezone: fridgeData['timezone'] as String? ?? 'Asia/Shanghai',
      zones: zones,
      foods: foods,
    );
  }

  static FridgeZone _zoneFromApi(Map<String, dynamic> json) {
    final id = _zoneId(json['code'] as String?);
    return FridgeZone(
      id: id,
      serverId: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: _zoneDescription(id),
      temperature: _temperatureLabel(json['temperatureC'] as num?),
      emoji: _zoneEmoji(id),
      containers: _asList(json['containers'])
          .map((value) {
            final container = _asMap(value);
            return FridgeContainer(
              id: (container['id'] as num).toInt(),
              name: container['name'] as String,
              type: container['type'] as String,
            );
          })
          .toList(growable: false),
    );
  }

  static FridgeFood _foodFromApi(
    Map<String, dynamic> json,
    UserProfile currentUser,
    Map<int, FridgeZoneId> zoneById,
  ) {
    final serverId = (json['id'] as num).toInt();
    final zoneId =
        zoneById[(json['zoneId'] as num).toInt()] ?? FridgeZoneId.fresh;
    final name = json['name'] as String;
    final category = json['category'] as String;
    final modelKey = json['modelKey'] as String?;
    final createdBy = (json['createdBy'] as num).toInt();

    return FridgeFood(
      id: serverId.toString(),
      serverId: serverId,
      containerId: (json['containerId'] as num?)?.toInt(),
      name: name,
      emoji: _foodEmoji(name: name, category: category, modelKey: modelKey),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      expiresInDays: (json['remainingDays'] as num).toInt(),
      zone: zoneId,
      category: category,
      owner: createdBy == currentUser.id
          ? currentUser.displayName
          : '成员 #$createdBy',
      tilt: ((serverId % 9) - 4) / 100,
      version: (json['version'] as num?)?.toInt() ?? 0,
      tags: _asList(json['tags']).map((value) => value.toString()).toList(),
      productionDate: json['productionDate'] as String?,
      expiresOn: json['expiresOn'] as String?,
      modelKey: modelKey,
    );
  }

  static List<dynamic> _asList(Object? value) {
    return value is List ? value : const [];
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
  }

  static FridgeZoneId _zoneId(String? code) {
    return switch (code) {
      'VARIABLE' => FridgeZoneId.variable,
      'FREEZER' => FridgeZoneId.freezer,
      'PANTRY' => FridgeZoneId.pantry,
      _ => FridgeZoneId.fresh,
    };
  }

  static String _zoneDescription(FridgeZoneId id) {
    return switch (id) {
      FridgeZoneId.fresh => '蔬果 · 饮品 · 熟食',
      FridgeZoneId.variable => '鲜肉 · 海鲜',
      FridgeZoneId.freezer => '速冻 · 备餐',
      FridgeZoneId.pantry => '调料 · 干货',
    };
  }

  static String _zoneEmoji(FridgeZoneId id) {
    return switch (id) {
      FridgeZoneId.fresh => '🥬',
      FridgeZoneId.variable => '🥩',
      FridgeZoneId.freezer => '🧊',
      FridgeZoneId.pantry => '🧺',
    };
  }

  static String _temperatureLabel(num? value) {
    if (value == null) {
      return '室温';
    }
    final formatted = value % 1 == 0
        ? value.toInt().toString()
        : value.toDouble().toStringAsFixed(1);
    return '$formatted°C';
  }

  static String _foodEmoji({
    required String name,
    required String category,
    required String? modelKey,
  }) {
    final key = '${modelKey ?? ''}$name$category'.toLowerCase();
    if (key.contains('牛奶') || key.contains('milk')) return '🥛';
    if (key.contains('鸡蛋') || key.contains('egg')) return '🥚';
    if (key.contains('番茄') || key.contains('tomato')) return '🍅';
    if (key.contains('肉') || key.contains('beef')) return '🥩';
    if (key.contains('虾') || key.contains('海鲜')) return '🍤';
    if (key.contains('水果') || key.contains('蓝莓')) return '🫐';
    if (key.contains('蔬菜')) return '🥬';
    if (key.contains('调料')) return '🍶';
    if (key.contains('主食')) return '🍚';
    return '🥣';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

void main() {
  test('keeps variable storage and maps legacy pantry food to fresh', () {
    const user = UserProfile(
      id: 7,
      displayName: '小满',
      username: 'manman',
      role: 'USER',
    );
    const food = {
      'fridgeId': 1,
      'category': '蛋奶',
      'quantity': 2.0,
      'unit': '盒',
      'productionDate': '2026-10-27',
      'expiresOn': '2026-11-02',
      'remainingDays': 5,
      'createdBy': 7,
      'version': 0,
    };

    final workspace = FridgeWorkspaceData.fromApi(
      familyData: {'id': 4, 'name': '小满的家', 'currentUserRole': 'OWNER'},
      fridgeData: {
        'id': 1,
        'familyId': 4,
        'name': '厨房冰箱',
        'timezone': 'Asia/Shanghai',
        'zones': [
          {
            'id': 11,
            'code': 'FRESH',
            'name': '冷藏',
            'temperatureC': 4.0,
            'sortOrder': 10,
            'containers': [
              {'id': 21, 'name': '上层隔层', 'type': 'SHELF', 'sortOrder': 10},
            ],
          },
          {
            'id': 12,
            'code': 'VARIABLE',
            'name': '变温',
            'temperatureC': 0,
            'containers': [
              {'id': 22, 'name': '变温抽屉', 'type': 'DRAWER'},
            ],
          },
          {'id': 13, 'code': 'FREEZER', 'name': '冷冻'},
          {'id': 14, 'code': 'PANTRY', 'name': '常温'},
        ],
      },
      foodsData: [
        {
          ...food,
          'id': 31,
          'zoneId': 11,
          'containerId': 21,
          'name': '测试牛奶',
          'modelKey': 'milk',
        },
        {...food, 'id': 32, 'zoneId': 12, 'containerId': 22, 'name': '淡奶油'},
        {...food, 'id': 33, 'zoneId': 14, 'containerId': 24, 'name': '奶粉'},
      ],
      currentUser: user,
    );

    expect(workspace.familyId, 4);
    expect(workspace.fridgeId, 1);
    expect(workspace.familyName, '小满的家');
    expect(workspace.role, 'OWNER');
    expect(workspace.canEdit, isTrue);
    expect(workspace.zones.map((zone) => zone.serverId), [11, 12, 13]);
    expect(workspace.zones.first.containers.single.id, 21);
    expect(workspace.zones[1].id, FridgeZoneId.variable);
    expect(workspace.zones[1].temperature, '0°C');
    expect(workspace.zones[1].containers.single.id, 22);
    expect(workspace.zones.last.temperature, isEmpty);
    expect(workspace.foods.first.name, '测试牛奶');
    expect(workspace.foods.first.zone, FridgeZoneId.fresh);
    expect(workspace.foods.first.version, 0);
    expect(workspace.foods.first.owner, '小满');
    expect(workspace.foods[1].zone, FridgeZoneId.variable);
    expect(workspace.foods[1].containerId, 22);
    expect(workspace.foods.last.zone, FridgeZoneId.fresh);
    expect(workspace.foods.last.containerId, isNull);
  });
}

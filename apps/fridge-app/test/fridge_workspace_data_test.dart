import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

void main() {
  test('maps backend family, fridge, zones and foods into workspace data', () {
    const user = UserProfile(
      id: 7,
      displayName: '小满',
      username: 'manman',
      role: 'USER',
    );

    final workspace = FridgeWorkspaceData.fromApi(
      familyData: {
        'id': 4,
        'name': '小满的家',
        'currentUserRole': 'OWNER',
      },
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
        ],
      },
      foodsData: [
        {
          'id': 31,
          'fridgeId': 1,
          'zoneId': 11,
          'containerId': 21,
          'name': '测试牛奶',
          'category': '蛋奶',
          'quantity': 2.0,
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
      ],
      currentUser: user,
    );

    expect(workspace.familyId, 4);
    expect(workspace.fridgeId, 1);
    expect(workspace.familyName, '小满的家');
    expect(workspace.role, 'OWNER');
    expect(workspace.canEdit, isTrue);
    expect(workspace.zones.single.serverId, 11);
    expect(workspace.zones.single.containers.single.id, 21);
    expect(workspace.foods.single.name, '测试牛奶');
    expect(workspace.foods.single.zone, FridgeZoneId.fresh);
    expect(workspace.foods.single.version, 0);
    expect(workspace.foods.single.owner, '小满');
  });
}

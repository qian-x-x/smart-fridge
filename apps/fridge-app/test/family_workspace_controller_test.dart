import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

void main() {
  test('restores a valid persisted family selection', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 5);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    final workspace = await container.read(familyControllerProvider.future);

    expect(workspace.families.length, 2);
    expect(workspace.selectedFamily?.id, 5);
    expect(workspace.selectedFamily?.name, '父母的厨房');
  });

  test('falls back to first family when persisted id is invalid', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 999);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    final workspace = await container.read(familyControllerProvider.future);

    expect(workspace.selectedFamily?.id, 4);
    expect(selection.selectedFamilyId, 4);
  });

  test('switches and persists the selected family', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 4);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    await container.read(familyControllerProvider.future);
    await container.read(familyControllerProvider.notifier).selectFamily(5);

    expect(
      container.read(familyControllerProvider).requireValue.selectedFamily?.id,
      5,
    );
    expect(selection.selectedFamilyId, 5);
  });

  test('joining a family selects and persists it', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 4);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    await container.read(familyControllerProvider.future);
    final joined = await container
        .read(familyControllerProvider.notifier)
        .join('join2026');

    expect(joined.role, 'VIEWER');
    expect(source.joinedCode, 'JOIN2026');
    expect(
      container.read(familyControllerProvider).requireValue.selectedFamily?.id,
      6,
    );
    expect(selection.selectedFamilyId, 6);
  });
}

ProviderContainer _container(
  _WorkspaceFamilySource source,
  _MemorySelectionStore selection,
) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(_WorkspaceSessionStore()),
      familyDataSourceProvider.overrideWithValue(source),
      familySelectionStoreProvider.overrideWithValue(selection),
    ],
  );
}

class _WorkspaceFamilySource implements FamilyDataSource {
  String? joinedCode;
  final List<FamilyInfo> families = [
    const FamilyInfo(
      id: 4,
      name: 'S2 接口测试家庭',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
    ),
    const FamilyInfo(
      id: 5,
      name: '父母的厨房',
      inviteCode: 'PARENT26',
      ownerUserId: 9,
      role: 'EDITOR',
    ),
  ];

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => families;

  @override
  Future<FamilyInfo> create(AuthSession session, String name) async {
    final family = FamilyInfo(
      id: 7,
      name: name,
      inviteCode: 'CREATED7',
      ownerUserId: session.user.id,
      role: 'OWNER',
    );
    families.add(family);
    return family;
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
    joinedCode = inviteCode.toUpperCase();
    const family = FamilyInfo(
      id: 6,
      name: '朋友的家',
      inviteCode: 'JOIN2026',
      ownerUserId: 11,
      role: 'VIEWER',
    );
    families.add(family);
    return family;
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async => const [];

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {}

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) {
    throw UnimplementedError();
  }
}

class _MemorySelectionStore implements FamilySelectionStore {
  _MemorySelectionStore({this.selectedFamilyId});

  int? selectedFamilyId;

  @override
  Future<int?> read(int userId) async => selectedFamilyId;

  @override
  Future<void> write(int userId, int familyId) async {
    selectedFamilyId = familyId;
  }

  @override
  Future<void> clear(int userId) async {
    selectedFamilyId = null;
  }
}

class _WorkspaceSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc(),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {}
}

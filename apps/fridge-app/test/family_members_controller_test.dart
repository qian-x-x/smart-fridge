import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_members_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

void main() {
  test('loads members for the selected family', () async {
    final source = _MemberFamilySource();
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    final members = await container.read(familyMembersProvider.future);

    expect(members.length, 2);
    expect(members.first.role, 'OWNER');
    expect(source.memberFamilyId, 4);
  });

  test('owner updates and removes ordinary members', () async {
    final source = _MemberFamilySource();
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    await container.read(familyMembersProvider.future);
    await container
        .read(familyMembersProvider.notifier)
        .updateRole(9, 'EDITOR');
    expect(source.updatedRole, 'EDITOR');
    expect(
      container.read(familyMembersProvider).requireValue.last.role,
      'EDITOR',
    );

    await container.read(familyMembersProvider.notifier).remove(9);
    expect(source.removedUserId, 9);
    expect(container.read(familyMembersProvider).requireValue.length, 1);
  });

  test('ownership transfer refreshes family and member state', () async {
    final source = _MemberFamilySource();
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    await container.read(familyMembersProvider.future);
    await container.read(familyMembersProvider.notifier).transfer(9);

    expect(source.transferredUserId, 9);
    expect(source.ownerUserId, 9);
    expect(source.currentRole, 'EDITOR');
    expect(
      container.read(familyMembersProvider).requireValue.singleWhere((member) => member.userId == 9).role,
      'OWNER',
    );
  });

  test('keeps member state when a governance request is rejected', () async {
    final source = _MemberFamilySource()..rejectMutation = true;
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    final initial = await container.read(familyMembersProvider.future);
    await expectLater(
      container.read(familyMembersProvider.notifier).updateRole(9, 'EDITOR'),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );

    expect(
      container
          .read(familyMembersProvider)
          .requireValue
          .map((member) => member.role),
      initial.map((member) => member.role),
    );
  });
}

ProviderContainer _memberContainer(_MemberFamilySource source) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(_MemberSessionStore()),
      familyDataSourceProvider.overrideWithValue(source),
      familySelectionStoreProvider.overrideWithValue(_MemberSelectionStore()),
    ],
  );
}

class _MemberFamilySource implements FamilyDataSource {
  int ownerUserId = 7;
  String currentRole = 'OWNER';
  int? memberFamilyId;
  String? updatedRole;
  int? removedUserId;
  int? transferredUserId;
  bool rejectMutation = false;
  final List<FamilyMember> members = [
    FamilyMember(
      userId: 7,
      username: 'manman',
      displayName: '小满',
      role: 'OWNER',
      joinedAt: DateTime.utc(2026, 10, 29),
      currentUser: true,
    ),
    FamilyMember(
      userId: 9,
      username: 'family_member',
      displayName: '家庭成员',
      role: 'VIEWER',
      joinedAt: DateTime.utc(2026, 10, 29),
      currentUser: false,
    ),
  ];

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async {
    return [
      FamilyInfo(
        id: 4,
        name: '小满的家',
        inviteCode: 'TEST2026',
        ownerUserId: ownerUserId,
        role: currentRole,
      ),
    ];
  }

  @override
  Future<FamilyInfo> create(AuthSession session, String name) {
    throw UnimplementedError();
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async {
    memberFamilyId = familyId;
    return List.unmodifiable(members);
  }

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) async {
    if (rejectMutation) {
      throw const ApiFailure(
        '只有家庭拥有者可以管理成员',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    }
    updatedRole = role;
    final index = members.indexWhere((member) => member.userId == userId);
    final current = members[index];
    final updated = FamilyMember(
      userId: current.userId,
      username: current.username,
      displayName: current.displayName,
      role: role,
      joinedAt: current.joinedAt,
      currentUser: current.currentUser,
    );
    members[index] = updated;
    return updated;
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {
    removedUserId = userId;
    members.removeWhere((member) => member.userId == userId);
  }

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) async {
    transferredUserId = targetUserId;
    ownerUserId = targetUserId;
    currentRole = 'EDITOR';
    final targetIndex = members.indexWhere(
      (member) => member.userId == targetUserId,
    );
    final oldOwnerIndex = members.indexWhere(
      (member) => member.role == 'OWNER',
    );
    members[oldOwnerIndex] = FamilyMember(
      userId: members[oldOwnerIndex].userId,
      username: members[oldOwnerIndex].username,
      displayName: members[oldOwnerIndex].displayName,
      role: 'EDITOR',
      joinedAt: members[oldOwnerIndex].joinedAt,
      currentUser: members[oldOwnerIndex].currentUser,
    );
    members[targetIndex] = FamilyMember(
      userId: members[targetIndex].userId,
      username: members[targetIndex].username,
      displayName: members[targetIndex].displayName,
      role: 'OWNER',
      joinedAt: members[targetIndex].joinedAt,
      currentUser: members[targetIndex].currentUser,
    );
    return FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: targetUserId,
      role: 'EDITOR',
    );
  }
}

class _MemberSelectionStore implements FamilySelectionStore {
  @override
  Future<int?> read(int userId) async => 4;

  @override
  Future<void> write(int userId, int familyId) async {}

  @override
  Future<void> clear(int userId) async {}
}

class _MemberSessionStore implements SessionStore {
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

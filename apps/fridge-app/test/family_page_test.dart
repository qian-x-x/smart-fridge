import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/features/family/presentation/family_action_dialog.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:smart_fridge_app/features/profile/presentation/profile_page.dart';

void main() {
  testWidgets('family forms validate and retain failed input for retry', (
    tester,
  ) async {
    var calls = 0;
    var reject = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FamilyActionDialog(
            join: true,
            onSubmit: (value) async {
              calls++;
              if (reject) throw StateError('邀请码无效');
              return null;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('join-family-submit')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('请输入 8 位字母或数字邀请码'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('invite-code-input')),
      'TEST2026',
    );
    await tester.tap(find.byKey(const ValueKey('join-family-submit')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('TEST2026'), findsOneWidget);
    expect(find.text('邀请码无效'), findsOneWidget);
    reject = false;
  });

  testWidgets('all settings rows open an honest capability dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_FamilySessionStore()),
          familyDataSourceProvider.overrideWithValue(_EmptyFamilySource()),
          familySelectionStoreProvider.overrideWithValue(
            _MemoryFamilySelectionStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in ['临期提醒', '冰箱布局', '外观与可访问性']) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }
    expect(find.byType(Switch), findsNothing);
  });
  testWidgets('profile displays data returned by the family API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familySelectionStoreProvider.overrideWithValue(
            _MemoryFamilySelectionStore(),
          ),

          sessionStoreProvider.overrideWithValue(_FamilySessionStore()),
          familyDataSourceProvider.overrideWithValue(_FamilySource()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('S2 接口测试家庭'), findsAtLeastNWidgets(1));
    expect(find.textContaining('ABC12345'), findsOneWidget);
    expect(find.text('拥有者'), findsAtLeastNWidgets(1));
    expect(find.textContaining('MANS2026'), findsNothing);
  });

  testWidgets('creates the first family from the empty state', (tester) async {
    final source = _EmptyFamilySource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familySelectionStoreProvider.overrideWithValue(
            _MemoryFamilySelectionStore(),
          ),

          sessionStoreProvider.overrideWithValue(_FamilySessionStore()),
          familyDataSourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有家庭'), findsOneWidget);
    await tester.tap(find.text('创建第一个家庭'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('family-name-input')),
      '周末厨房',
    );
    await tester.tap(find.byKey(const ValueKey('create-family-submit')));
    await tester.pumpAndSettle();

    expect(source.createdName, '周末厨房');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfilePage)),
    );
    expect(
      container.read(familyControllerProvider).value?.selectedFamily?.name,
      '周末厨房',
    );
    final visibleTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .where((text) => text.isNotEmpty)
        .join(' | ');
    expect(find.text('周末厨房'), findsOneWidget, reason: visibleTexts);
  });
  testWidgets('joins a family and makes it the selected workspace', (
    tester,
  ) async {
    final source = _JoinFamilySource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_FamilySessionStore()),
          familyDataSourceProvider.overrideWithValue(source),
          familySelectionStoreProvider.overrideWithValue(
            _MemoryFamilySelectionStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('join-family-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('invite-code-input')),
      'friend26',
    );
    await tester.tap(find.byKey(const ValueKey('join-family-submit')));
    await tester.pumpAndSettle();

    expect(source.joinedCode, 'FRIEND26');
    expect(find.text('朋友的家'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfilePage)),
    );
    expect(
      container.read(familyControllerProvider).value?.selectedFamily?.id,
      6,
    );
  });
  testWidgets('owner opens member management with role actions', (
    tester,
  ) async {
    final source = _MemberManagementFamilySource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_FamilySessionStore()),
          familyDataSourceProvider.overrideWithValue(source),
          familySelectionStoreProvider.overrideWithValue(
            _MemoryFamilySelectionStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('manage-members-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-actions-9')));
    await tester.pumpAndSettle();

    expect(find.text('成员管理'), findsOneWidget);
    expect(find.text('家庭成员'), findsOneWidget);
    expect(find.text('设为编辑者'), findsOneWidget);
    expect(find.text('设为只读者'), findsOneWidget);
    expect(find.text('转交所有权'), findsOneWidget);
    expect(find.text('移除成员'), findsOneWidget);
  });
}

class _FamilySessionStore implements SessionStore {
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

class _FamilySource implements FamilyDataSource {
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async {
    return const [
      FamilyInfo(
        id: 4,
        name: 'S2 接口测试家庭',
        inviteCode: 'ABC12345',
        ownerUserId: 7,
        role: 'OWNER',
      ),
    ];
  }

  @override
  Future<FamilyInfo> create(AuthSession session, String name) async {
    return FamilyInfo(
      id: 9,
      name: name,
      inviteCode: 'NEWCODE1',
      ownerUserId: 7,
      role: 'OWNER',
    );
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async {
    return const [];
  }

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

class _EmptyFamilySource implements FamilyDataSource {
  final List<FamilyInfo> families = [];
  String? createdName;

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => families;

  @override
  Future<FamilyInfo> create(AuthSession session, String name) async {
    createdName = name;
    final family = FamilyInfo(
      id: 9,
      name: name,
      inviteCode: 'WEEKEND1',
      ownerUserId: 7,
      role: 'OWNER',
    );
    families.add(family);
    return family;
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async {
    return const [];
  }

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

class _MemoryFamilySelectionStore implements FamilySelectionStore {
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

class _JoinFamilySource extends _FamilySource {
  String? joinedCode;

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
    joinedCode = inviteCode;
    return const FamilyInfo(
      id: 6,
      name: '朋友的家',
      inviteCode: 'FRIEND26',
      ownerUserId: 11,
      role: 'VIEWER',
    );
  }

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async {
    return [
      ...await super.list(session),
      const FamilyInfo(
        id: 6,
        name: '朋友的家',
        inviteCode: 'FRIEND26',
        ownerUserId: 11,
        role: 'VIEWER',
      ),
    ];
  }
}

class _MemberManagementFamilySource extends _FamilySource {
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
      role: 'EDITOR',
      joinedAt: DateTime.utc(2026, 10, 29),
      currentUser: false,
    ),
  ];

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async {
    return List.unmodifiable(members);
  }
}

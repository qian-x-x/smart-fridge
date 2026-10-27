import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/profile/presentation/profile_page.dart';

void main() {
  testWidgets('profile displays data returned by the family API', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
      container.read(familyControllerProvider).value?.single.name,
      '周末厨房',
    );
    final visibleTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .where((text) => text.isNotEmpty)
        .join(' | ');
    expect(find.text('周末厨房'), findsOneWidget, reason: visibleTexts);
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
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/presentation/fridge_home_page.dart';

void main() {
  testWidgets(
    'home exposes accessible fridge zones and switches compartments',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: FridgeHomePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我家的冰箱'), findsOneWidget);
      expect(find.text('冷藏'), findsOneWidget);
      expect(find.text('变温'), findsOneWidget);
      expect(find.text('冷冻'), findsOneWidget);
      expect(find.text('番茄'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('fridge-zone-selector')),
        const Offset(-130, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('常温'), findsOneWidget);

      await tester.tap(find.text('冷冻'));
      await tester.pumpAndSettle();

      expect(find.text('手工水饺'), findsOneWidget);
    },
  );
}

class _FakeSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => AuthSession.demo();

  @override
  Future<void> write(AuthSession session) async {}
}

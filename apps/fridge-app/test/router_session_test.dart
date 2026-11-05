import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/app.dart';
import 'package:smart_fridge_app/core/router/app_router.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/webgl_fridge_view.dart';
import 'package:smart_fridge_app/features/recipe/presentation/recipes_page.dart';

void main() {
  testWidgets(
    'navigation keeps the scene and recipe query, and disables hidden scene input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(_RoutingAuth.new)],
          child: const SmartFridgeApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartFridgeApp)),
      );
      final router = container.read(appRouterProvider);
      final scene = tester.element(find.byType(WebGLFridgeView));
      router.go('/recipes');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WebGLFridgeView>(
              find.byType(WebGLFridgeView, skipOffstage: false),
            )
            .interactive,
        isFalse,
      );
      await tester.tap(find.text('20 分钟内'));
      await tester.enterText(
        find.byKey(const ValueKey('recipe-search-input')),
        '番茄',
      );
      await tester.pumpAndSettle();
      router.go('/profile');
      await tester.pumpAndSettle();
      router.go('/recipes');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('recipe-search-input')),
            )
            .controller
            ?.text,
        '番茄',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '20 分钟内'))
            .selected,
        isTrue,
      );
      router.go('/home');
      await tester.pumpAndSettle();
      expect(
        identical(tester.element(find.byType(WebGLFridgeView)), scene),
        isTrue,
      );
      expect(
        tester
            .widget<WebGLFridgeView>(find.byType(WebGLFridgeView))
            .interactive,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logging out disposes cached branches and their private draft state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(_RoutingAuth.new)],
          child: const SmartFridgeApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartFridgeApp)),
      );
      final router = container.read(appRouterProvider);
      router.go('/recipes');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recipe-search-input')),
        '私人查询',
      );
      (container.read(authControllerProvider.notifier) as _RoutingAuth)
          .signOut();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.byType(RecipesPage, skipOffstage: false), findsNothing);
      expect(find.byType(WebGLFridgeView, skipOffstage: false), findsNothing);
      (container.read(authControllerProvider.notifier) as _RoutingAuth)
          .signIn();
      await tester.pumpAndSettle();
      router.go('/recipes');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('recipe-search-input')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'root sheets cover the mobile navigation and suspend the iframe',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(_RoutingAuth.new)],
          child: const SmartFridgeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('番茄').first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('番茄').first);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byType(BottomSheet)).dy,
        closeTo(844, 1),
      );
      expect(
        tester
            .widget<WebGLFridgeView>(find.byType(WebGLFridgeView))
            .interactive,
        isFalse,
      );
      await tester.tapAt(const Offset(326, 810));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartFridgeApp)),
      );
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/home',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('token rotation preserves route, dialog and unsaved text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_RoutingAuth.new)],
        child: const SmartFridgeApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartFridgeApp)),
    );
    final router = container.read(appRouterProvider);
    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建家庭'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('family-name-input')),
      '未提交的家庭',
    );
    (container.read(authControllerProvider.notifier) as _RoutingAuth).rotate();
    await tester.pumpAndSettle();
    expect(identical(container.read(appRouterProvider), router), isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(find.text('未提交的家庭'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RoutingAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => AuthSession.demo();

  void signOut() => state = const AsyncData(null);
  void signIn() => state = AsyncData(AuthSession.demo());

  void rotate() {
    final current = AuthSession.demo();
    state = AsyncData(
      AuthSession(
        accessToken: 'rotated-demo',
        refreshToken: current.refreshToken,
        expiresIn: 900,
        issuedAt: DateTime.now().toUtc(),
        user: current.user,
        isDemo: true,
      ),
    );
  }
}

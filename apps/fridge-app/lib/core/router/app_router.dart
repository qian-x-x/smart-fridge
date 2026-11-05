import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/presentation/login_page.dart';
import 'package:smart_fridge_app/features/auth/presentation/register_page.dart';
import 'package:smart_fridge_app/features/auth/presentation/splash_page.dart';
import 'package:smart_fridge_app/features/fridge/presentation/fridge_home_page.dart';
import 'package:smart_fridge_app/features/profile/presentation/profile_page.dart';
import 'package:smart_fridge_app/features/recipe/presentation/recipes_page.dart';
import 'package:smart_fridge_app/shared/layout/home_shell.dart';
import 'package:smart_fridge_app/shared/layout/market_branch_container.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    refreshListenable: refresh,
    initialLocation: '/boot',
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      final isPublic = path == '/login' || path == '/register';
      final hasLoaded = auth.hasValue;
      final isAuthenticated = auth.value != null;

      if (!hasLoaded) {
        return path == '/boot' ? null : '/boot';
      }
      if (!isAuthenticated && !isPublic) {
        return '/login';
      }
      if (isAuthenticated && (isPublic || path == '/boot')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/boot', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _authPage(state, const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _authPage(state, const RegisterPage()),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => HomeShell(child: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            MarketBranchContainer(
              index: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const FridgeHomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recipes',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const RecipesPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

CustomTransitionPage<void> _authPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 310),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondary, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .025),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );

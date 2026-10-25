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

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/boot',
    redirect: (context, state) {
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
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const FridgeHomePage(),
          ),
          GoRoute(
            path: '/recipes',
            builder: (context, state) => const RecipesPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = switch (location) {
      '/recipes' => 1,
      '/profile' => 2,
      _ => 0,
    };

    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x125B4336),
              blurRadius: 22,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (nextIndex) {
            final route = switch (nextIndex) {
              1 => '/recipes',
              2 => '/profile',
              _ => '/home',
            };
            context.go(route);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.kitchen_outlined),
              selectedIcon: Icon(Icons.kitchen_rounded),
              label: '冰箱',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_rounded),
              label: '菜谱',
            ),
            NavigationDestination(
              icon: Icon(Icons.family_restroom_outlined),
              selectedIcon: Icon(Icons.family_restroom_rounded),
              label: '家庭',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1040;
        if (!desktop) {
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
                onDestinationSelected: (nextIndex) => _go(context, nextIndex),
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

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: _DesktopRail(
                  index: index,
                  onSelected: (nextIndex) => _go(context, nextIndex),
                ),
              ),
              Expanded(
                child: SafeArea(left: false, bottom: false, child: child),
              ),
            ],
          ),
        );
      },
    );
  }

  void _go(BuildContext context, int index) {
    context.go(switch (index) {
      1 => '/recipes',
      2 => '/profile',
      _ => '/home',
    });
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: [
          Tooltip(
            message: '小满冰箱',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cocoa,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x285B4336),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.kitchen_rounded,
                color: AppColors.cream,
                size: 25,
              ),
            ),
          ),
          const SizedBox(height: 30),
          _RailDestination(
            icon: Icons.kitchen_outlined,
            selectedIcon: Icons.kitchen_rounded,
            label: '冰箱',
            selected: index == 0,
            onTap: () => onSelected(0),
          ),
          const SizedBox(height: 12),
          _RailDestination(
            icon: Icons.restaurant_menu_rounded,
            label: '菜谱',
            selected: index == 1,
            onTap: () => onSelected(1),
          ),
          const SizedBox(height: 12),
          _RailDestination(
            icon: Icons.family_restroom_outlined,
            selectedIcon: Icons.family_restroom_rounded,
            label: '家庭',
            selected: index == 2,
            onTap: () => onSelected(2),
          ),
          const Spacer(),
          IconButton(
            tooltip: '通知',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.cocoa,
          ),
          const SizedBox(height: 8),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.paper, width: 3),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? AppColors.linen : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 62,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon ?? icon : icon,
                  size: 21,
                  color: selected ? AppColors.cocoa : AppColors.sand,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.cocoa : AppColors.sand,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

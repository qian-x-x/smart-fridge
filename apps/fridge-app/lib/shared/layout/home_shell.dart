import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fridge_app/core/config/app_brand.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/shared/layout/scene_input_scope.dart';
import 'package:smart_fridge_app/shared/widgets/action_button.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final index = switch (location) {
      '/recipes' => 1,
      '/profile' => 2,
      _ => 0,
    };
    final family = ref.watch(familyControllerProvider).value?.selectedFamily;
    final isDemo = ref.watch(authControllerProvider).value?.isDemo ?? false;
    void go(int next) {
      if (next == index) return;
      if (child is StatefulNavigationShell) {
        (child as StatefulNavigationShell).goBranch(next);
      } else {
        context.go(['/home', '/recipes', '/profile'][next]);
      }
    }

    return SceneInputScope(
      enabled: ModalRoute.isCurrentOf(context) ?? true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1000) {
            return Scaffold(
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Container(
                      height: 64,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            AppBrand.name,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (isDemo)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Text(
                                '演示',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 156),
                            child: AppOutlinedButton.icon(
                              onPressed: () => go(2),
                              icon: const Icon(Icons.home_outlined, size: 17),
                              label: Text(
                                family?.name ?? '选择家庭',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
              bottomNavigationBar: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: go,
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.kitchen_outlined),
                      selectedIcon: Icon(Icons.kitchen),
                      label: '冰箱',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.restaurant_menu_outlined),
                      selectedIcon: Icon(Icons.restaurant_menu),
                      label: '菜谱',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
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
                Container(
                  width: 94,
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 28, 12, 20),
                      child: Column(
                        children: [
                          const Tooltip(
                            message: AppBrand.name,
                            child: Icon(
                              Icons.kitchen_outlined,
                              size: 34,
                              color: AppColors.terracotta,
                            ),
                          ),
                          const SizedBox(height: 32),
                          for (final entry in [
                            (Icons.kitchen_outlined, '我的冰箱'),
                            (Icons.restaurant_menu_outlined, '菜谱灵感'),
                            (Icons.people_outline, '家庭设置'),
                          ].indexed) ...[
                            PressFeedback(
                              child: Semantics(
                                selected: index == entry.$1,
                                child: Material(
                                  color: index == entry.$1
                                      ? AppColors.ink
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => go(entry.$1),
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 74,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                          horizontal: 3,
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              entry.$2.$1,
                                              size: 22,
                                              color: index == entry.$1
                                                  ? Colors.white
                                                  : AppColors.muted,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              entry.$2.$2,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: index == entry.$1
                                                    ? Colors.white
                                                    : AppColors.muted,
                                                fontWeight: index == entry.$1
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const Spacer(),
                          const Divider(),
                          const SizedBox(height: 20),
                          IconButton(
                            tooltip: '家庭与设置',
                            onPressed: () => go(2),
                            icon: const CircleAvatar(
                              backgroundColor: AppColors.mint,
                              foregroundColor: AppColors.terracotta,
                              child: Icon(Icons.person_outline, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    left: false,
                    bottom: false,
                    child: Column(
                      children: [
                        Container(
                          height: 78,
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                AppBrand.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (isDemo)
                                const Padding(
                                  padding: EdgeInsets.only(right: 18),
                                  child: Text(
                                    '演示模式 · 仅供浏览',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: AppOutlinedButton.icon(
                                  onPressed: () => go(2),
                                  icon: const Icon(
                                    Icons.home_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    family?.name ?? '选择家庭',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

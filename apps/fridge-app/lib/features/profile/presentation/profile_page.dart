import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:smart_fridge_app/features/family/presentation/family_workspace_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final user = session?.user;
    final family = ref.watch(familyControllerProvider).value?.selectedFamily;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 950;
        final families = Container(
          padding: EdgeInsets.all(desktop ? 24 : 16),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: const FamilyWorkspaceSection(),
        );
        return ListView(
          key: const PageStorageKey('family-page-scroll'),
          padding: EdgeInsets.fromLTRB(
            desktop ? 32 : 20,
            26,
            desktop ? 32 : 20,
            32,
          ),
          children: [
            const Text(
              'BETTER TOGETHER',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 9),
            Text('家庭协作', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 9),
            const Text(
              '家人共享，日常各自有序。',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.linen,
                  foregroundColor: AppColors.terracotta,
                  child: Text(
                    user?.displayName.characters.firstOrNull ?? '易',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? '家人',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        session?.isDemo == true
                            ? '演示账号 · 仅供浏览'
                            : '@${user?.username ?? ''} · ${family?.name ?? '选择一个家庭'}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (family != null)
                  Text(
                    _roleLabel(family.role),
                    style: const TextStyle(
                      color: AppColors.terracotta,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            families,
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: AppOutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rose,
                  side: const BorderSide(color: Color(0x55B75B64)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('退出当前账号'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '小易冰箱 · 查食材，看菜谱，都容易',
              style: TextStyle(
                color: AppColors.cocoa.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('要离开冰箱了吗？'),
        content: const Text('本地登录信息会被清除，下次仍可重新登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('留下'),
          ),
          AppFilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  String _roleLabel(String role) {
    return switch (role) {
      'OWNER' => '拥有者',
      'EDITOR' => '编辑者',
      _ => '只读者',
    };
  }
}

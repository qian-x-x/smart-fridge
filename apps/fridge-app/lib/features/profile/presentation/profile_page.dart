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
    final familyState = ref.watch(familyControllerProvider);
    final family = familyState.value?.selectedFamily;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Text(
          '家庭与设置',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cocoa,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(
                  user?.displayName.characters.first ?? '小',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? '小满',
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session?.isDemo == true
                          ? '演示账号 · ${family?.name ?? '小满的家'}'
                          : '@${user?.username ?? 'family_owner'} · '
                                '${family?.name ?? '正在加载家庭'}',
                      style: TextStyle(
                        color: AppColors.cream.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (family != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _roleLabel(family.role),
                    style: const TextStyle(
                      color: AppColors.linen,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FamilyWorkspaceSection(),
        const SizedBox(height: 20),
        Text('偏好设置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const _SettingTile(
          icon: Icons.notifications_none_rounded,
          title: '临期提醒',
          subtitle: '食材进入最后 3 天时通知家庭成员',
          trailing: Switch(value: true, onChanged: null),
        ),
        const SizedBox(height: 8),
        const _SettingTile(
          icon: Icons.layers_outlined,
          title: '冰箱布局',
          subtitle: '4 个分区 · 9 个隔层和储物筐',
        ),
        const SizedBox(height: 8),
        const _SettingTile(
          icon: Icons.palette_outlined,
          title: '外观与可访问性',
          subtitle: '香槟米色 · WebGL 3D 视图 · 跟随系统字号',
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _logout(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.rose,
            side: const BorderSide(color: Color(0x55B75B64)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('退出当前账号'),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Smart Fridge · 工程预览版 0.1.0',
            style: TextStyle(
              color: AppColors.cocoa.withValues(alpha: 0.38),
              fontSize: 10,
            ),
          ),
        ),
      ],
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
          FilledButton(
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

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x185B4336)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: AppColors.cocoa),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.53),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          trailing ??
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand),
        ],
      ),
    );
  }
}

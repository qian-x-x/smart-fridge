import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:smart_fridge_app/features/family/presentation/family_workspace_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';

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
        final settings = _settings(context, ref);
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
            Text('家庭与设置', style: Theme.of(context).textTheme.headlineMedium),
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
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: families),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: settings),
                ],
              )
            else ...[
              families,
              const SizedBox(height: 22),
              settings,
            ],
          ],
        );
      },
    );
  }

  Widget _settings(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('偏好设置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _SettingTile(
          icon: Icons.notifications_none_rounded,
          title: '临期提醒',
          subtitle: '库存显示临期状态 · 推送通知尚未接入',
          onTap: () => _showSetting(
            context,
            '临期提醒',
            const Text(
              '库存会标记未来 3 天内到期及已过期的食材，菜谱页可筛选临期食材。当前版本尚未接入系统推送通知，也不提供通知开关。',
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.layers_outlined,
          title: '冰箱布局',
          subtitle: '冷藏与独立抽屉 · 厨房常温储物',
          onTap: () => _showSetting(
            context,
            '冰箱布局',
            Consumer(
              builder: (context, ref, _) => ref
                  .watch(fridgeWorkspaceProvider)
                  .when(
                    data: (workspace) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workspace.hasFridge
                              ? workspace.fridgeName
                              : '当前家庭尚未创建冰箱',
                        ),
                        for (final zone in workspace.zones)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${zone.name} · ${zone.temperature}'),
                            subtitle: Text(
                              zone.containers
                                  .map((item) => item.name)
                                  .join('、'),
                            ),
                          ),
                        const Text('当前布局为只读。分区与容器编辑尚未接入；常温食品存放在厨房柜台。'),
                      ],
                    ),
                    loading: () => const Text('正在读取冰箱布局…'),
                    error: (error, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error.toString()),
                        TextButton(
                          onPressed: () => ref
                              .read(fridgeWorkspaceProvider.notifier)
                              .refresh(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.palette_outlined,
          title: '外观与可访问性',
          subtitle: '静白全景 · 跟随系统字号与动态效果偏好',
          onTap: () => _showSetting(
            context,
            '外观与可访问性',
            const Text(
              '当前采用静白全景主题。文字跟随系统字号，三维动画遵循浏览器减少动态效果偏好。可在系统或浏览器的可访问性设置中调整；当前版本暂不提供其他主题。',
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppOutlinedButton.icon(
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
            '小易冰箱 · 查食材，看菜谱，都容易',
            style: TextStyle(
              color: AppColors.cocoa.withValues(alpha: 0.38),
              fontSize: 11,
            ),
          ),
        ),
        TextButton(
          onPressed: () =>
              showLicensePage(context: context, applicationName: '小易冰箱'),
          child: const Text('开源许可'),
        ),
      ],
    ),
  );

  Future<void> _showSetting(
    BuildContext context,
    String title,
    Widget content,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

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

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
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
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand),
            ],
          ),
        ),
      ),
    );
  }
}

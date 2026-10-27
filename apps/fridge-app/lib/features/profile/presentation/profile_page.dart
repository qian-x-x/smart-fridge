import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final user = session?.user;
    final familyState = ref.watch(familyControllerProvider);
    final family = familyState.value?.firstOrNull;

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
        _FamilySection(
          state: familyState,
          onCreate: () => _createFamily(context, ref),
          onRetry: () =>
              ref.read(familyControllerProvider.notifier).refresh(),
        ),
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

  Future<void> _createFamily(BuildContext context, WidgetRef ref) async {
    var familyName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('创建新家庭'),
        content: TextFormField(
          key: const ValueKey('family-name-input'),
          autofocus: true,
          onChanged: (value) => familyName = value,
          decoration: const InputDecoration(
            labelText: '家庭名称',
            hintText: '例如：小满的家',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('create-family-submit'),
            onPressed: () {
              final value = familyName.trim();
              if (value.isNotEmpty) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(familyControllerProvider.notifier).create(name);
      ref.invalidate(familyControllerProvider);
      await ref.read(familyControllerProvider.future);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('家庭已创建')));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _FamilySection extends StatelessWidget {
  const _FamilySection({
    required this.state,
    required this.onCreate,
    required this.onRetry,
  });

  final AsyncValue<List<FamilyInfo>> state;
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const _FamilyStateCard(
        icon: Icons.sync_rounded,
        title: '正在同步家庭',
        subtitle: '从 Gateway 读取家庭权限和邀请码',
      ),
      error: (error, stackTrace) => _FamilyStateCard(
        icon: Icons.cloud_off_rounded,
        title: '家庭信息加载失败',
        subtitle: error.toString(),
        action: TextButton(onPressed: onRetry, child: const Text('重试')),
      ),
      data: (families) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '我的家庭',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('创建家庭'),
              ),
            ],
          ),
          if (families.isEmpty)
            _FamilyStateCard(
              icon: Icons.family_restroom_rounded,
              title: '还没有家庭',
              subtitle: '创建家庭后即可邀请成员并配置冰箱',
              action: FilledButton(
                onPressed: onCreate,
                child: const Text('创建第一个家庭'),
              ),
            )
          else
            for (final family in families)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FamilyCard(family: family),
              ),
        ],
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({required this.family});

  final FamilyInfo family;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEE2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  family.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '邀请码 ${family.inviteCode}',
                  style: const TextStyle(
                    color: AppColors.sage,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MemberAvatar(
                label: family.name.characters.first,
                color: AppColors.terracotta,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '你的角色：${_roleLabel(family.role)} · 家庭数据已同步',
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.62),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      'OWNER' => '拥有者',
      'EDITOR' => '编辑者',
      _ => '只读者',
    };
  }
}

class _FamilyStateCard extends StatelessWidget {
  const _FamilyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x185B4336)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.paper, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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

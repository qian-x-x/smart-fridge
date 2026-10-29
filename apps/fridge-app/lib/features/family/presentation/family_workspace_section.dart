import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_workspace_state.dart';
import 'package:smart_fridge_app/features/family/presentation/family_member_management_sheet.dart';

class FamilyWorkspaceSection extends ConsumerWidget {
  const FamilyWorkspaceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(familyControllerProvider);
    return state.when(
      loading: () => const _StateCard(
        icon: Icons.sync_rounded,
        title: '正在同步家庭',
        subtitle: '从 Gateway 读取家庭权限和邀请码',
      ),
      error: (error, stackTrace) => _StateCard(
        icon: Icons.cloud_off_rounded,
        title: '家庭信息加载失败',
        subtitle: error.toString(),
        action: TextButton(
          onPressed: () =>
              ref.read(familyControllerProvider.notifier).refresh(),
          child: const Text('重试'),
        ),
      ),
      data: (workspace) => _FamilyList(
        workspace: workspace,
        onCreate: () => _createFamily(context, ref),
        onJoin: () => _joinFamily(context, ref),
        onSelect: (familyId) => _selectFamily(context, ref, familyId),
      ),
    );
  }

  Future<void> _selectFamily(
    BuildContext context,
    WidgetRef ref,
    int familyId,
  ) async {
    try {
      await ref.read(familyControllerProvider.notifier).selectFamily(familyId);
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _joinFamily(BuildContext context, WidgetRef ref) async {
    var inviteCode = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('加入家庭'),
        content: TextField(
          key: const ValueKey('invite-code-input'),
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          onChanged: (text) => inviteCode = text,
          decoration: const InputDecoration(labelText: '8 位邀请码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('join-family-submit'),
            onPressed: () {
              final code = inviteCode.trim();
              if (code.length == 8) {
                Navigator.of(dialogContext).pop(code);
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(familyControllerProvider.notifier).join(value);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _createFamily(BuildContext context, WidgetRef ref) async {
    var familyName = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('创建新家庭'),
        content: TextField(
          key: const ValueKey('family-name-input'),
          autofocus: true,
          onChanged: (text) => familyName = text,
          decoration: const InputDecoration(labelText: '家庭名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('create-family-submit'),
            onPressed: () {
              final name = familyName.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(familyControllerProvider.notifier).create(value);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _FamilyList extends StatelessWidget {
  const _FamilyList({
    required this.workspace,
    required this.onCreate,
    required this.onJoin,
    required this.onSelect,
  });

  final FamilyWorkspaceState workspace;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              key: const ValueKey('join-family-button'),
              onPressed: onJoin,
              icon: const Icon(Icons.login_rounded, size: 17),
              label: const Text('加入家庭'),
            ),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('创建家庭'),
            ),
          ],
        ),
        if (workspace.families.isEmpty)
          _StateCard(
            icon: Icons.family_restroom_rounded,
            title: '还没有家庭',
            subtitle: '创建家庭或使用邀请码加入一个家庭',
            action: FilledButton(
              onPressed: onCreate,
              child: const Text('创建第一个家庭'),
            ),
          )
        else
          for (final family in workspace.families)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FamilyCard(
                family: family,
                selected: family.id == workspace.selectedFamilyId,
                onTap: () => onSelect(family.id),
              ),
            ),
        if (workspace.selectedFamily != null && !workspace.selectedFamily!.isDemo)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('manage-members-button'),
              onPressed: () => showFamilyMemberManagementSheet(context),
              icon: const Icon(Icons.people_outline_rounded),
              label: const Text('查看成员'),
            ),
          ),
      ],
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final FamilyInfo family;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE1EBDD) : AppColors.paper,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey('family-card-${family.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: selected
                    ? AppColors.sage
                    : AppColors.terracotta,
                foregroundColor: Colors.white,
                child: Text(family.name.characters.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '邀请码 ${family.inviteCode} · '
                      '${_roleLabel(family.role)}',
                      style: TextStyle(
                        color: AppColors.cocoa.withValues(alpha: 0.58),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? AppColors.sage : AppColors.sand,
              ),
            ],
          ),
        ),
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

class _StateCard extends StatelessWidget {
  const _StateCard({
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(subtitle),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

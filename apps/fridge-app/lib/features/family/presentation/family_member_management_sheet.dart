import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/application/family_members_controller.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

Future<void> showFamilyMemberManagementSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    builder: (context) => const FamilyMemberManagementSheet(),
  );
}

class FamilyMemberManagementSheet extends ConsumerWidget {
  const FamilyMemberManagementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider);
    final workspace = ref.watch(familyControllerProvider).value;
    final canManage = workspace?.selectedFamily?.role == 'OWNER';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return members.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString()),
            ),
          ),
          data: (items) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '成员管理',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${items.length} 位成员',
                    style: const TextStyle(color: AppColors.sage),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Text('当前家庭还没有成员')
              else
                for (final member in items)
                  _MemberTile(
                    member: member,
                    canManage: canManage,
                    onRoleChanged: (role) =>
                        _changeRole(context, ref, member.userId, role),
                    onRemove: () => _confirmRemove(context, ref, member),
                    onTransfer: () => _confirmTransfer(context, ref, member),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    int userId,
    String role,
  ) async {
    try {
      await ref.read(familyMembersProvider.notifier).updateRole(userId, role);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定将 ${member.displayName} 移出家庭吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          AppFilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(familyMembersProvider.notifier).remove(member.userId);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _confirmTransfer(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('转交家庭所有权'),
        content: Text('转交后 ${member.displayName} 成为拥有者，你将变为编辑者。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          AppFilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认转交'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(familyMembersProvider.notifier).transfer(member.userId);
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.onRoleChanged,
    required this.onRemove,
    required this.onTransfer,
  });

  final FamilyMember member;
  final bool canManage;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onRemove;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final ordinaryMember = !member.isOwner;
    return Card(
      key: ValueKey('member-${member.userId}'),
      color: AppColors.paper,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isOwner
              ? AppColors.cocoa
              : AppColors.terracotta,
          foregroundColor: Colors.white,
          child: Text(member.displayName.characters.first),
        ),
        title: Text(
          member.currentUser ? '${member.displayName}（我）' : member.displayName,
        ),
        subtitle: Text(_roleLabel(member.role)),
        trailing: canManage && ordinaryMember
            ? PopupMenuButton<_MemberAction>(
                key: ValueKey('member-actions-${member.userId}'),
                tooltip: '成员操作',
                onSelected: (action) {
                  switch (action) {
                    case _MemberAction.makeEditor:
                      onRoleChanged('EDITOR');
                      break;
                    case _MemberAction.makeViewer:
                      onRoleChanged('VIEWER');
                      break;
                    case _MemberAction.transferOwner:
                      onTransfer();
                      break;
                    case _MemberAction.remove:
                      onRemove();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _MemberAction.makeEditor,
                    child: Text('设为编辑者'),
                  ),
                  const PopupMenuItem(
                    value: _MemberAction.makeViewer,
                    child: Text('设为只读者'),
                  ),
                  if (member.isEditor)
                    const PopupMenuItem(
                      value: _MemberAction.transferOwner,
                      child: Text('转交所有权'),
                    ),
                  const PopupMenuItem(
                    value: _MemberAction.remove,
                    child: Text('移除成员'),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      'OWNER' => '家庭拥有者',
      'EDITOR' => '编辑者',
      _ => '只读者',
    };
  }
}

enum _MemberAction { makeEditor, makeViewer, transferOwner, remove }

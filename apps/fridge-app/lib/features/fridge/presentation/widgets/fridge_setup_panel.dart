import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';

class FridgeSetupPanel extends ConsumerStatefulWidget {
  const FridgeSetupPanel({super.key, this.family});

  final FamilyInfo? family;

  @override
  ConsumerState<FridgeSetupPanel> createState() => _FridgeSetupPanelState();
}

class _FridgeSetupPanelState extends ConsumerState<FridgeSetupPanel> {
  final _name = TextEditingController(text: '我家的冰箱');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(fridgeWorkspaceProvider.notifier).createFridge(_name.text);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.family;
    final canCreate = family?.canManage == true;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.kitchen_outlined, size: 64),
              const SizedBox(height: 20),
              Text(
                family == null ? '先创建或加入一个家庭' : '${family.name}尚未创建冰箱',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                family == null
                    ? '在家庭页创建家庭，或使用邀请码加入家人的家庭。'
                    : canCreate
                    ? '为冰箱起个名字，系统会自动创建冷藏、变温、冷冻和常温四个区域。'
                    : '请联系家庭拥有者创建冰箱，创建后刷新即可查看。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (canCreate) ...[
                TextField(
                  key: const ValueKey('fridge-name-input'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: '冰箱名称'),
                  onSubmitted: (_) => _create(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                AppFilledButton(
                  key: const ValueKey('create-fridge-button'),
                  onPressed: _saving ? null : _create,
                  child: Text(_saving ? '正在创建…' : '创建冰箱'),
                ),
              ],
              TextButton(
                onPressed: _saving ? null : () => context.go('/profile'),
                child: Text(family == null ? '前往家庭页' : '管理或切换家庭'),
              ),
              if (family != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => ref
                            .read(fridgeWorkspaceProvider.notifier)
                            .refresh(),
                  child: const Text('刷新冰箱'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

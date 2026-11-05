import 'package:flutter/material.dart';

class FormExitGuard extends StatefulWidget {
  const FormExitGuard({
    required this.child,
    required this.hasChanges,
    required this.busy,
    super.key,
  });
  final Widget child;
  final bool Function() hasChanges;
  final bool Function() busy;

  @override
  State<FormExitGuard> createState() => _FormExitGuardState();
}

class _FormExitGuardState extends State<FormExitGuard> {
  bool _allowClose = false;
  bool _confirming = false;

  Future<void> _confirmClose() async {
    if (_confirming || widget.busy()) return;
    if (!widget.hasChanges()) {
      _close();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的内容？'),
        content: const Text('你填写的食材还没有保存。可以继续编辑，或放弃本次填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃填写'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || discard != true || widget.busy()) return;
    _close();
  }

  void _close() {
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ModalRoute.isCurrentOf(context) ?? false)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _allowClose,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmClose();
    },
    child: widget.child,
  );
}

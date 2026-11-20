import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:flutter/material.dart';

class FamilyActionDialog extends StatefulWidget {
  const FamilyActionDialog({
    required this.join,
    required this.onSubmit,
    super.key,
  });
  final bool join;
  final Future<Object?> Function(String value) onSubmit;

  @override
  State<FamilyActionDialog> createState() => _FamilyActionDialogState();
}

class _FamilyActionDialogState extends State<FamilyActionDialog> {
  final _form = GlobalKey<FormState>();
  final _input = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_input.text.trim());
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is StateError
              ? error.message.toString()
              : error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.join ? '加入家庭' : '创建新家庭'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: ValueKey(
                widget.join ? 'invite-code-input' : 'family-name-input',
              ),
              controller: _input,
              autofocus: true,
              enabled: !_busy,
              maxLength: widget.join ? 8 : 60,
              textCapitalization: widget.join
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: widget.join ? '8 位邀请码' : '家庭名称',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (widget.join) {
                  return RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(text)
                      ? null
                      : '请输入 8 位字母或数字邀请码';
                }
                return text.isEmpty || text.length > 60
                    ? '请输入 1 至 60 个字符的家庭名称'
                    : null;
              },
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        AppFilledButton(
          key: ValueKey(
            widget.join ? 'join-family-submit' : 'create-family-submit',
          ),
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? (widget.join ? '正在加入…' : '正在初始化…')
                : widget.join
                ? '加入'
                : '创建',
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

/// Keeps the Material button's focus, semantics and hit target while pressing.
class PressFeedback extends StatefulWidget {
  const PressFeedback({required this.child, this.enabled = true, super.key});
  final Widget child;
  final bool enabled;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;

  @override
  void didUpdateWidget(PressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (_) => setState(() => _pressed = true)
        : null,
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: _pressed ? 0.97 : 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
      builder: (context, value, child) =>
          Transform.scale(scale: value, transformHitTests: false, child: child),
    ),
  );
}

class AppFilledButton extends StatelessWidget {
  const AppFilledButton({
    required this.onPressed,
    required this.child,
    this.style,
    super.key,
  }) : icon = null;
  const AppFilledButton.icon({
    required this.onPressed,
    required Widget label,
    required this.icon,
    this.style,
    super.key,
  }) : child = label;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => PressFeedback(
    enabled: onPressed != null,
    child: icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: icon!,
            label: child,
          ),
  );
}

class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    required this.onPressed,
    required this.child,
    this.style,
    super.key,
  }) : icon = null;
  const AppOutlinedButton.icon({
    required this.onPressed,
    required Widget label,
    required this.icon,
    this.style,
    super.key,
  }) : child = label;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => PressFeedback(
    enabled: onPressed != null,
    child: icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: icon!,
            label: child,
          ),
  );
}

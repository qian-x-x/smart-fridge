import 'package:flutter/widgets.dart';

/// Platform views must not consume events while a root navigator overlay is open.
class SceneInputScope extends InheritedWidget {
  const SceneInputScope({
    required this.enabled,
    required super.child,
    super.key,
  });
  final bool enabled;

  static bool isEnabled(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SceneInputScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(SceneInputScope oldWidget) =>
      enabled != oldWidget.enabled;
}

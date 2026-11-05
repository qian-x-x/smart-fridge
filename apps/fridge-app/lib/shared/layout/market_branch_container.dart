import 'package:flutter/material.dart';
import 'package:smart_fridge_app/shared/layout/scene_input_scope.dart';

/// Retains branch navigators, including the 3D platform view and filter state.
class MarketBranchContainer extends StatefulWidget {
  const MarketBranchContainer({
    required this.index,
    required this.children,
    super.key,
  });
  final int index;
  final List<Widget> children;

  @override
  State<MarketBranchContainer> createState() => _MarketBranchContainerState();
}

class _MarketBranchContainerState extends State<MarketBranchContainer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 310),
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(MarketBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputEnabled = SceneInputScope.isEnabled(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          Offstage(
            offstage: index != widget.index,
            child: TickerMode(
              enabled: index == widget.index,
              child: ExcludeFocus(
                excluding: index != widget.index,
                child: SceneInputScope(
                  enabled: inputEnabled && index == widget.index,
                  child: FadeTransition(
                    opacity: _curve,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.018),
                        end: Offset.zero,
                      ).animate(_curve),
                      child: widget.children[index],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_sticker_stack.dart';
import 'package:smart_fridge_app/features/fridge/domain/ingredient_stickers.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_sticker_image.dart';

class ReferenceStickerLayer extends StatefulWidget {
  const ReferenceStickerLayer({
    required this.zone,
    required this.foods,
    required this.photoSize,
    required this.center,
    required this.interactive,
    required this.onFoodSelected,
    super.key,
  });

  final FridgeZoneId zone;
  final List<FridgeFood> foods;
  final double photoSize;
  final Offset center;
  final bool interactive;
  final ValueChanged<FridgeFood>? onFoodSelected;

  @override
  State<ReferenceStickerLayer> createState() => _ReferenceStickerLayerState();
}

class _ReferenceStickerLayerState extends State<ReferenceStickerLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  static const _rows = 4;
  late List<FridgeStickerStack> _stacks;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _updateStock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(ReferenceStickerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foods != widget.foods || oldWidget.zone != widget.zone) {
      _updateStock();
    }
    _syncMotion();
  }

  int get _columns => fridgeStickerColumns(widget.zone, _stacks.length);
  int get _capacity => _columns * _rows;
  int get _lastPage => math.max(0, (_stacks.length - 1) ~/ _capacity);

  void _updateStock() {
    _stacks = groupFridgeStickers(widget.foods);
    _page = math.min(_page, _lastPage);
  }

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !widget.interactive ||
        _stacks.isEmpty) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The grid is projected into each square reference image.
    final (left, right, rowEdges) = switch (widget.zone) {
      FridgeZoneId.fresh => (.351, .649, const [.151, .236, .351, .463, .553]),
      FridgeZoneId.variable => (
        .151,
        .849,
        const [.233, .354, .475, .596, .717],
      ),
      FridgeZoneId.freezer => (
        .169,
        .831,
        const [.247, .362, .476, .591, .706],
      ),
    };
    final cellWidth = (right - left) / _columns;
    final visible = _stacks.skip(_page * _capacity).take(_capacity);
    final photoOrigin =
        widget.center - Offset(widget.photoSize / 2, widget.photoSize / 2);
    final fadeDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 400);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: fadeDuration,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Stack(
        children: [
          for (final (index, stack) in visible.indexed)
            _positionSticker(
              photoOrigin,
              stack,
              index,
              left,
              cellWidth,
              rowEdges,
            ),
          if (_lastPage > 0)
            Positioned(
              left: 8,
              bottom: 8,
              child: Material(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '上一组食材',
                      onPressed: widget.interactive && _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${_page + 1} / ${_lastPage + 1}'),
                    IconButton(
                      tooltip: '下一组食材',
                      onPressed: widget.interactive && _page < _lastPage
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Positioned _positionSticker(
    Offset origin,
    FridgeStickerStack stack,
    int index,
    double left,
    double cellWidth,
    List<double> rowEdges,
  ) {
    final columns = _columns;
    final slot = index % columns;
    final column = widget.zone == FridgeZoneId.fresh
        ? slot ~/ 2 + (slot.isOdd ? columns ~/ 2 : 0)
        : slot;
    final row = index ~/ columns;
    final top = rowEdges[row];
    final cellHeight = rowEdges[row + 1] - top;
    final size = math.min(
      78.0,
      math.min(cellWidth, cellHeight) * widget.photoSize * .78,
    );
    final center =
        origin +
        Offset(
          (left + (column + .5) * cellWidth) * widget.photoSize,
          (top + cellHeight / 2) * widget.photoSize,
        );
    return Positioned(
      key: ValueKey(stack.food.id),
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: _ReferenceSticker(
        stack: stack,
        size: size,
        float: _float,
        phase: index * .72,
        onTap: widget.interactive && widget.onFoodSelected != null
            ? () => widget.onFoodSelected!(stack.food)
            : null,
      ),
    );
  }
}

class _ReferenceSticker extends StatefulWidget {
  const _ReferenceSticker({
    required this.stack,
    required this.size,
    required this.float,
    required this.phase,
    required this.onTap,
  });

  final FridgeStickerStack stack;
  final double size;
  final Animation<double> float;
  final double phase;
  final VoidCallback? onTap;

  @override
  State<_ReferenceSticker> createState() => _ReferenceStickerState();
}

class _ReferenceStickerState extends State<_ReferenceSticker> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.onTap != null && (_hover || _focused);
    final food = widget.stack.food;
    final portions = widget.stack.portionCount;
    final badge = widget.stack.badge;
    final size = widget.size;
    return Semantics(
      button: true,
      label: food.name,
      value: portions == null ? null : '$portions 份',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onHover: (value) => setState(() => _hover = value),
          onFocusChange: (value) => setState(() => _focused = value),
          onTap: widget.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: widget.float,
                builder: (context, child) {
                  final sine = MediaQuery.disableAnimationsOf(context)
                      ? 0.0
                      : math.sin(
                          widget.float.value * 2 * math.pi + widget.phase,
                        );
                  return Transform.translate(
                    offset: Offset(0, size * (highlighted ? -.1 : sine * .05)),
                    child: Transform.rotate(
                      angle: highlighted ? 0 : sine * .035,
                      child: Transform.scale(
                        scale: highlighted ? 1.04 : 1,
                        child: child,
                      ),
                    ),
                  );
                },
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (
                        var layer = widget.stack.layers - 1;
                        layer >= 0;
                        layer--
                      )
                        Transform.translate(
                          offset: Offset(
                            -layer * size * .04,
                            layer * size * .04,
                          ),
                          child: Transform.rotate(
                            angle: -layer * .087,
                            child: Opacity(
                              opacity: layer == 0 ? 1 : .68,
                              child: Center(
                                child: IngredientStickerImage(
                                  sticker: stickerForFood(food),
                                  emoji: food.emoji,
                                  size: size * .86,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (badge != null)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: ExcludeSemantics(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF25313A),
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: (size * .18).clamp(7, 11),
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (highlighted)
                Positioned(
                  bottom: widget.size + 8,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        child: Text(
                          food.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

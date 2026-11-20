import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_sticker_stack.dart';
import 'package:smart_fridge_app/features/fridge/domain/ingredient_stickers.dart';
import 'package:web/web.dart' as web;

class WebGLFridgeView extends StatefulWidget {
  const WebGLFridgeView({
    required this.focus,
    required this.onOverview,
    required this.onZoneSelected,
    this.onFoodSelected,
    this.foods = const [],
    this.interactive = true,
    super.key,
  });

  final ({FridgeZoneId zone, int request})? focus;
  final VoidCallback onOverview;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final ValueChanged<FridgeFood>? onFoodSelected;
  final List<FridgeFood> foods;
  final bool interactive;

  @override
  State<WebGLFridgeView> createState() => _WebGLFridgeViewState();
}

class _WebGLFridgeViewState extends State<WebGLFridgeView> {
  late final String _viewType;
  late final StreamSubscription<web.MessageEvent> _messageSubscription;
  web.HTMLIFrameElement? _iframe;
  bool _ready = false;
  int _inventoryRevision = 0;

  @override
  void initState() {
    super.initState();
    _viewType = 'smart-fridge-webgl-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = 'fridge3d/index.html?rev=blender-scene-v1'
        ..title = '小易冰箱 WebGL 三维模型'
        ..setAttribute('allowtransparency', 'true')
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = 'transparent'
        ..style.overflow = 'hidden';
      iframe.style.pointerEvents = widget.interactive ? 'auto' : 'none';
      iframe.setAttribute('data-input-enabled', widget.interactive.toString());
      _iframe = iframe;
      return iframe;
    });

    _messageSubscription = web.window.onMessage.listen(_handleMessage);
  }

  @override
  void didUpdateWidget(covariant WebGLFridgeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _iframe?.style.pointerEvents = widget.interactive ? 'auto' : 'none';
    _iframe?.setAttribute('data-input-enabled', widget.interactive.toString());
    if (oldWidget.interactive != widget.interactive) _sendInputState();
    if (oldWidget.foods != widget.foods) _sendInventory();
    if (oldWidget.focus != widget.focus) _sendFocus();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _iframe?.style.pointerEvents = 'none';
    _iframe?.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: const ValueKey('webgl-fridge-scene'),
      viewType: _viewType,
    );
  }

  void _handleMessage(web.MessageEvent event) {
    if (event.origin != web.window.location.origin ||
        event.source != _iframe?.contentWindow ||
        !mounted) {
      return;
    }
    final raw = event.data;
    if (raw == null) {
      return;
    }
    final data = raw.dartify();
    if (data is! String) {
      return;
    }
    Object? payload;
    try {
      payload = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (payload is! Map<String, dynamic> ||
        payload['source'] != 'smart-fridge-3d') {
      return;
    }
    if (payload['type'] == 'ready') {
      _ready = true;
      _sendInputState();
      _sendInventory();
      if (widget.focus != null) _sendFocus();
      return;
    }
    if (!widget.interactive) return;
    if (payload['type'] == 'food-selected') {
      final foodId = payload['foodId'];
      if (foodId is! String || payload['revision'] != _inventoryRevision) {
        return;
      }
      final food = widget.foods
          .where((food) => food.id == foodId && food.quantity > 0)
          .firstOrNull;
      if (food != null) widget.onFoodSelected?.call(food);
      return;
    }
    if (payload['type'] != 'zone-selected' || payload['fromFlutter'] == true) {
      return;
    }
    final zone = _zoneFromWire(payload['zone']);
    if (zone != null) {
      widget.onZoneSelected(zone);
    }
  }

  void _sendInputState() {
    if (!_ready) return;
    _iframe?.contentWindow?.postMessage(
      jsonEncode({
        'type': 'smart-fridge-command',
        'action': 'setInteractive',
        'enabled': widget.interactive,
      }).toJS,
      web.window.location.origin.toJS,
    );
  }

  void _sendInventory() {
    if (!_ready) return;
    final stacks = groupFridgeStickers(widget.foods);
    _iframe?.contentWindow?.postMessage(
      jsonEncode({
        'type': 'smart-fridge-command',
        'action': 'inventory',
        'revision': ++_inventoryRevision,
        'foods': [
          for (final stack in stacks)
            {
              'id': stack.food.id,
              'name': stack.food.name,
              'artwork': stickerForFood(stack.food)?.imageName,
              'emoji': stack.food.emoji,
              'quantity': stack.food.quantity,
              'zone': stack.food.zone.name,
              'layers': stack.layers,
              'portions': stack.portionCount,
            },
        ],
      }).toJS,
      web.window.location.origin.toJS,
    );
  }

  void _sendFocus() {
    if (!_ready) {
      return;
    }
    final focus = widget.focus;
    final message = jsonEncode({
      'type': 'smart-fridge-command',
      'action': focus == null ? 'resetView' : 'focusZone',
      if (focus != null) 'zone': focus.zone.name,
    });
    _iframe?.contentWindow?.postMessage(
      message.toJS,
      web.window.location.origin.toJS,
    );
  }

  FridgeZoneId? _zoneFromWire(Object? value) {
    return switch (value) {
      'fresh' => FridgeZoneId.fresh,
      'variable' => FridgeZoneId.variable,
      'freezer' => FridgeZoneId.freezer,
      _ => null,
    };
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:web/web.dart' as web;

class WebGLFridgeView extends StatefulWidget {
  const WebGLFridgeView({
    required this.zone,
    required this.onZoneSelected,
    super.key,
  });

  final FridgeZoneId zone;
  final ValueChanged<FridgeZoneId> onZoneSelected;

  @override
  State<WebGLFridgeView> createState() => _WebGLFridgeViewState();
}

class _WebGLFridgeViewState extends State<WebGLFridgeView> {
  late final String _viewType;
  late final StreamSubscription<web.MessageEvent> _messageSubscription;
  web.HTMLIFrameElement? _iframe;
  bool _ready = false;
  FridgeZoneId? _sceneDrivenZone;

  @override
  void initState() {
    super.initState();
    _viewType = 'smart-fridge-webgl-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = 'fridge3d/index.html'
        ..title = '小满冰箱 WebGL 三维模型'
        ..setAttribute('allowtransparency', 'true')
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = 'transparent'
        ..style.overflow = 'hidden';
      iframe.onLoad.listen((_) {
        _ready = true;
      });
      _iframe = iframe;
      return iframe;
    });

    _messageSubscription = web.window.onMessage.listen(_handleMessage);
  }

  @override
  void didUpdateWidget(covariant WebGLFridgeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone != widget.zone) {
      if (_sceneDrivenZone == widget.zone) {
        _sceneDrivenZone = null;
        return;
      }
      _sendFocus(widget.zone);
    }
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
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
    if (event.origin != web.window.location.origin) {
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
    final payload = jsonDecode(data);
    if (payload is! Map<String, dynamic> ||
        payload['source'] != 'smart-fridge-3d') {
      return;
    }
    if (payload['type'] != 'zone-selected') {
      return;
    }
    final zone = _zoneFromWire(payload['zone']);
    if (zone != null) {
      _sceneDrivenZone = zone;
      widget.onZoneSelected(zone);
    }
  }

  void _sendFocus(FridgeZoneId zone) {
    if (!_ready) {
      return;
    }
    final message = jsonEncode({
      'type': 'smart-fridge-command',
      'action': 'focusZone',
      'zone': zone.name,
      'openPanel': true,
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
      'pantry' => FridgeZoneId.pantry,
      _ => null,
    };
  }
}

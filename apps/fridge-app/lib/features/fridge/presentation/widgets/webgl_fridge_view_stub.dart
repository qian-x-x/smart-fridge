import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';

class WebGLFridgeView extends StatelessWidget {
  const WebGLFridgeView({
    required this.zone,
    required this.onZoneSelected,
    super.key,
  });

  final FridgeZoneId zone;
  final ValueChanged<FridgeZoneId> onZoneSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '四门立式冰箱三维模型。当前为 Android 兼容视图。',
      child: CustomPaint(
        key: const ValueKey('webgl-fridge-fallback'),
        painter: _FridgeFallbackPainter(zone),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.paper.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'WebGL 3D 场景在 Web 端启用',
                style: TextStyle(
                  color: AppColors.cocoa,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FridgeFallbackPainter extends CustomPainter {
  const _FridgeFallbackPainter(this.zone);

  final FridgeZoneId zone;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyWidth = math.min(size.width * 0.62, 260.0);
    final bodyHeight = math.min(size.height * 0.82, 410.0);
    final rect = Rect.fromCenter(
      center: center.translate(0, -8),
      width: bodyWidth,
      height: bodyHeight,
    );

    final shadow = Paint()
      ..color = const Color(0x244F382E)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawOval(
      Rect.fromCenter(
        center: rect.bottomCenter.translate(24, 4),
        width: bodyWidth * 0.95,
        height: 32,
      ),
      shadow,
    );

    final side = Path()
      ..moveTo(rect.right - 2, rect.top + 18)
      ..lineTo(rect.right + 28, rect.top + 34)
      ..lineTo(rect.right + 28, rect.bottom - 9)
      ..lineTo(rect.right - 2, rect.bottom)
      ..close();
    canvas.drawPath(side, Paint()..color = const Color(0xFFAE9680));

    final body = RRect.fromRectAndRadius(rect, const Radius.circular(34));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4E5D6), Color(0xFFD8C0AA)],
        ).createShader(rect),
    );

    final doorLine = Paint()
      ..color = const Color(0x664F382E)
      ..strokeWidth = 1.2;
    final splitY = rect.top + bodyHeight * 0.52;
    canvas.drawLine(
      Offset(rect.center.dx, rect.top + 18),
      Offset(rect.center.dx, splitY),
      doorLine,
    );
    canvas.drawLine(
      Offset(rect.left + 16, splitY),
      Offset(rect.right - 16, splitY),
      doorLine,
    );
    canvas.drawLine(
      Offset(rect.left + 16, splitY + bodyHeight * 0.2),
      Offset(rect.right - 16, splitY + bodyHeight * 0.2),
      doorLine,
    );

    final selectedBand = switch (zone) {
      FridgeZoneId.fresh => Rect.fromLTRB(
        rect.left + 12,
        rect.top + 18,
        rect.center.dx - 3,
        splitY - 3,
      ),
      FridgeZoneId.pantry => Rect.fromLTRB(
        rect.center.dx + 3,
        rect.top + 18,
        rect.right - 12,
        splitY - 3,
      ),
      FridgeZoneId.variable => Rect.fromLTRB(
        rect.left + 12,
        splitY + 3,
        rect.right - 12,
        splitY + bodyHeight * 0.2 - 3,
      ),
      FridgeZoneId.freezer => Rect.fromLTRB(
        rect.left + 12,
        splitY + bodyHeight * 0.2 + 3,
        rect.right - 12,
        rect.bottom - 12,
      ),
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(selectedBand, const Radius.circular(26)),
      Paint()..color = AppColors.butter.withValues(alpha: 0.18),
    );

    final handlePaint = Paint()..color = AppColors.cocoa;
    final handleTop = rect.top + bodyHeight * 0.14;
    final handleHeight = bodyHeight * 0.25;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.center.dx - 10, handleTop, 7, handleHeight),
        const Radius.circular(6),
      ),
      handlePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.center.dx + 3, handleTop, 7, handleHeight),
        const Radius.circular(6),
      ),
      handlePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rect.center.dx, splitY + 21),
          width: 74,
          height: 7,
        ),
        const Radius.circular(8),
      ),
      handlePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rect.center.dx, splitY + bodyHeight * 0.2 + 23),
          width: 88,
          height: 7,
        ),
        const Radius.circular(8),
      ),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FridgeFallbackPainter oldDelegate) {
    return oldDelegate.zone != zone;
  }
}

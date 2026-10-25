import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/webgl_fridge_view.dart';

class FridgeScene extends StatelessWidget {
  const FridgeScene({
    required this.zones,
    required this.selectedZone,
    required this.onZoneSelected,
    super.key,
  });

  final List<FridgeZone> zones;
  final FridgeZoneId selectedZone;
  final ValueChanged<FridgeZoneId> onZoneSelected;

  @override
  Widget build(BuildContext context) {
    final zone = zones.firstWhere((item) => item.id == selectedZone);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final stageHeight = compact ? 420.0 : 620.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 72,
              child: ListView.separated(
                key: const ValueKey('fridge-zone-selector'),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: zones.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final item = zones[index];
                  return _ZoneSelector(
                    zone: item,
                    active: item.id == selectedZone,
                    onTap: () => onZoneSelected(item.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: stageHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFBF7F0), Color(0xFFEDE4D8)],
                  ),
                  borderRadius: BorderRadius.circular(compact ? 26 : 34),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x175B4336),
                      blurRadius: 34,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(compact ? 26 : 34),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _StageBackdrop(),
                      WebGLFridgeView(
                        zone: selectedZone,
                        onZoneSelected: onZoneSelected,
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: _WebGLBadge(compact: compact),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _DragHint(compact: compact),
                      ),
                      if (!compact)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: _SceneCaption(zone: zone, compact: false),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZoneSelector extends StatelessWidget {
  const _ZoneSelector({
    required this.zone,
    required this.active,
    required this.onTap,
  });

  final FridgeZone zone;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      label: '${zone.name}区，${zone.temperature}',
      child: Material(
        color: active
            ? AppColors.cocoa
            : AppColors.paper.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: 116,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? AppColors.cocoa : AppColors.linen,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.cream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(zone.emoji, style: const TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? AppColors.cream : AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        zone.temperature,
                        style: TextStyle(
                          color: active
                              ? AppColors.cream.withValues(alpha: 0.62)
                              : AppColors.cocoa.withValues(alpha: 0.56),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: -40,
          top: -70,
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              color: Color(0x42E8D6C4),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -72,
          bottom: -70,
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              color: Color(0x3DDDE8DC),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.28),
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.58),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WebGLBadge extends StatelessWidget {
  const _WebGLBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            compact ? 'WEBGL' : 'WEBGL 真 3D',
            style: const TextStyle(
              color: AppColors.cocoa,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHint extends StatelessWidget {
  const _DragHint({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const Icon(
        Icons.threesixty_rounded,
        color: AppColors.cocoa,
        size: 22,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.threesixty_rounded, color: AppColors.cocoa, size: 18),
        const SizedBox(width: 6),
        Text(
          '拖动旋转 · 点击开门',
          style: TextStyle(
            color: AppColors.cocoa.withValues(alpha: 0.62),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SceneCaption extends StatelessWidget {
  const _SceneCaption({required this.zone, required this.compact});

  final FridgeZone zone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 13 : 16,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x155B4336),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(zone.emoji, style: const TextStyle(fontSize: 21)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${zone.name} · ${zone.temperature}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  zone.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.cocoa.withValues(alpha: 0.56),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            Text(
              '点击模型切换',
              style: TextStyle(
                color: AppColors.sage.withValues(alpha: 0.92),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

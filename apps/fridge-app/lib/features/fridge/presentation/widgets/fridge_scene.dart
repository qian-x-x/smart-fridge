import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_sticker.dart';

class FridgeScene extends StatelessWidget {
  const FridgeScene({
    required this.zones,
    required this.foods,
    required this.selectedZone,
    required this.onZoneSelected,
    required this.onFoodTap,
    super.key,
  });

  final List<FridgeZone> zones;
  final List<FridgeFood> foods;
  final FridgeZoneId selectedZone;
  final ValueChanged<FridgeZoneId> onZoneSelected;
  final ValueChanged<FridgeFood> onFoodTap;

  @override
  Widget build(BuildContext context) {
    final zone = zones.firstWhere((item) => item.id == selectedZone);
    final zoneFoods = foods.where((food) => food.zone == selectedZone).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 82,
          child: ListView.separated(
            key: const ValueKey('fridge-zone-selector'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: zones.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final item = zones[index];
              final active = item.id == selectedZone;
              return Semantics(
                selected: active,
                button: true,
                label: '${item.name}区，${item.temperature}',
                child: GestureDetector(
                  onTap: () => onZoneSelected(item.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: 112,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.cocoa : AppColors.paper,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppColors.cocoa : AppColors.linen,
                      ),
                      boxShadow: active
                          ? const [
                              BoxShadow(
                                color: Color(0x265B4336),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 21)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  color: active
                                      ? AppColors.cream
                                      : AppColors.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.temperature,
                                style: TextStyle(
                                  color: active
                                      ? AppColors.cream.withValues(alpha: 0.65)
                                      : AppColors.cocoa.withValues(alpha: 0.58),
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
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxWidth < 420 ? 440.0 : 490.0;
            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 18,
                    right: 2,
                    bottom: 18,
                    width: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFB89E86),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEADAC9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 18,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFEBD9C7), Color(0xFFD8BEA5)],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFFF8EEE2),
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x225B4336),
                            blurRadius: 34,
                            offset: Offset(18, 22),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 19,
                            top: 62,
                            child: Container(
                              width: 7,
                              height: 103,
                              decoration: BoxDecoration(
                                color: AppColors.cocoa,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x335B4336),
                                    blurRadius: 7,
                                    offset: Offset(3, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 44,
                            top: 44,
                            height: 2,
                            child: ColoredBox(
                              color: AppColors.cocoa.withValues(alpha: 0.16),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 48,
                            top: 56,
                            bottom: 18,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFF9F5EC),
                                      Color(0xFFE8F0E5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFB99F88),
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    const Positioned(
                                      left: 16,
                                      top: 13,
                                      child: _CavityLabel(),
                                    ),
                                    Positioned(
                                      left: 16,
                                      right: 16,
                                      top: 48,
                                      child: _ZoneCaption(zone: zone),
                                    ),
                                    Positioned(
                                      left: 18,
                                      right: 18,
                                      bottom: 22,
                                      child: AnimatedSlide(
                                        offset: const Offset(0, 0),
                                        duration: const Duration(
                                          milliseconds: 340,
                                        ),
                                        curve: Curves.easeOutBack,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 340,
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            18,
                                            16,
                                            16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.paper.withValues(
                                              alpha: 0.92,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              21,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x24302822),
                                                blurRadius: 20,
                                                offset: Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: zoneFoods.isEmpty
                                              ? const _EmptyZone()
                                              : Wrap(
                                                  alignment:
                                                      WrapAlignment.center,
                                                  spacing: 8,
                                                  runSpacing: 10,
                                                  children: [
                                                    for (final food
                                                        in zoneFoods)
                                                      FoodSticker(
                                                        key: ValueKey(food.id),
                                                        food: food,
                                                        onTap: () =>
                                                            onFoodTap(food),
                                                      ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 18,
                                      right: 18,
                                      bottom: 10,
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: AppColors.cocoa.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 28,
                            top: 17,
                            child: _FridgeBrand(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 30,
                    right: 54,
                    bottom: -12,
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.cocoa.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CavityLabel extends StatelessWidget {
  const _CavityLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cocoa.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.ac_unit_rounded, size: 13, color: AppColors.sage),
          SizedBox(width: 4),
          Text(
            '今日 4°C',
            style: TextStyle(
              color: AppColors.sage,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneCaption extends StatelessWidget {
  const _ZoneCaption({required this.zone});

  final FridgeZone zone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(zone.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${zone.name} · ${zone.temperature}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                zone.description,
                style: TextStyle(
                  color: AppColors.cocoa.withValues(alpha: 0.58),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyZone extends StatelessWidget {
  const _EmptyZone();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('🧺', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text(
            '这一层还空着',
            style: TextStyle(
              color: AppColors.cocoa,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FridgeBrand extends StatelessWidget {
  const _FridgeBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.kitchen_rounded, size: 16, color: AppColors.cocoa),
        SizedBox(width: 4),
        Text(
          'MANMAN',
          style: TextStyle(
            color: AppColors.cocoa,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

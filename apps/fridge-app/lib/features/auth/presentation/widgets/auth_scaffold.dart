import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6EEE3), AppColors.cream, Color(0xFFE8EDE6)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: -110,
                right: -80,
                child: _SoftCircle(size: 280, color: Color(0x55D7B49A)),
              ),
              const Positioned(
                bottom: -120,
                left: -90,
                child: _SoftCircle(size: 320, color: Color(0x5570866A)),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 880;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 64 : 24,
                      vertical: wide ? 48 : 28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - (wide ? 96 : 56),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: wide
                              ? Row(
                                  children: [
                                    const Expanded(child: _BrandStory()),
                                    const SizedBox(width: 72),
                                    SizedBox(
                                      width: 430,
                                      child: _FormCard(
                                        title: title,
                                        subtitle: subtitle,
                                        child: child,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _CompactBrand(),
                                    const SizedBox(height: 28),
                                    _FormCard(
                                      title: title,
                                      subtitle: subtitle,
                                      child: child,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 44,
          height: compact ? 38 : 44,
          decoration: BoxDecoration(
            color: AppColors.cocoa,
            borderRadius: BorderRadius.circular(compact ? 13 : 15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x245B4336),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.kitchen_rounded,
            color: AppColors.cream,
            size: compact ? 21 : 25,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '小满冰箱',
          style: TextStyle(
            color: AppColors.cocoa,
            fontSize: compact ? 19 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _BrandStory extends StatelessWidget {
  const _BrandStory();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(height: 52),
        Text(
          '把家的味道，\n好好放进去。',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 56, color: AppColors.cocoa),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Text(
            '一眼看见冰箱里的每一份食材，和家人一起决定今晚吃什么。'
            '临期先吃、缺什么再补，生活少一点仓促。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.cocoa.withValues(alpha: 0.78),
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(height: 34),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FeaturePill(icon: Icons.auto_awesome_rounded, label: '食材可视化'),
            _FeaturePill(icon: Icons.soup_kitchen_rounded, label: '灵感菜谱'),
            _FeaturePill(icon: Icons.family_restroom_rounded, label: '家庭共享'),
          ],
        ),
        const SizedBox(height: 46),
        const _MiniFridge(),
      ],
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(compact: true),
        const SizedBox(height: 20),
        Text(
          '把家的味道，\n好好放进去。',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 38, color: AppColors.cocoa),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x185B4336),
            blurRadius: 42,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.cocoa.withValues(alpha: 0.68)),
          ),
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.terracotta),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.cocoa,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFridge extends StatelessWidget {
  const _MiniFridge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 132,
              height: 172,
              decoration: BoxDecoration(
                color: const Color(0xFFE3CDB8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF4E5D5), width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x225B4336),
                    blurRadius: 22,
                    offset: Offset(12, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 6,
                    height: 35,
                    decoration: BoxDecoration(
                      color: AppColors.cocoa,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 106,
                    height: 2,
                    color: AppColors.cocoa.withValues(alpha: 0.24),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MiniFood(emoji: '🥬', angle: -0.08),
                        _MiniFood(emoji: '🥛', angle: 0.05),
                        _MiniFood(emoji: '🍓', angle: -0.04),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const Positioned(
              right: -170,
              bottom: 24,
              child: _SpeechNote(title: '今晚吃点什么？', detail: '西红柿和鸡蛋都快到期啦'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniFood extends StatelessWidget {
  const _MiniFood({required this.emoji, required this.angle});

  final String emoji;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 31,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 19)),
      ),
    );
  }
}

class _SpeechNote extends StatelessWidget {
  const _SpeechNote({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x155B4336),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: TextStyle(
              color: AppColors.cocoa.withValues(alpha: 0.7),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

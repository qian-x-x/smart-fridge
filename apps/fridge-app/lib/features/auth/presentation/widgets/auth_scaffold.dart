import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/config/app_brand.dart';
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 940;
          final form = Container(
            decoration: wide
                ? BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  )
                : null,
            padding: EdgeInsets.all(wide ? 42 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandMark(),
                const SizedBox(height: 10),
                const Text(
                  AppBrand.tagline,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 30),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, height: 1.6),
                ),
                const SizedBox(height: 28),
                child,
              ],
            ),
          );
          final art = ClipRRect(
            borderRadius: BorderRadius.circular(wide ? 28 : 0),
            child: Image.asset(
              AppBrand.kitchenImage,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              semanticLabel: '暖橙厨房外观概念图',
            ),
          );
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: wide
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Row(
                            children: [
                              Expanded(flex: 5, child: form),
                              const SizedBox(width: 26),
                              Expanded(
                                flex: 6,
                                child: SizedBox(height: 720, child: art),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: title.contains('创建') ? 160 : 210,
                              child: art,
                            ),
                            form,
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.kitchen_outlined, color: AppColors.terracotta, size: 32),
      const SizedBox(width: 11),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppBrand.name,
            style: TextStyle(
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const Text(
            AppBrand.englishName,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    ],
  );
}

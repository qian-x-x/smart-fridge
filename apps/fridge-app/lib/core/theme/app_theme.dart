import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF4F6F7);
  static const cool = Color(0xFFEAF0F3);
  static const control = Color(0xFF85919B);
  static const focus = Color(0xFF344F66);
  // Legacy aliases keep the existing business widgets compatible with V2.0.
  static const cream = canvas;
  static const paper = Color(0xFFFFFFFF);
  static const linen = cool;
  static const sand = control;
  static const ink = Color(0xFF171A1D);
  static const cocoa = ink;
  static const terracotta = ink;
  static const peach = cool;
  static const sage = Color(0xFF345E50);
  static const butter = cool;
  static const rose = Color(0xFF963D45);
  static const mint = cool;
  static const muted = Color(0xFF59636D);
  static const border = Color(0xFFDCE2E6);
  static const wood = focus;
  static const warning = Color(0xFF735522);
}

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.terracotta,
      onPrimary: Colors.white,
      primaryContainer: AppColors.mint,
      onPrimaryContainer: AppColors.terracotta,
      secondary: AppColors.terracotta,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.linen,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.wood,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.control,
      outlineVariant: AppColors.border,
      surfaceContainerHighest: AppColors.cream,
      error: AppColors.rose,
      surfaceTint: Colors.transparent,
    );
    final text = ThemeData.light().textTheme.apply(
      fontFamily: 'XiaoyiUI',
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.control),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'XiaoyiUI',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: -1,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 30,
          letterSpacing: -0.6,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: const TextStyle(color: AppColors.focus),
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.focus, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.rose),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: shape,
              textStyle: const TextStyle(
                fontFamily: 'XiaoyiUI',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              animationDuration: const Duration(milliseconds: 120),
              elevation: 0,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFFE8ECEF);
                }
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xFF080B0E);
                }
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0xFF30363C);
                }
                return AppColors.ink;
              }),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? const Color(0xFF77818A)
                    : Colors.white,
              ),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? AppColors.focus
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: shape,
          side: const BorderSide(color: AppColors.control),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.mint,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'XiaoyiUI',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? AppColors.terracotta
                : AppColors.muted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.terracotta,
        labelStyle: const TextStyle(fontFamily: 'XiaoyiUI', fontSize: 13),
        secondarySelectedColor: AppColors.ink,
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: const BorderSide(color: AppColors.control),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

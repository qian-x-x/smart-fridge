import 'package:flutter/material.dart';

abstract final class AppColors {
  static const cream = Color(0xFFFCF5E9);
  static const paper = Color(0xFFFFFFFF);
  static const linen = Color(0xFFF6E6D5);
  static const sand = Color(0xFF9A8170);
  static const cocoa = Color(0xFF442B22);
  static const ink = Color(0xFF442B22);
  static const terracotta = Color(0xFFBC4D30);
  static const peach = Color(0xFFEBC4A2);
  static const sage = Color(0xFF526A45);
  static const butter = Color(0xFFFFF0C9);
  static const rose = Color(0xFFAC3D35);
  static const mint = Color(0xFFF6E6D5);
  static const muted = Color(0xFF806A5C);
  static const border = Color(0xFFECDFCF);
  static const wood = Color(0xFFAE825A);
  static const warning = Color(0xFF946017);
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
      outline: AppColors.border,
      surfaceContainerHighest: AppColors.cream,
      error: AppColors.rose,
    );
    final text = ThemeData.light().textTheme.apply(
      fontFamily: 'XiaoyiUI',
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
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
        floatingLabelStyle: const TextStyle(color: AppColors.terracotta),
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5),
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
              elevation: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered) ? 3 : 0,
              ),
              shadowColor: const WidgetStatePropertyAll(Color(0x40BC4D30)),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: shape,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
            fontSize: 11,
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
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

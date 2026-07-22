// lib/core/theme/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:litreview_app/core/constants/app_colors.dart';

ThemeData buildAppTheme() {
  // Create color scheme from our custom colors
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    tertiary: AppColors.tertiary,
    onTertiary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    background: AppColors.background,
    onBackground: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
  );

  // Use Inter font for modern tech look
  final textTheme = GoogleFonts.interTextTheme().copyWith(
    displayLarge: GoogleFonts.inter(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: AppColors.textPrimary,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: AppColors.textPrimary,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: AppColors.textPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    
    // AppBar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),

    // Card Theme
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
    ),

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: AppColors.primary),
        foregroundColor: AppColors.primary,
        textStyle: textTheme.labelLarge?.copyWith(color: AppColors.primary),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        foregroundColor: AppColors.primary,
        textStyle: textTheme.labelLarge?.copyWith(color: AppColors.primary),
      ),
    ),

    // Input Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMedium,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      backgroundColor: AppColors.surfaceMedium,
      selectedColor: AppColors.primary.withOpacity(0.1),
      labelStyle: textTheme.labelLarge,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // Dialog Theme
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyLarge,
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 0,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 24,
    ),

    // Scaffold Background Color
    scaffoldBackgroundColor: AppColors.background,
  );
}

import 'package:flutter/material.dart';

class AppColors {
  // Primary gradient colors
  static const lightBlue = Color(0xFFE0F4FF);
  static const lightPurple = Color(0xFFF1E6FF);
  static const lightPink = Color(0xFFFFE6F1);

  // Container and card colors (lighter versions)
  static const containerBlue = Color(0xFFF0F9FF);
  static const containerPurple = Color(0xFFF8F2FF);
  static const containerPink = Color(0xFFFFF2F8);

  // Accent colors
  static const accentBlue = Color(0xFF4A90E2);
  static const accentPurple = Color(0xFF9C6ADE);
  static const accentPink = Color(0xFFE268A7);

  // Dark elements
  static const darkBlue = Color(0xFF1E3D59);
  static const darkPurple = Color(0xFF4A2B5F);
  static const darkPink = Color(0xFF8E2C54);

  // Text colors
  static const primaryText = Color(0xFF1A1A1A);
  static const secondaryText = Color(0xFF4D4D4D);
  static const tertiaryText = Color(0xFF808080);

  // Glassmorphic effect colors
  static const glassLight = Color(0x1AFFFFFF);
  static const glassMedium = Color(0x26FFFFFF);
  static const glassDark = Color(0x40FFFFFF);

  /// Surface color for dropdowns and other containers
  static const Color surfaceColor = Color(0xFF1E1E2E);

  // Gradient definitions
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEEF2FF),
      Color(0xFFF7F9FF),
      Color(0xFFF8F0FF),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static final backgroundGradientTop = RadialGradient(
    center: Alignment(-1, 0.8),
    radius: 15,
    tileMode: TileMode.mirror,
    colors: [
      lightPink.withOpacity(0.5),
      
      
      
      lightBlue.withOpacity(0.5),
      
      
      
      
      lightPink.withOpacity(0.5),
      
    ],
    stops: [0.0,0.5,1],

  );

  static const topBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFF0F9FF),
      Color(0xFFF8F2FF),
      Color(0xFFFFF2F8),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Glassmorphic container decoration
  static BoxDecoration glassDecoration = BoxDecoration(
    color: glassLight,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: glassMedium,
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: glassDark,
        blurRadius: 16,
        spreadRadius: 4,
      ),
    ],
  );
} 
// lib/core/constants/app_spacing.dart
import 'package:flutter/material.dart';

class AppSpacing {
  // Base spacing unit (4px)
  static const double base = 4.0;

  // Core spacing values
  static const double xs = base;           // 4
  static const double sm = base * 2;       // 8
  static const double md = base * 4;       // 16
  static const double lg = base * 6;       // 24
  static const double xl = base * 8;       // 32
  static const double xxl = base * 12;     // 48
  static const double xxxl = base * 16;    // 64

  // Layout specific spacing
  static const double layoutGutter = md;   // 16
  static const double layoutMargin = lg;   // 24
  static const double sectionSpacing = xl; // 32
  static const double pageSpacing = xxl;   // 48

  // Component specific spacing
  static const double cardPadding = md;    // 16
  static const double buttonSpacing = sm;  // 8
  static const double iconSpacing = sm;    // 8
  static const double inputPadding = sm;   // 8

  // Grid system
  static const double gridGap = md;        // 16
  static const double gridMargin = lg;     // 24

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  // Get dynamic spacing based on screen size
  static double getResponsiveSpacing(double baseSpacing, BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return baseSpacing * 0.8; // Slightly smaller on mobile
    } else if (width < tabletBreakpoint) {
      return baseSpacing; // Normal size on tablet
    } else {
      return baseSpacing * 1.2; // Slightly larger on desktop
    }
  }

  // Get dynamic margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.all(md);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.all(lg);
    } else {
      return const EdgeInsets.all(xl);
    }
  }

  // Get dynamic padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.all(sm);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.all(md);
    } else {
      return const EdgeInsets.all(lg);
    }
  }
}

import 'package:flutter/material.dart';

class AppAnimations {
  // Duration constants
  static const Duration fastest = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 750);

  // Curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;
  static const Curve decelerateCurve = Curves.easeOutExpo;
  static const Curve accelerateCurve = Curves.easeInExpo;
  static const Curve bounceCurve = Curves.elasticOut;

  // Offset constants for slide animations
  static const Offset slideInOffset = Offset(0.0, 0.05);
  static const Offset slideOutOffset = Offset(0.0, -0.05);

  // Scale constants for scale animations
  static const double scaleMin = 0.95;
  static const double scaleMax = 1.05;

  // Opacity constants
  static const double fadeMin = 0.0;
  static const double fadeMax = 1.0;

  // Stagger intervals
  static const Duration staggerDuration = Duration(milliseconds: 50);
} 
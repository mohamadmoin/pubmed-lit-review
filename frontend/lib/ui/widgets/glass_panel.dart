import 'dart:ui';

import 'package:flutter/material.dart';

/// Lightweight glass-style panel (replaces glass_kit for web builds).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.height,
    this.width,
    this.borderRadius,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.3),
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Backwards-compatible alias for existing call sites.
class GlassContainer {
  GlassContainer._();

  static Widget clearGlass({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double? height,
    double? width,
    BorderRadius? borderRadius,
    Color? color,
    Color? borderColor,
    double elevation = 0,
    double blur = 0,
    LinearGradient? borderGradient,
  }) {
    return GlassPanel(
      padding: padding,
      height: height,
      width: width,
      borderRadius: borderRadius,
      color: color,
      borderColor: borderColor,
      child: child,
    );
  }
}

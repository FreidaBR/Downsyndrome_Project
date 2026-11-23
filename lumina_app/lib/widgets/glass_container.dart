import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final bool isDark;
  final double blurSigma;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    required this.isDark,
    this.blurSigma = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = BorderRadius.circular(20.0);
    final currentRadius = borderRadius ?? defaultRadius;

    // Resolve colors
    final Color surfaceColor = isDark
        ? LuminaColors.darkSurface
        : LuminaColors.lightSurface;
    
    final Color borderColor = isDark
        ? LuminaColors.darkSurfaceB
        : LuminaColors.lightSurfaceB;

    final Color shadowColor = isDark
        ? LuminaColors.darkShadow
        : LuminaColors.lightShadow;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: currentRadius,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 70.0,
            offset: const Offset(0, 30),
            spreadRadius: -10.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: currentRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: currentRadius,
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

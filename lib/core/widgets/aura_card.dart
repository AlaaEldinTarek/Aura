import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AuraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;
  final double radius;
  final bool shadow;
  final VoidCallback? onTap;

  const AuraCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.radius = AppConstants.radiusLarge,
    this.shadow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? AppConstants.card(isDark);
    final effectiveBorder = borderColor ?? AppConstants.border(isDark);
    final effectivePadding =
        padding ?? const EdgeInsets.all(AppConstants.paddingMedium);

    final decoration = BoxDecoration(
      color: effectiveColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: effectiveBorder,
        width: borderWidth ?? 1.0,
      ),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: effectivePadding, child: child),
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      padding: effectivePadding,
      decoration: decoration,
      child: child,
    );
  }
}

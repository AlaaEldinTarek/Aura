import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// A reusable card widget with consistent theming across the app
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardContent = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: borderRadius ?? BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(AppConstants.radiusMedium),
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// Small card with minimal padding - perfect for status indicators
  static Widget small({
    required Widget child,
    Key? key,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      margin: margin,
      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      onTap: onTap,
      child: child,
    );
  }

  /// Medium card with standard padding - perfect for most content
  static Widget medium({
    required Widget child,
    Key? key,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }

  /// Large card with more padding - perfect for feature placeholders
  static Widget large({
    required Widget child,
    Key? key,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      margin: margin,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      onTap: onTap,
      child: child,
    );
  }
}

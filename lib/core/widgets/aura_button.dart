import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_typography.dart';

enum AuraButtonVariant { primary, secondary, ghost }

class AuraButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AuraButtonVariant variant;
  final Widget? icon;
  final bool loading;
  final bool expanded;
  final double? verticalPadding;
  final double? fontSize;

  const AuraButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AuraButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.verticalPadding,
    this.fontSize,
  });

  const AuraButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.verticalPadding,
    this.fontSize,
  }) : variant = AuraButtonVariant.secondary;

  const AuraButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.verticalPadding,
    this.fontSize,
  }) : variant = AuraButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final vPad = verticalPadding ?? 14.0;
    final labelStyle = (fontSize != null
            ? AppTypography.bodyM.copyWith(fontSize: fontSize)
            : AppTypography.bodyM)
        .copyWith(fontWeight: FontWeight.bold);

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AuraButtonVariant.primary
                  ? (isDark ? Colors.black : Colors.white)
                  : primary,
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon!,
                  const SizedBox(width: AppConstants.paddingSmall),
                  Text(label, style: labelStyle),
                ],
              )
            : Text(label, style: labelStyle);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
    );
    final padding = EdgeInsets.symmetric(
      horizontal: AppConstants.paddingLarge,
      vertical: vPad,
    );

    Widget button;
    switch (variant) {
      case AuraButtonVariant.primary:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: isDark ? Colors.black : Colors.white,
            disabledBackgroundColor: primary.withValues(alpha: 0.5),
            shape: shape,
            padding: padding,
            elevation: 0,
          ),
          child: child,
        );
      case AuraButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary.withValues(alpha: 0.5)),
            shape: shape,
            padding: padding,
          ),
          child: child,
        );
      case AuraButtonVariant.ghost:
        button = TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: primary,
            shape: shape,
            padding: padding,
          ),
          child: child,
        );
    }

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

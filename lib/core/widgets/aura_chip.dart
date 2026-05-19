import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_typography.dart';

enum AuraChipVariant { filled, outlined, filter }

class AuraChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AuraChipVariant variant;
  final Color? color;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool selected;
  final bool pill;

  const AuraChip({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AuraChipVariant.filter,
    this.color,
    this.leadingIcon,
    this.trailingIcon,
    this.selected = false,
    this.pill = true,
  });

  const AuraChip.filled({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.leadingIcon,
    this.trailingIcon,
    this.selected = false,
    this.pill = true,
  }) : variant = AuraChipVariant.filled;

  const AuraChip.outlined({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.leadingIcon,
    this.trailingIcon,
    this.selected = false,
    this.pill = true,
  }) : variant = AuraChipVariant.outlined;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final accent = color ?? primary;
    final radius = pill ? 20.0 : AppConstants.radiusMedium.toDouble();

    Color bgColor;
    Color borderColor;
    Color textColor;

    switch (variant) {
      case AuraChipVariant.filled:
        bgColor = accent.withValues(alpha: 0.15);
        borderColor = Colors.transparent;
        textColor = accent;
      case AuraChipVariant.outlined:
        bgColor = Colors.transparent;
        borderColor = accent.withValues(alpha: 0.5);
        textColor = accent;
      case AuraChipVariant.filter:
        bgColor = selected
            ? accent.withValues(alpha: 0.15)
            : AppConstants.card(isDark);
        borderColor = selected
            ? accent
            : AppConstants.border(isDark);
        textColor = selected ? accent : AppConstants.textMuted(isDark);
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          leadingIcon!,
          const SizedBox(width: AppConstants.gap4),
        ],
        Text(
          label,
          style: AppTypography.labelS.copyWith(
            color: textColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppConstants.gap4),
          trailingIcon!,
        ],
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animationDurationShort,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.gap12,
          vertical: AppConstants.gap4,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        child: content,
      ),
    );
  }
}

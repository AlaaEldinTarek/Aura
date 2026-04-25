import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// A beautiful, reusable settings tile with consistent styling
class SettingTile extends StatelessWidget {
  final IconData? icon;
  final String? iconEmoji;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showChevron;

  const SettingTile({
    super.key,
    this.icon,
    this.iconEmoji,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showChevron = true,
  }) : assert(icon != null || iconEmoji != null, 'Either icon or iconEmoji must be provided');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRTL = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppConstants.darkBorder.withOpacity(0.3) : AppConstants.lightBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingMedium,
            ),
            child: Row(
              children: [
                // Icon
                if (icon != null)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppConstants.primaryColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppConstants.primaryColor,
                      size: 20,
                    ),
                  )
                else if (iconEmoji != null)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        iconEmoji!,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                const SizedBox(width: AppConstants.paddingMedium),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing widget
                if (trailing != null) trailing!,

                // Chevron
                if (showChevron && onTap != null && trailing == null)
                  Icon(
                    isRTL ? Icons.chevron_left : Icons.chevron_right,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings tile with a switch
class SettingTileSwitch extends StatelessWidget {
  final IconData? icon;
  final String? iconEmoji;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;

  const SettingTileSwitch({
    super.key,
    this.icon,
    this.iconEmoji,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.iconColor,
  }) : assert(icon != null || iconEmoji != null, 'Either icon or iconEmoji must be provided');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppConstants.darkBorder.withOpacity(0.3) : AppConstants.lightBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onChanged != null ? () => onChanged!(!value) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingMedium,
            ),
            child: Row(
              children: [
                // Icon
                if (icon != null)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppConstants.primaryColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppConstants.primaryColor,
                      size: 20,
                    ),
                  )
                else if (iconEmoji != null)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        iconEmoji!,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                const SizedBox(width: AppConstants.paddingMedium),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Switch
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppConstants.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grouped settings section header
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMedium,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
        AppConstants.paddingSmall,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: AppConstants.primaryColor,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

/// Settings card container with grouped settings
class SettingsCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const SettingsCard({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingMedium,
                AppConstants.paddingMedium,
                AppConstants.paddingMedium,
                AppConstants.paddingSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppConstants.darkBorder.withOpacity(0.3) : AppConstants.lightBorder.withOpacity(0.3),
            ),
          ],
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

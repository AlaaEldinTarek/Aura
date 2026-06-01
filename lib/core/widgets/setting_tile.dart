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

    final ts = MediaQuery.textScalerOf(context);
    final iconContSz = ts.scale(40.0);
    final iconSz = ts.scale(20.0);
    final emojiFontSz = ts.scale(22.0);
    final tileH = ts.scale(AppConstants.paddingMedium);
    final tileHPad = ts.scale(AppConstants.paddingMedium);
    final iconGap = ts.scale(AppConstants.paddingMedium);
    final chevronSz = ts.scale(20.0);

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
            padding: EdgeInsets.symmetric(horizontal: tileHPad, vertical: tileH),
            child: Row(
              children: [
                // Icon
                if (icon != null)
                  Container(
                    width: iconContSz,
                    height: iconContSz,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppConstants.getPrimary(isDark)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppConstants.getPrimary(isDark),
                      size: iconSz,
                    ),
                  )
                else if (iconEmoji != null)
                  Container(
                    width: iconContSz,
                    height: iconContSz,
                    decoration: BoxDecoration(
                      color: AppConstants.getPrimary(isDark).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        iconEmoji!,
                        style: TextStyle(fontSize: emojiFontSz),
                      ),
                    ),
                  ),
                SizedBox(width: iconGap),

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
                    size: chevronSz,
                    color: AppConstants.textDisabled(isDark),
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
    final ts = MediaQuery.textScalerOf(context);
    final iconContSz = ts.scale(40.0);
    final iconSz = ts.scale(20.0);
    final emojiFontSz = ts.scale(22.0);

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
            padding: EdgeInsets.symmetric(
              horizontal: ts.scale(AppConstants.paddingMedium),
              vertical: ts.scale(AppConstants.paddingMedium),
            ),
            child: Row(
              children: [
                // Icon
                if (icon != null)
                  Container(
                    width: iconContSz,
                    height: iconContSz,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppConstants.getPrimary(isDark)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppConstants.getPrimary(isDark),
                      size: iconSz,
                    ),
                  )
                else if (iconEmoji != null)
                  Container(
                    width: iconContSz,
                    height: iconContSz,
                    decoration: BoxDecoration(
                      color: AppConstants.getPrimary(isDark).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        iconEmoji!,
                        style: TextStyle(fontSize: emojiFontSz),
                      ),
                    ),
                  ),
                SizedBox(width: ts.scale(AppConstants.paddingMedium)),

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
                  activeColor: AppConstants.getPrimary(isDark),
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
    final ts = MediaQuery.textScalerOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ts.scale(AppConstants.paddingMedium),
        ts.scale(AppConstants.paddingLarge),
        ts.scale(AppConstants.paddingMedium),
        ts.scale(AppConstants.paddingSmall),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: ts.scale(18.0),
              color: AppConstants.getPrimary(isDark),
            ),
            SizedBox(width: ts.scale(AppConstants.paddingSmall)),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.getPrimary(isDark),
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
        color: AppConstants.card(isDark),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppConstants.border(isDark),
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

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// A beautiful empty state widget for when there's no data
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String? iconEmoji;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon,
    this.iconEmoji,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : assert(icon != null || iconEmoji != null, 'Either icon or iconEmoji must be provided');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with background
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppConstants.getPrimary(isDark).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: icon != null
                    ? Icon(
                        icon,
                        size: 48,
                        color: AppConstants.getPrimary(isDark).withOpacity(0.5),
                      )
                    : Text(
                        iconEmoji!,
                        style: const TextStyle(fontSize: 48),
                      ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingSmall),

            // Subtitle
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                textAlign: TextAlign.center,
              ),

            // Action Button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppConstants.paddingLarge),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.getPrimary(isDark),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLarge,
                    vertical: AppConstants.paddingMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state with shimmer skeleton
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

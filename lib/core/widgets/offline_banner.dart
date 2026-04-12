import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../providers/connectivity_provider.dart';
import '../providers/auth_provider.dart';
import '../services/offline_queue_service.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final user = ref.watch(currentUserProvider);

    // Only show banner for logged-in users who are offline
    final shouldShow = !isOnline && user != null;

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final pendingCount = OfflineQueueService.instance.pendingCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: AppConstants.warning,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? '${'offline_mode'.tr()} (${pendingCount} pending)'
                  : 'offline_mode'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.sync,
            color: Colors.white70,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// Wrapper widget to add offline banner to any screen
// Note: For scrollable content, consider adding banner directly to screen instead
class ConnectivityWrapper extends ConsumerWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final user = ref.watch(currentUserProvider);
    final shouldShowBanner = !isOnline && user != null;

    // If no banner needed, return child as-is
    if (!shouldShowBanner) {
      return child;
    }

    // Use Column with proper constraints
    return Column(
      children: [
        const OfflineBanner(),
        // Use Expanded to give child remaining space
        Expanded(
          child: child,
        ),
      ],
    );
  }
}

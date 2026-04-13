import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prayer_record.dart';
import '../services/prayer_tracking_service.dart';
import 'auth_provider.dart';

/// Cached daily prayer status - shared between home and prayer screens
class DailyPrayerStatus {
  final Map<String, PrayerStatus> statuses;
  final DateTime loadedAt;

  const DailyPrayerStatus({
    this.statuses = const {},
    required this.loadedAt,
  });

  bool get isStale {
    // Refresh if older than 30 seconds, or if day changed
    final now = DateTime.now();
    final loadedDay = DateTime(loadedAt.year, loadedAt.month, loadedAt.day);
    final today = DateTime(now.year, now.month, now.day);
    if (loadedDay != today) return true;
    return now.difference(loadedAt).inSeconds > 30;
  }

  DailyPrayerStatus copyWith(Map<String, PrayerStatus> newStatuses) {
    return DailyPrayerStatus(
      statuses: newStatuses,
      loadedAt: DateTime.now(),
    );
  }
}

class DailyPrayerStatusNotifier extends StateNotifier<DailyPrayerStatus> {
  final PrayerTrackingService _trackingService = PrayerTrackingService.instance;

  DailyPrayerStatusNotifier()
      : super(DailyPrayerStatus(loadedAt: DateTime.fromMillisecondsSinceEpoch(0)));

  Future<void> load({bool forceRefresh = false}) async {
    if (!forceRefresh && !state.isStale) return;

    try {
      await _trackingService.initialize();
      final userId = getCurrentUserId();
      final summary = await _trackingService.getDailySummary(
        userId: userId,
        date: DateTime.now(),
      );

      state = DailyPrayerStatus(
        statuses: Map.from(summary.prayers),
        loadedAt: DateTime.now(),
      );
    } catch (e) {
      // Keep existing state on error
    }
  }

  /// Update a single prayer status (after user marks/unmarks a prayer)
  void updatePrayer(String prayerName, PrayerStatus status) {
    final updated = Map<String, PrayerStatus>.from(state.statuses);
    updated[prayerName] = status;
    state = state.copyWith(updated);
  }

  /// Remove a prayer status (after user unmarks)
  void removePrayer(String prayerName) {
    final updated = Map<String, PrayerStatus>.from(state.statuses);
    updated[prayerName] = PrayerStatus.missed;
    state = state.copyWith(updated);
  }
}

final dailyPrayerStatusProvider =
    StateNotifierProvider<DailyPrayerStatusNotifier, DailyPrayerStatus>(
  (ref) => DailyPrayerStatusNotifier(),
);

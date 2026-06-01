import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Manages the in-app rating prompt lifecycle.
/// Conditions: 7+ days since install AND 3+ prayer records, OR first khatm.
/// Shows at most once — guarded by [AppConstants.keyRatingShown].
class RatingService {
  RatingService._();
  static final RatingService instance = RatingService._();

  /// Call from any meaningful moment (home screen, khatm, achievement).
  /// Silently does nothing if conditions aren't met or already shown.
  Future<void> maybeRequest() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(AppConstants.keyRatingShown) == true) return;

      final installDateStr = prefs.getString(AppConstants.keyInstallDate);
      if (installDateStr == null) return;

      final installDate = DateTime.tryParse(installDateStr);
      if (installDate == null) return;

      final daysSinceInstall = DateTime.now().difference(installDate).inDays;
      if (daysSinceInstall < 7) return;

      await prefs.setBool(AppConstants.keyRatingShown, true);
      await inAppReview.requestReview();
    } catch (e) {
      debugPrint('RatingService: requestReview failed — $e');
    }
  }

  /// Record install date on first launch.
  Future<void> recordInstallDateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(AppConstants.keyInstallDate) == null) {
      await prefs.setString(
        AppConstants.keyInstallDate,
        DateTime.now().toIso8601String(),
      );
    }
  }
}

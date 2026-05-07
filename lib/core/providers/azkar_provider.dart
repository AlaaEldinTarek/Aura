import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/azkar.dart';

const _kPrefsKey = 'azkar_state';
const _kStreakDateKey = 'azkar_streak_date';

class AzkarNotifier extends StateNotifier<AzkarState> {
  AzkarNotifier() : super(AzkarState.empty()) {
    _load();
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = AzkarState.fromJson(json, _todayKey());
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state.toJson()));
  }

  Future<void> toggleItem(String id, AzkarCategory cat) async {
    final wasMorningComplete = state.isMorningComplete;
    final wasEveningComplete = state.isEveningComplete;

    Set<String> newMorning = Set.from(state.completedMorning);
    Set<String> newEvening = Set.from(state.completedEvening);

    if (cat == AzkarCategory.morning) {
      if (newMorning.contains(id)) {
        newMorning.remove(id);
      } else {
        newMorning.add(id);
      }
    } else {
      if (newEvening.contains(id)) {
        newEvening.remove(id);
      } else {
        newEvening.add(id);
      }
    }

    state = state.copyWith(
      completedMorning: newMorning,
      completedEvening: newEvening,
    );

    // Check if a session just completed
    final nowMorningComplete = state.isMorningComplete;
    final nowEveningComplete = state.isEveningComplete;
    final sessionJustCompleted =
        (!wasMorningComplete && nowMorningComplete) ||
        (!wasEveningComplete && nowEveningComplete);

    if (sessionJustCompleted) {
      await _onSessionComplete();
    }

    await _save();
  }

  Future<void> _onSessionComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDate = prefs.getString(_kStreakDateKey) ?? '';

    int streak = state.streakCount;
    int sessions = state.totalSessions + 1;

    if (lastDate == today) {
      // Already counted today — just increment sessions if not already done
    } else {
      final yesterday = _yesterdayKey();
      if (lastDate == yesterday) {
        streak++;
      } else if (lastDate.isEmpty) {
        streak = 1;
      } else {
        streak = 1;
      }
      await prefs.setString(_kStreakDateKey, today);
    }

    state = state.copyWith(streakCount: streak, totalSessions: sessions);
  }

  static String _yesterdayKey() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  Future<void> resetDay() async {
    state = AzkarState.empty();
    await _save();
  }
}

final azkarProvider = StateNotifierProvider<AzkarNotifier, AzkarState>(
  (_) => AzkarNotifier(),
);

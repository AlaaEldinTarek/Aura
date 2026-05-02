import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wird.dart';
import '../services/wird_service.dart';

final wirdStateProvider =
    StateNotifierProvider<WirdNotifier, AsyncValue<WirdState>>((ref) {
  return WirdNotifier();
});

class WirdNotifier extends StateNotifier<AsyncValue<WirdState>> {
  WirdNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final data = await WirdService.instance.getFullState();
      if (!mounted) return;
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setDailyPageGoal(int goal) async {
    final current = state.value;
    if (current == null) return;
    final clamped = goal.clamp(1, 604);
    final newSettings = current.settings.copyWith(dailyPageGoal: clamped);
    await WirdService.instance.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setReminderTimes(List<String> times) async {
    final current = state.value;
    if (current == null) return;
    final capped = times.length > 10 ? times.sublist(0, 10) : times;
    final newSettings = current.settings.copyWith(reminderTimes: capped);
    await WirdService.instance.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final newSettings = current.settings.copyWith(remindersEnabled: enabled);
    await WirdService.instance.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> addReminder(String time) async {
    final current = state.value;
    if (current == null) return;
    if (current.settings.reminderTimes.length >= 10) return;
    final newTimes = [...current.settings.reminderTimes, time];
    await setReminderTimes(newTimes);
  }

  Future<void> removeReminder(int index) async {
    final current = state.value;
    if (current == null) return;
    final newTimes = [...current.settings.reminderTimes]..removeAt(index);
    await setReminderTimes(newTimes);
  }

  Future<void> recordPagesRead(int additionalPages, int currentPage) async {
    await WirdService.instance.recordPagesRead(additionalPages, currentPage);
    final updatedState = await WirdService.instance.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  Future<void> markComplete() async {
    await WirdService.instance.markDayComplete();
    final updatedState = await WirdService.instance.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  Future<void> refresh() async {
    await _init();
  }
}

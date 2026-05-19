import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/task_service.dart';

class GuestMigrationState {
  final bool isPending;
  final String? uid;
  final int taskCount;
  final bool dialogShownThisSession;

  const GuestMigrationState({
    this.isPending = false,
    this.uid,
    this.taskCount = 0,
    this.dialogShownThisSession = false,
  });

  GuestMigrationState copyWith({
    bool? isPending,
    String? uid,
    int? taskCount,
    bool? dialogShownThisSession,
  }) =>
      GuestMigrationState(
        isPending: isPending ?? this.isPending,
        uid: uid ?? this.uid,
        taskCount: taskCount ?? this.taskCount,
        dialogShownThisSession: dialogShownThisSession ?? this.dialogShownThisSession,
      );
}

class GuestMigrationNotifier extends StateNotifier<GuestMigrationState> {
  GuestMigrationNotifier() : super(const GuestMigrationState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('pending_guest_migration_uid');
    if (uid == null) return;
    final count = await TaskService.instance.getLocalTaskCount();
    if (count == 0) {
      await _clearFlag();
      return;
    }
    state = GuestMigrationState(isPending: true, uid: uid, taskCount: count);
  }

  Future<void> migrate() async {
    final uid = state.uid;
    if (uid == null) return;
    await TaskService.instance.migrateGuestTasksToFirestore(uid);
    await _clearFlag();
    state = const GuestMigrationState();
  }

  void markDialogShown() {
    state = state.copyWith(dialogShownThisSession: true);
  }

  Future<void> _clearFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_guest_migration_uid');
  }
}

final guestMigrationProvider =
    StateNotifierProvider<GuestMigrationNotifier, GuestMigrationState>(
  (ref) => GuestMigrationNotifier(),
);

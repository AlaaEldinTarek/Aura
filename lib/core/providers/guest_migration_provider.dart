import 'package:firebase_auth/firebase_auth.dart';
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
  // Injectable for tests (TaskService and FirebaseAuth need Firebase).
  final Future<int> Function() _localTaskCount;
  final String? Function() _currentUid;
  final Future<void> Function(String uid) _migrateTasks;

  GuestMigrationNotifier({
    Future<int> Function()? localTaskCount,
    String? Function()? currentUid,
    Future<void> Function(String uid)? migrateTasks,
  })  : _localTaskCount =
            localTaskCount ?? (() => TaskService.instance.getLocalTaskCount()),
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _migrateTasks = migrateTasks ??
            ((uid) => TaskService.instance.migrateGuestTasksToFirestore(uid)),
        super(const GuestMigrationState()) {
    refresh();
  }

  /// Re-reads the flag and the local task count (F60). Pending only for the
  /// signed-in account the flag names; otherwise the flag and the local tasks
  /// are left as they are. Keeps [GuestMigrationState.dialogShownThisSession].
  Future<void> refresh() async {
    final shown = state.dialogShownThisSession;
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('pending_guest_migration_uid');
    if (uid == null || _currentUid() != uid) {
      state = GuestMigrationState(dialogShownThisSession: shown);
      return;
    }
    final count = await _localTaskCount();
    if (count == 0) {
      await _clearFlag();
      state = GuestMigrationState(dialogShownThisSession: shown);
      return;
    }
    state = GuestMigrationState(
      isPending: true,
      uid: uid,
      taskCount: count,
      dialogShownThisSession: shown,
    );
  }

  Future<void> migrate() async {
    final uid = state.uid;
    if (uid == null || _currentUid() != uid) return;
    await _migrateTasks(uid);
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

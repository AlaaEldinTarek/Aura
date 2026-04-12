import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';

/// Connectivity state
enum ConnectivityStatus {
  online,
  offline,
}

/// Connectivity provider - monitors network connectivity status
class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier() : super(ConnectivityStatus.online) {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Initialize connectivity monitoring
  Future<void> _initialize() async {
    try {
      // Check initial connectivity status
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _updateStatus(results);
        },
      );

      debugPrint('🌐 Connectivity monitoring initialized');
    } catch (e) {
      debugPrint('❌ Error initializing connectivity: $e');
      // Default to online on error (assume connection)
      state = ConnectivityStatus.online;
    }
  }

  /// Update connectivity status based on connectivity results
  void _updateStatus(List<ConnectivityResult> results) {
    // If there are no results, assume offline
    if (results.isEmpty) {
      state = ConnectivityStatus.offline;
      debugPrint('🔴 No connectivity detected');
      return;
    }

    // Check if any connection is available (not none)
    final hasConnection = results.any((result) => result != ConnectivityResult.none);

    if (hasConnection) {
      if (state != ConnectivityStatus.online) {
        state = ConnectivityStatus.online;
        debugPrint('🟢 Device is online');
        // Sync queued offline operations when coming back online
        SyncService.instance.syncPendingOperations();
      }
    } else {
      if (state != ConnectivityStatus.offline) {
        state = ConnectivityStatus.offline;
        debugPrint('🔴 Device is offline');
      }
    }
  }

  /// Check if device is currently online
  bool get isOnline => state == ConnectivityStatus.online;

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Provider for connectivity status
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
  return ConnectivityNotifier();
});

/// Simplified provider that provides a boolean for online/offline status
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityProvider);
  return status == ConnectivityStatus.online;
});

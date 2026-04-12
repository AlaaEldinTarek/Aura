import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'offline_queue_service.dart';

/// Service that syncs queued offline operations when connectivity is restored
class SyncService {
  SyncService._();

  static final SyncService _instance = SyncService._();
  static SyncService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineQueueService _queueService = OfflineQueueService.instance;

  bool _isSyncing = false;

  /// Process all queued operations
  Future<int> syncPendingOperations() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int synced = 0;

    try {
      final queue = _queueService.getQueue();

      if (queue.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      debugPrint('🔄 SyncService: Processing ${queue.length} queued operations');

      for (final operation in queue) {
        try {
          bool success = false;

          switch (operation.type) {
            case 'record':
              success = await _syncRecord(operation);
              break;
            case 'delete':
              success = await _syncDelete(operation);
              break;
            default:
              debugPrint('⚠️ Unknown operation type: ${operation.type}');
              success = true; // Remove unknown types
          }

          if (success) {
            await _queueService.dequeue(operation.id);
            synced++;
          }
        } catch (e) {
          debugPrint('❌ Error syncing operation ${operation.id}: $e');
          // Continue with next operation
        }
      }

      if (synced > 0) {
        debugPrint('✅ SyncService: Synced $synced/${queue.length} operations');
      }
    } catch (e) {
      debugPrint('❌ SyncService error: $e');
    }

    _isSyncing = false;
    return synced;
  }

  Future<bool> _syncRecord(QueuedOperation operation) async {
    try {
      final userId = operation.data['userId'] as String?;
      if (userId == null) return false;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection(operation.collection)
          .add(operation.data);

      return true;
    } catch (e) {
      debugPrint('❌ Error syncing record: $e');
      return false;
    }
  }

  Future<bool> _syncDelete(QueuedOperation operation) async {
    try {
      final userId = operation.data['userId'] as String?;
      final docId = operation.data['docId'] as String?;
      if (userId == null || docId == null) return false;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection(operation.collection)
          .doc(docId)
          .delete();

      return true;
    } catch (e) {
      debugPrint('❌ Error syncing delete: $e');
      return false;
    }
  }
}

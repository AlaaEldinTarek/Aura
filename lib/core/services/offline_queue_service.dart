import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A queued write operation for offline support
class QueuedOperation {
  final String id;
  final String type; // 'record', 'delete', 'update'
  final String collection; // 'prayer_records', 'dhikr_sessions', 'tasks'
  final Map<String, dynamic> data;
  final DateTime createdAt;

  const QueuedOperation({
    required this.id,
    required this.type,
    required this.collection,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'collection': collection,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) => QueuedOperation(
    id: json['id'] as String,
    type: json['type'] as String,
    collection: json['collection'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Service for queuing operations when offline and replaying when online
class OfflineQueueService {
  OfflineQueueService._();

  static final OfflineQueueService _instance = OfflineQueueService._();
  static OfflineQueueService get instance => _instance;

  static const String _queueKey = 'offline_operation_queue';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('📥 OfflineQueueService: Initialized');
  }

  /// Add an operation to the queue
  Future<void> enqueue(QueuedOperation operation) async {
    if (_prefs == null) await initialize();

    final queue = _loadQueue();
    queue.add(operation);

    // Keep only last 100 operations to prevent unbounded growth
    if (queue.length > 100) {
      queue.removeRange(0, queue.length - 100);
    }

    await _saveQueue(queue);
    debugPrint('📥 Queued offline operation: ${operation.type} ${operation.collection} (${queue.length} pending)');
  }

  /// Get all queued operations
  List<QueuedOperation> getQueue() {
    return _loadQueue();
  }

  /// Get count of pending operations
  int get pendingCount => _loadQueue().length;

  /// Remove a specific operation from the queue
  Future<void> dequeue(String operationId) async {
    final queue = _loadQueue();
    queue.removeWhere((op) => op.id == operationId);
    await _saveQueue(queue);
  }

  /// Clear all queued operations
  Future<void> clearQueue() async {
    await _saveQueue([]);
    debugPrint('📥 Offline queue cleared');
  }

  List<QueuedOperation> _loadQueue() {
    if (_prefs == null) return [];

    final jsonStr = _prefs!.getString(_queueKey);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => QueuedOperation.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('❌ Error loading offline queue: $e');
      return [];
    }
  }

  Future<void> _saveQueue(List<QueuedOperation> queue) async {
    if (_prefs == null) return;

    final jsonList = queue.map((op) => op.toJson()).toList();
    await _prefs!.setString(_queueKey, jsonEncode(jsonList));
  }
}

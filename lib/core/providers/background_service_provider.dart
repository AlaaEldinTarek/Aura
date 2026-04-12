import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/background_service_manager.dart';

/// Provider for background service manager
final backgroundServiceProvider = Provider<BackgroundServiceManager>((ref) {
  return BackgroundServiceManager.instance;
});

/// Provider for foreground service running state
final foregroundServiceRunningProvider = StateProvider<bool>((ref) {
  return BackgroundServiceManager.instance.isRunning;
});

/// Provider for initializing background service
final backgroundServiceInitProvider = FutureProvider<bool>((ref) async {
  await BackgroundServiceManager.instance.initialize();
  return BackgroundServiceManager.instance.isRunning;
});

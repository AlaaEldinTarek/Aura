import 'package:flutter/services.dart';

/// Navigation Service - Tracks current route for native back button handling
class NavigationService {
  NavigationService._();

  static const MethodChannel _channel = MethodChannel('com.aura.hala/navigation');

  static String _currentRoute = '/';

  static String get currentRoute => _currentRoute;

  /// Call this when route changes to update native MainActivity
  static Future<void> setCurrentRoute(String route) async {
    _currentRoute = route;
    try {
      await _channel.invokeMethod('setCurrentRoute', {'route': route});
    } catch (e) {
      // Ignore errors - this is optional functionality
    }
  }

  /// Initialize with current route (call from main.dart or navigation observer)
  static Future<void> initialize() async {
    await setCurrentRoute(_currentRoute);
  }
}

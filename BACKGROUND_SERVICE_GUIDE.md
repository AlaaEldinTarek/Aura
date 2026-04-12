# Keeping Aura App Running in Background - Complete Guide

## Problem
When users minimize or close the app, the Android OS may suspend or kill the Flutter process, stopping:
- Prayer time timers
- Countdown widgets
- State updates
- Adhan playback

## Solutions Implemented

### 1. Foreground Service (Android) ✅ IMPLEMENTED

**What it does:** Creates a persistent notification that keeps the app alive even when closed.

**Files created/modified:**
- `android/app/src/main/kotlin/com/aura/hala/PrayerForegroundService.kt` - Native foreground service
- `android/app/src/main/kotlin/com/aura/hala/BackgroundServiceHandler.kt` - Platform channel handler
- `android/app/src/main/AndroidManifest.xml` - Service registration and permissions
- `lib/core/services/background_service_manager.dart` - Flutter service manager
- `lib/core/providers/background_service_provider.dart` - Riverpod provider
- `lib/features/settings/settings_screen.dart` - Settings UI toggle

**How to use:**
```dart
// Start foreground service (keeps app alive)
await BackgroundServiceManager.instance.startForegroundService();

// Stop foreground service
await BackgroundServiceManager.instance.stopForegroundService();

// Check if running
bool isRunning = BackgroundServiceManager.instance.isRunning;
```

**User benefit:**
- App stays alive for prayer alerts
- Adhan plays at exact times
- Notification shows "Aura - Prayer Times Active"

### 2. Native Alarms (Already Implemented) ✅

Your app already has:
- `PrayerAlarmReceiver` - Native BroadcastReceiver for exact alarms
- `PrayerAlarmService` - Schedules native alarms via AlarmManager
- `AdhanPlayer` - Native MediaPlayer for adhan playback

These work even when Flutter is killed because they run at the native level.

### 3. Workmanager Alternative (Recommended for Periodic Tasks)

For additional reliability, add workmanager for periodic tasks:

**Add to pubspec.yaml:**
```yaml
workmanager: ^0.5.2
```

**Usage:**
```dart
// Define periodic task
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Refresh prayer times
    // Schedule alarms
    return Future.value(true);
  });
}

// Initialize
Workmanager().initialize(
  callbackDispatcher,
  isInDebugMode: false,
);

// Schedule periodic task (every 15 minutes)
Workmanager().registerPeriodicTask(
  'prayerTimeUpdate',
  'updatePrayerTimes',
  frequency: Duration(minutes: 15),
);
```

### 4. Battery Optimization Whitelist

Guide users to whitelist your app:

```dart
Future<void> requestBatteryOptimizationWhitelist() async {
  if (Platform.isAndroid) {
    final channel = MethodChannel('com.aura.hala/prayer_alarms');
    await channel.invokeMethod('openBatteryOptimizationSettings');
  }
}
```

## Complete Implementation Checklist

### Android Side ✅
- [x] Foreground service created
- [x] Service registered in AndroidManifest.xml
- [x] Permissions added (FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC)
- [x] Platform channel handler in MainActivity.kt
- [x] Service restarts if killed

### Flutter Side ✅
- [x] BackgroundServiceManager for controlling native service
- [x] Riverpod provider for state management
- [x] Settings UI with toggle switch
- [x] Integration with PrayerAlarmService
- [x] Initialization in main.dart

### What This Achieves

1. **App stays alive** - Foreground service prevents OS from killing the app
2. **Prayer alerts work** - Native alarms fire at exact times
3. **Adhan plays** - Native MediaPlayer works even if Flutter is paused
4. **User control** - Toggle in settings to enable/disable
5. **Persistent notification** - Shows app is active

## Testing

1. **Enable background service in settings**
2. **Minimize app** (swipe up from bottom or press home)
3. **Wait for prayer time** - Adhan should play
4. **Check notification** - Should show "Aura - Prayer Times Active"

## Permissions Summary

Your AndroidManifest.xml now includes:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

## Important Notes

1. **Android 14+**: Requires `FOREGROUND_SERVICE_DATA_SYNC` permission type
2. **Battery Optimization**: Users should whitelist your app
3. **Exact Alarm**: Users must grant this permission on Android 12+
4. **Persistent Notification**: Required by Android for foreground services

## User Communication

Add this in your onboarding or settings:

> "To receive prayer alerts reliably, enable Background Service. This keeps the app running with a minimal notification. You can disable this anytime, but alerts may not work when the app is closed."

## Alternative: iOS Implementation

For iOS, use:
- `Background fetch` - For periodic updates
- `UNNotificationRequest` - For local notifications at exact times
- `Audio` background mode - For adhan playback

Add to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>audio</string>
    <string>processing</string>
</array>
```

## Summary

The foreground service solution is now **fully implemented** in your app. When users enable it in settings, the app will:
1. Show a persistent notification
2. Stay alive in background
3. Play adhan at prayer times
4. Update widgets correctly

This is the most reliable approach for Android prayer apps.

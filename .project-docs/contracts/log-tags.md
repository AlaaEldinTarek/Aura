# Contract — log tags & logcat filters
Seeded from old CLAUDE.md on 2026-11-06; Confidence: Unknown until Step 2. Any logging change is verified by
comparing captured `adb logcat` output before/after for the same device-checklist scenarios (same filters, events, order).

## Filters in use
```bash
adb logcat | grep -E "(PrayerAlarm|NotificationService|PrayerTimes|AdhanPlayer|SilentMode)"
adb logcat | grep "🕌"
```

## Tags (must keep working)
- `PrayerAlarm`, `NotificationService`, `PrayerTimes`, `AdhanPlayer`, `SilentMode` (Kotlin `Log` tags and/or Dart prefixes — Step 2)

## Emoji prefixes (Dart platform-channel logs)
- `🕌` prayer · `📱` platform/device · `🔔` notifications · `✅` success · `🔄` sync/refresh

Hotspot (initial survey): ~511 `print`/`debugPrint` calls, no levels.

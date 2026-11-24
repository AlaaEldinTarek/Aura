# Fix F73 + F74 — Task-summary text frozen / Azkar card timeout

**Status:** Draft — not approved for code  
**Branch:** `fix/f73-f74`  
**Findings:** F73 (MEDIUM), F74 (LOW)  
**Files touched:** `lib/core/services/notification_service.dart`, `android/app/src/main/kotlin/com/aura/hala/AzkarAlarmReceiver.kt`

---

## F73 — Task-summary 3999 text frozen at schedule time

### Problem

`scheduleDailyTaskSummary()` builds `title`/`body` from the task counts **at schedule time** and passes them to `scheduleNativeNotification` without a `kind` or `countA`/`countB`. On Android the PendingIntent stores that frozen text; at fire time `NativeNotificationReceiver.onReceive()` reads and posts it as-is. The native re-arm (`repeatDaily = true`, `NativeNotificationReceiver.kt:179–186`) re-schedules for 24 h later with the same frozen payload, so the next day's notification may show yesterday's count.

### Fix

Pass `kind: 'digest'`, `countA: todayCount`, `countB: overdueCount` in the `scheduleNativeNotification` call. `NativeReminderCard.titleFor(KIND_DIGEST, …)` and `bodyFor(KIND_DIGEST, countA, countB, …)` already handle both languages and all count combinations (lines 66–91 of `NativeReminderCard.kt`); the card text is then built at **fire time** in the current app language from the stored counts.

#### Behaviour change to note

The no-tasks title changes from `"No tasks today"` / `"لا مهام لليوم"` (Dart-built) to `"Today's Tasks"` / `"ملخص مهامك اليوم"` (NativeReminderCard.KIND_DIGEST), consistent with the Digest card (4001). The body `"Clean day! No tasks due today 🎉"` / `"يوم نظيف! لا مهام اليوم 🎉"` is unchanged.

### Change (Dart)

**File:** `lib/core/services/notification_service.dart`  
**Method:** `scheduleDailyTaskSummary()`, the `scheduleNativeNotification` invocation (~line 865)

```dart
// Before
await _nativeAlarmChannel.invokeMethod('scheduleNativeNotification', {
  'notificationId': _dailySummaryId,
  'title': title,
  'body': body,
  'channelId': _taskChannelId,
  'channelName': _taskChannelName,
  'triggerAt': scheduled.millisecondsSinceEpoch,
  'tapTab': 3,
  'repeatDaily': true,
  'isArabic': isArabic,
});

// After
await _nativeAlarmChannel.invokeMethod('scheduleNativeNotification', {
  'notificationId': _dailySummaryId,
  'title': title,
  'body': body,
  'channelId': _taskChannelId,
  'channelName': _taskChannelName,
  'triggerAt': scheduled.millisecondsSinceEpoch,
  'tapTab': 3,
  'repeatDaily': true,
  'isArabic': isArabic,
  'kind': 'digest',
  'countA': todayCount,
  'countB': overdueCount,
});
```

No Kotlin changes required; `MainActivity.kt:658–660` already reads and forwards `kind`, `countA`, `countB`.

---

## F74 — Azkar card timeout 60 s, should be ~30 min

### Problem

`AzkarAlarmReceiver.kt:155` sets `.setTimeoutAfter(60_000)` (60 seconds). The azkar card is for post-prayer dhikr; 60 s is too short — the user may still be finishing prayer when the card disappears. 30 minutes is consistent with other post-prayer cards.

### Change (Kotlin)

**File:** `android/app/src/main/kotlin/com/aura/hala/AzkarAlarmReceiver.kt:155`

```kotlin
// Before
.setTimeoutAfter(60_000)

// After
.setTimeoutAfter(30 * 60 * 1000L)
```

---

## Contract check

- No new SharedPreferences keys
- No notification IDs or channels changed (3999 / `azkar_reminder` unchanged)
- No method-channel names changed
- No Firestore paths changed

---

## Tests

| ID | Description |
|----|-------------|
| T1 | Daily task summary notification shows current-language title/body at fire time |
| T2 | "No tasks" case: title is "Today's Tasks" / "ملخص مهامك اليوم", body is clean-day string |
| T3 | Azkar card stays on screen for >60 s without auto-dismissing |

T1 and T2 are observable at the next 8 am fire (or via the dev test). T3 is observable via the azkar dev tile.

---

## Device checks

| Step | Description |
|------|-------------|
| S55  | Trigger dev "Test azkar" — notification card stays visible for at least 1 min |
| S56  | At 8 am: task-summary card shows the correct count in the current language |

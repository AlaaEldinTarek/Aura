# Fix spec: F51r — platform guards around exact-alarm scheduling

Status: Draft — awaiting owner decisions (section "Decisions") and `approve phase P1`

Branch: `fix/f51r` (from main da2f72a). Tag: fix track P2 (platform guard), low risk. Source: `reference/findings.md` F51(r).
Behavior-preserving: no alarm time, request code, notification ID, channel, prefs key or log tag changes.

All checks are static (source read 2026-11-28). No device run. Callers' own `try` coverage was only checked for the sites below, not for every caller up the stack (UNVERIFIED where noted).

## Finding

`AlarmManager.setExactAndAllowWhileIdle` / `setExact` can throw `SecurityException` on Android 12–12L (API 31–32) when the user revokes "Alarms & reminders" (`SCHEDULE_EXACT_ALARM`). The manifest declares both `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` (`AndroidManifest.xml:13-14`); on API 33+ `USE_EXACT_ALARM` makes this very unlikely, on API 31–32 it can happen. The test phone (Android 10, API 29) can never hit it, so no device check can show it.

### Unguarded sites (VERIFIED: no `try` around the call, looked 12 lines up)

| File | Lines | Function |
| --- | --- | --- |
| `PrayerAlarmReceiver.kt` | 184/186 | `scheduleReminderAlarm` |
| `PrayerAlarmReceiver.kt` | 272/278 | `scheduleDelayedReminder` |
| `PrayerAlarmReceiver.kt` | 326/332 | `schedulePrayerAlarm` — the adhan alarm itself |
| `PrayerAlarmReceiver.kt` | 443/445 | post-prayer check |
| `PrayerAlarmReceiver.kt` | 869/875 | `scheduleSilentModeRestore` |
| `NativeNotificationReceiver.kt` | 90/92 | `schedule` |
| `TaskReminderReceiver.kt` | 81/83 | `schedule` |

These seven are the sites the finding names (three files). Same pattern, also unguarded in the same sense, but **not named in the finding**: `AzkarAlarmReceiver.kt:87/89`, `DailySummaryReceiver.kt:47/49`, `FocusModeReceiver.kt:71/77`, `MainActivity.kt:487/493`, `ToggleSilentModeReceiver.kt:274/280`. A `try` further than 12 lines above would not have shown (UNVERIFIED for these five).

### Already guarded (VERIFIED, use as the pattern)

`DailyRecalcReceiver.kt:60` (`catch Exception`), `JumuahReminderReceiver.kt:73` (`catch SecurityException`), `TaskReminderReceiver.scheduleDueNow` (:102-111), `PrayerForegroundService.scheduleRestartIfNeeded` (:911-922).

### Who crashes

A `SecurityException` thrown inside a `BroadcastReceiver.onReceive` or a service callback kills the process. Callers: `schedulePrayerAlarm` is reached from `PrayerRescheduleService.kt:134`, `NativePrayerCalculator.kt:221` and the `MainActivity` channel handler (`:437`); `scheduleReminderAlarm` from `PrayerAlarmReceiver.kt:217,356`. Whether those callers already catch: UNVERIFIED (not read). A channel handler exception reaches Dart as an error; a service or receiver one is a crash.

### Other sub-items of F51r

- **`openExactAlarmSettings` reports success on failure** — VERIFIED (`MainActivity.kt:726-728`: `catch` → `result.success(true)`). But both Dart callers ignore the result (`platform_channel_service.dart:86`, `prayer_alarm_service.dart:273`), so there is no user-visible effect today. **Not worth a change** (Decision 2).
- **Foreground-service restart uses `PendingIntent.getService` on O+** — VERIFIED in code (`PrayerForegroundService.kt:905`); the call is already inside `try/catch`. Whether the restart really works on API 26+ is UNVERIFIED. The right API on O+ would be `getForegroundService`, which changes how the service starts and cannot be judged from source. **Not in this fix**; needs a device test (Decision 3).
- **Boot also listens to `android.intent.action.REBOOT`** — VERIFIED (`PrayerBootReceiver.kt:23`, manifest `:162`). It is a vendor (EMUI) fallback next to the standard actions; I found no defect. **No change.**

## Fix (phase P1, one commit)

At each unguarded site above, wrap only the `if (SDK_INT >= M) { setExactAndAllowWhileIdle } else { setExact }` block:

```kotlin
try {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) { alarmManager.setExactAndAllowWhileIdle(...) }
    else { alarmManager.setExact(...) }
} catch (e: SecurityException) {
    Log.e(TAG, "❌ Exact alarm not allowed for <what>: ${e.message}")
    return   // skip the "scheduled" log line below it
}
```

- Only `SecurityException` is caught (the documented failure), same as `JumuahReminderReceiver`. Existing log tags and emoji style are kept; the new line reuses each file's `TAG`.
- `return` keeps the "scheduled" log from claiming success. In functions with code after the log, nothing else follows the arming, so the early return changes nothing on the success path.
- `PrayerAlarmReceiver.kt` is an "edit carefully" file: the diff is limited to the five blocks, no moved code.

## Decisions (owner)

**Answered 2026-11-28:** (1) the seven named sites only. Decisions 2 and 3 were not asked; the spec proceeds with their recommended answers (skip the `openExactAlarmSettings` change; the `getForegroundService` question stays a separate device-test item) unless the owner says otherwise at phase approval.

1. Scope: the seven named sites only (recommended, matches the finding), or also the five extra sites listed above (same defect, more files incl. `DailySummaryReceiver.kt`, which is also "edit carefully")?
2. Skip the `openExactAlarmSettings` result change (recommended: no visible effect)?
3. `getForegroundService` question: leave as a separate device-test item (recommended)?

## Files changed

- `PrayerAlarmReceiver.kt`, `NativeNotificationReceiver.kt`, `TaskReminderReceiver.kt` (+ the five extra files only if Decision 1 says so)
- new `test/contracts/f51r_source_test.dart` (source-text test, style of `native_keys_scan_test.dart`): each listed function body has the call inside a `try` with `catch (e: SecurityException)`.
- `.project-docs/STATE.md` after merge (separate docs branch).
- No contract file changes (no key, channel, ID or tag changes).

## Verification

- `flutter analyze`, `flutter test` (pass/fail only); `flutter build apk --release --obfuscate --split-debug-info=build/debug-info` compiles the Kotlin. Not run until approved.
- Device (owner-observed, Android 10): nothing visible should change. Check one adhan alarm still fires and a task reminder still fires. The failure path itself cannot be reproduced on API 29; it would need an API 31–32 emulator with "Alarms & reminders" switched off (UNVERIFIED, optional).

## Risks

- The success path is identical; only a thrown `SecurityException` is now logged instead of crashing.
- A swallowed failure means the alarm silently does not arm. That is no worse than a crash, and the existing permission row in Settings (`canScheduleExactAlarms`) still shows the state. A user-visible warning is out of scope (new UI).
- `PrayerAlarmReceiver.kt` edits: reviewer should read the five blocks for brace and early-return placement.

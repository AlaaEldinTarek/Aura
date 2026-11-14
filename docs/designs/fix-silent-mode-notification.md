# Fix F68 — Silent-Mode Notification Control Buttons

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft. **Partly superseded on 2026-11-14** by `docs/designs/fix-silent-mode-buttons-in-fgs.md`: the separate notification 8100, the `silent_mode_control` channel and request codes 8100/8101 are replaced by buttons inside the foreground-service notification. The boot-receiver ringer restore (Path d) and the rest of this spec stay in force.
*   **Date:** 2026-11-11
*   **Branch:** `fix/silent-mode-notification`
*   **Finding:** F68 (`reference/findings.md`)

---

## Overview

When a prayer adhan fires and the user has silent mode (vibrate-on-prayer) enabled, Aura switches
the phone to vibrate for a configurable window (default 20 min). During that window the user should
be able to stop the vibrate early ("Stop Vibration") or keep it past the auto-restore timer
("Keep Vibration").

Before commit `6514f26` those buttons lived on the adhan notification itself (IDs 1001–1006).
That commit stripped the adhan notification to a minimal 3-second full-screen-intent trigger, moved
all controls into `AdhanFullScreenActivity`, and added `addAction` calls to the foreground
service's custom-view notification as a fallback. The fallback is broken: `addAction` buttons are
invisible on a notification that uses `setCustomBigContentView` without `DecoratedCustomViewStyle`.

The result: once the user dismisses the adhan screen, no working control exists in the notification
shade for the rest of the silent window.

## The Problem

After the adhan full-screen activity is dismissed, the user cannot cancel or extend silent mode
from the notification shade. The foreground service notification appears to offer "Stop Vibration"
/ "Keep Vibration" buttons, but they are never rendered. The only exit paths are waiting 20 min for
the auto-restore alarm or manually changing the ringer in Android Settings.

This is a pre-existing regression introduced in commit `6514f26` and confirmed as not caused by
any subsequent PR.

## Goals

*   Post a separate, standard (no custom view) notification with two action buttons — "Stop
    Vibration" and "Keep Vibration" — whenever silent mode is activated.
*   Cancel that notification from every code path that ends silent mode.
*   Remove the dead `addAction` calls from `PrayerForegroundService.showAdhanModeNotification()`.
*   Update `contracts/notification-ids.md` with the new notification ID and channel.
*   Restore `saved_ringer_mode` and clear `is_silent_active` in `PrayerBootReceiver` on boot (pre-existing gap; included here because clearing the flag without first restoring the ringer would leave the phone on vibrate after reboot).
*   Make zero changes to Dart code (`lib/`), verified by grep.

## Non-Goals

*   Changing the foreground service's custom-layout notification design.
*   Changing `AdhanFullScreenActivity` or its buttons.
*   Fixing the separate `EXTEND_SILENT` state bug (F51e) where the ringer is left on vibrate
    permanently without a prefs flag being cleared.
*   Adding localized string resources to `res/values*/strings.xml` (inline strings are used
    consistently throughout the native layer).
*   Any change to notification IDs 1001–1006 (adhan notification contract).

## Open Questions

*   **Q1 (RESOLVED — see Technical Plan §Double-post guard):** What happens if adhan fires while
    silent mode is already active (e.g., back-to-back prayers within 20 min)? Answer: Android
    replaces an existing notification when `notify()` is called with the same ID. This is
    sufficient; no extra guard is needed in the posting path.
*   **Q2 (RESOLVED — see Technical Plan §Teardown coverage):** Does `PrayerBootReceiver`
    need to cancel notification 8100 on reboot? Answer: No — Android removes all posted
    notifications before `BOOT_COMPLETED` fires; no cancel call is needed. `PrayerBootReceiver`
    does need to restore the ringer (Android persists `ringerMode` across reboots) and clear
    `is_silent_active`. See §Teardown coverage item (d).
*   **Q3 (RESOLVED — see Technical Plan §Teardown coverage):** Does `PrayerForegroundService.onDestroy`
    need a cancel call? Answer: No, because the foreground service stays alive for the full silent
    window; teardown is handled by the receiver paths. See §Teardown coverage item (e).

---

## Critical User Journeys (CUJs)

### CUJ 1: Stop vibration early via shade

*   **Given**: Prayer adhan has fired, silent mode is active (`is_silent_active = true`),
    adhan screen has been dismissed.
*   **When**: User pulls down the notification shade and taps "Stop Vibration" on notification 8100.
*   **Then**: `ToggleSilentModeReceiver` receives `DISMISS_SILENT`; ringer is restored to
    `saved_ringer_mode`; `is_silent_active = false`; notification 8100 is cancelled; foreground
    service exits adhan mode and resumes its standard prayer-countdown operation.

### CUJ 2: Keep vibration past the auto-restore timer

*   **Given**: Same as CUJ 1.
*   **When**: User taps "Keep Vibration" on notification 8100.
*   **Then**: `ToggleSilentModeReceiver` receives `EXTEND_SILENT`; the auto-restore alarm is
    cancelled; ringer stays on vibrate; `silent_end_time = 0` (permanent mode); notification 8100
    is cancelled (user has made their choice).

### CUJ 3: Auto-restore after 20 minutes

*   **Given**: User has taken no action; silent mode is still active after the configured window.
*   **When**: `SilentOffReceiver` fires.
*   **Then**: Ringer is restored; `is_silent_active = false`; notification 8100 is cancelled.

### CUJ 4: Back-to-back prayers within the silent window (double-post guard)

*   **Given**: Sunrise fires while Fajr's silent window is still active (unusual but possible at
    high latitudes).
*   **When**: `PrayerAlarmReceiver` calls `enableSilentModeForPrayer` again, which posts
    notification 8100 again with the same ID.
*   **Then**: Android replaces the existing notification 8100 with the new one. No duplicate
    notification appears. The auto-restore alarm is re-armed for the new end time (new 20-min
    window). Behavior is correct with no extra guard.

### CUJ 5: Device reboot while silent mode is active

*   **Given**: Device is rebooted while `is_silent_active = true` and notification 8100 is visible.
*   **When**: `PrayerBootReceiver.onReceive` runs.
*   **Then** — the exact state the user sees after the fix:
    - **Notification 8100:** gone. Android removes all posted notifications before `BOOT_COMPLETED` fires.
    - **Ringer mode:** Restored to `saved_ringer_mode`. `PrayerBootReceiver` reads `saved_ringer_mode`
      from `aura_silent_mode` prefs and calls `audioManager.setRingerMode` before clearing the prefs.
      See §Path (d) for the technical mechanism.
    - **`is_silent_active`:** `false`. `PrayerBootReceiver` writes `is_silent_active = false` and
      `silent_end_time = 0` to `aura_silent_mode` after restoring the ringer.
    - **`SilentOffReceiver` alarm (request code 3999):** `AlarmManager` alarms do not survive a reboot;
      the auto-restore alarm is implicitly gone. The `PrayerBootReceiver` cleanup is definitive.

---

## Technical Plan

### New artefact: notification 8100 on channel `silent_mode_control`

A standard `NotificationCompat.Builder` notification (no `RemoteViews`, no custom layout)
is posted by `enableSilentModeForPrayer` in `PrayerAlarmReceiver` immediately after the ringer is
set to vibrate and `is_silent_active = true` is written.

```
PrayerAlarmReceiver.enableSilentModeForPrayer()
    ├── audioManager.ringerMode = RINGER_MODE_VIBRATE
    ├── silentPrefs: is_silent_active = true
    ├── silentPrefs: silent_end_time = now + duration
    ├── scheduleSilentModeRestore()      ← existing
    └── postSilentModeNotification()     ← NEW
            NotificationManagerCompat.notify(ctx, 8100, builder)
```

Notification spec:
- **ID:** 8100
- **Channel:** `silent_mode_control` (new, `IMPORTANCE_DEFAULT`, no sound, no vibration)
- **Small icon:** `R.drawable.ic_notification` (same as foreground service)
- **Content title:** `"Aura — Vibrate Mode"` / `"هالة — وضع الاهتزاز"` (language from `aura_prayer_times.language`)
- **Content text:** prayer name (using `getDisplayPrayerName` for Jumu'ah)
- **`setOngoing(false)`** — the user can swipe away notification 8100 without tapping a button. This is intentional: if the user dismisses the notification, silent mode continues until the auto-restore timer fires (the timer is the safety net). `is_silent_active` stays true and the ringer stays on vibrate until path (a), (b), or (c) fires. `setOngoing(true)` was considered but rejected — it prevents the user from ever dismissing the notification even when they prefer not to see it; the auto-restore timer already guarantees eventual ringer restoration.
- **`setAutoCancel(false)`** — tapping the body does nothing harmful
- **Action 1:** "Stop Vibration" / "إيقاف الاهتزاز" → `DISMISS_SILENT` PendingIntent (request code 8100)
- **Action 2:** "Keep Vibration" / "إبقاء الاهتزاز" → `EXTEND_SILENT` PendingIntent (request code 8101)

Both `PendingIntent`s carry `EXTRA_PRAYER_NAME` and `EXTRA_PRAYER_NAME_AR` (required by
`ToggleSilentModeReceiver`).

### Double-post guard

Android's `NotificationManagerCompat.notify(ctx, id, notification)` with a fixed ID replaces any
existing notification that has the same ID in the same package. No explicit "is already posted"
check is needed. If `enableSilentModeForPrayer` is called a second time within an active window,
the notification is refreshed (new prayer name, new timer) and the old one disappears. This is the
correct behaviour.

The existing `scheduleSilentModeRestore` already replaces the old `SilentOffReceiver` alarm via
`FLAG_UPDATE_CURRENT`, so the timer is also refreshed.

No guard needed. No code change needed beyond calling `NotificationManagerCompat.notify`.

### Teardown coverage

Every path that sets `is_silent_active = false` must also call
`NotificationManagerCompat.from(ctx).cancel(8100)`. The table below lists every such path, its
current location, the required change, and whether it is verified in code:

| # | Path | Location | Change needed | Verified |
|---|---|---|---|---|
| (a) | User taps "Stop Vibration" | `ToggleSilentModeReceiver.dismissSilentMode()` `:139` | Add `cancel(8100)` before or after clearing `is_silent_active` | Static code read |
| (b) | User taps "Keep Vibration" | `ToggleSilentModeReceiver.extendSilentMode()` `:205` | Add `cancel(8100)` after writing `silent_end_time = 0` | Static code read |
| (c) | Auto-restore timer fires | `SilentOffReceiver.onReceive()` `:331` | Add `cancel(8100)` alongside `is_silent_active = false` | Static code read |
| (d) | Device reboot | `PrayerBootReceiver` — currently **no silent-mode reset** | No `cancel(8100)` needed (Android clears all notifications at boot). Restore `saved_ringer_mode` via `AudioManager`, then write `is_silent_active = false` + `silent_end_time = 0`. | Static — gap confirmed |
| (e) | Foreground service destroyed | `PrayerForegroundService.onDestroy` | **No change needed.** The service is long-lived and is not stopped during the silent window; destruction while silent mode is active is an abnormal crash path (or OEM process kill under battery pressure). The notification will be orphaned until the next boot. (Exception: a force-stop via Android Settings removes all notifications for the package immediately — notification 8100 is gone — but the ringer stays on vibrate until `PrayerBootReceiver` runs at the next boot.) If the service is ever stopped normally (`stopService`), the auto-restore alarm is still armed and will fire on schedule, reaching path (c). | Static reasoning |
| (f) | `SilentModeAutomation` (legacy) | `SilentModeAutomation.kt:84` — `SilentModeScheduler` object | No change needed — `SilentModeScheduler` has zero active call sites; see §Path (f) below | Dead code — 0 call sites (grep confirmed) |

> **Verification legend:** *Static code read* = insertion point confirmed by reading source; *Static — gap confirmed* = absence confirmed by reading source; *Static reasoning* = design inference, code not read; *Dead code — 0 call sites (grep confirmed)* = zero active callers confirmed by grep.

> In the Implementation Plan, the `cancel(8100)` calls for paths (a), (b), (c) are implemented via the `cancelSilentModeNotification(context)` helper defined in §File 3.

**Path (d) — reboot details:**
- **Notification 8100:** Android removes all posted notifications before `BOOT_COMPLETED` fires.
  No `cancel(8100)` call is needed in `PrayerBootReceiver`.
- **Ringer mode:** Android persists `AudioManager.ringerMode` in `Settings.Global` across reboots.
  If Aura set the phone to vibrate before the reboot, it stays on vibrate after the reboot —
  Android does not reset it. The fix must restore the ringer explicitly. `PrayerBootReceiver` reads
  `saved_ringer_mode` from `aura_silent_mode` prefs (the value saved by `enableSilentModeForPrayer`
  before switching to vibrate) and calls `audioManager.setRingerMode(savedRingerMode)`. Wrapped in
  `try/catch (SecurityException)` — Do Not Disturb (DND) access may be missing on some OEM skins,
  causing the ringer change to throw. The flag is always cleared even if the restore fails.
- **`is_silent_active` prefs flag:** Prefs persist across reboots. Without the fix, the flag stays
  `true` after boot, causing the foreground service to enter adhan mode on first tick (showing
  dead action buttons) and the next adhan to overwrite `saved_ringer_mode` with the post-boot
  ringer state rather than the user's original setting. After restoring the ringer, write
  `is_silent_active = false` and `silent_end_time = 0`.
- **Order in `PrayerBootReceiver.onReceive`:** (1) check `is_silent_active`; if true, restore
  ringer then clear prefs; (2) reschedule alarms. This is synchronous and runs before the
  `Handler.postDelayed` alarm-rescheduling block.
- **SilentOffReceiver alarm (request code 3999):** `AlarmManager` alarms do not persist across reboots;
  the auto-restore alarm is implicitly cancelled. The `PrayerBootReceiver` cleanup is definitive.

**Path (f):** `SilentModeAutomation.kt` exports the object `SilentModeScheduler`, which contains a `restoreRingerMode` private function that writes `is_silent_active = false` at `:84`. `SilentModeScheduler` has **zero call sites** in `android/` and `lib/` — verified by grep:

```
$ grep -rn "SilentModeScheduler" android/ lib/
android/app/src/main/kotlin/com/aura/hala/README.md:32:| `SilentModeAutomation.kt` | `SilentModeScheduler` (object): `cancelAll`, `cancelSilentOffAlarm`, `triggerSilentMode` (no-op) |
android/app/src/main/kotlin/com/aura/hala/SilentModeAutomation.kt:26:object SilentModeScheduler {
```

Only hits are the definition itself (`SilentModeAutomation.kt:26`) and a README documentation entry — no call sites. The object is dead code; no live code path can reach `:84`. No change needed. If `SilentModeScheduler` is ever activated in the future, `cancel(8100)` must be added to its `restoreRingerMode` function at that time.

### Dead `addAction` removal

`PrayerForegroundService.showAdhanModeNotification()` lines 592–622 reads `is_silent_active` and
calls `builder.addAction(…)` twice. Because the builder uses `setCustomBigContentView` (a
`RemoteViews`-based layout), `addAction` buttons are not rendered — Android only renders action
buttons on custom-view notifications when `DecoratedCustomViewStyle` is set. These two `addAction`
calls are dead. Remove the entire block (lines 592–622, including the `silentPrefs` read and both
`PendingIntent` constructions).

### No-Dart-change rule

No files under `lib/` are changed by this fix. Verify before raising the PR:

```
git diff --stat -- lib/
```

Expected: empty — no files under `lib/` are modified. `8100` (notification ID) and
`silent_mode_control` (channel ID) are native-only constants; `is_silent_active` is a
SharedPreferences key that Dart code could legitimately reference in other contexts and is not
included in this check.

### New channel creation

`MainActivity.createNotificationChannel()` already creates `prayer_times` and `prayer_tracking`.
Add `silent_mode_control` there:
- Importance: `IMPORTANCE_DEFAULT`
- Sound: none (`setSound(null, null)`)
- Vibration: disabled (`enableVibration(false)`)
- Badge: false (`setShowBadge(false)`)
- Rationale: `IMPORTANCE_DEFAULT` is used rather than `IMPORTANCE_LOW` to avoid OEM launchers collapsing the notification into a hidden "silent notifications" group that the user might not find. Sound and vibration are manually disabled to keep the notification silent.

### PendingIntent request codes

| Code | Use | File |
|---|---|---|
| 8100 | "Stop Vibration" PendingIntent for notification 8100 | `PrayerAlarmReceiver.kt` |
| 8101 | "Keep Vibration" PendingIntent for notification 8100 | `PrayerAlarmReceiver.kt` |

**Codes 8100 and 8101 are free.** Evidence from `contracts/notification-ids.md` (all assigned
request codes as of main @ 85a12b5):

| Assigned range | Owner |
|---|---|
| 1001–1006 (alarm) | `PrayerAlarmReceiver` prayer alarms |
| 2001–2006 (reminder) | `PrayerAlarmReceiver` +1000 offset |
| 3001–3006 (post-check) | `PrayerAlarmReceiver` +2000 offset |
| 3999 | `SilentOffReceiver` auto-restore alarm |
| 3000–3006 | `AzkarAlarmReceiver` azkar alarms |
| 5000-range | `FocusModeReceiver` base 5000 |
| 5996 | Focus Mode relaunch |
| 7001 | Daily summary (`DailySummaryReceiver`) |
| 8001 | Jumu'ah reminder (`JumuahReminderReceiver`) |
| 8001, 8002 | Foreground-service silent buttons (dead; being removed by this fix) |
| 9100 | Daily recalc (`DailyRecalcReceiver`) |
| 9999 | Test adhan |
| widgetId +1000/+2000/+5000 | `TasksWidget` |

The range 8100–8101 appears in none of these assignments. The codes 8001/8002 used by the
foreground service's dead `addAction` block are themselves being removed in this fix, so there is
no residual claim on those codes either.

### Contract update

`contracts/notification-ids.md`:
- Add row: `8100 | Silent-mode control | — | PrayerAlarmReceiver.kt (postSilentModeNotification) | No | New`
- Add channel row: `silent_mode_control | — | MainActivity.kt (createNotificationChannel) | New`

`android/app/src/main/kotlin/com/aura/hala/README.md`:
- Update the `ToggleSilentModeReceiver` row to mention notification 8100 is cancelled on
  `DISMISS_SILENT` / `EXTEND_SILENT`.
- Note `PrayerBootReceiver` now clears `is_silent_active` on boot.

---

## Alternatives Considered

### Alternative A: Apply `DecoratedCustomViewStyle` to the foreground notification

Add `.setStyle(NotificationCompat.DecoratedCustomViewStyle())` to the foreground service's
`notificationBuilder`. This would make the existing `addAction` buttons visible without a new
notification.

*   **Pros**: Fewer moving parts; no new notification ID or channel.
*   **Cons**: `DecoratedCustomViewStyle` renders the custom `RemoteViews` inside a standard
    notification frame with the app icon, app name, and timestamp — this changes the foreground
    notification's visual design. The prayer-countdown layout was designed to fill the full
    notification height; inside `DecoratedCustomViewStyle` it is demoted to a small inline card.
    The foreground notification is always visible and is the app's primary presence in the shade;
    changing its design is a UI regression.
*   **Reason for rejection:** Rejected by author — changes the foreground notification's visual
    design, which is a UI regression outside the scope of a behavior-preserving fix.

### Alternative B: Re-attach buttons to the adhan notification (IDs 1001–1006)

Restore the pre-`6514f26` behaviour by adding action buttons back to `showPrayerNotification` in
`PrayerAlarmReceiver`, conditionally when `is_silent_active`.

*   **Pros**: Historically correct; no new notification or channel.
*   **Cons**: The finding's spec constraint explicitly prohibits this: "the fix must not
    re-introduce the old problem of overloading the adhan notification (which now serves only as a
    `setFullScreenIntent` trigger with a 3-second lifespan)". A 3-second auto-dismiss notification
    cannot reliably host persistent buttons; the user may not see it before it disappears.
*   **Reason for rejection:** Rejected by author — violates the spec constraint in F68 and cannot
    reliably host persistent buttons.

---

## Non-Functional Requirements

*   **Contract stability:** New notification ID 8100 and channel `silent_mode_control` must be
    documented in `contracts/notification-ids.md` in the same commit as the code change. CLAUDE.md
    rule: "change both Dart and Kotlin + `.project-docs/contracts/` in one commit."
*   **No new permissions:** `VIBRATE` and `POST_NOTIFICATIONS` are already declared in the
    manifest; `NotificationManagerCompat.cancel` requires no additional permission.
*   **Minimum SDK 24:** `NotificationManagerCompat` is available from API 4; `PendingIntent.FLAG_IMMUTABLE`
    is available from API 23 (and is guarded by existing code patterns). No min-SDK risk.

---

## Detailed Implementation Plan

### Target Files to Modify

#### 1. `android/app/src/main/kotlin/com/aura/hala/PrayerAlarmReceiver.kt` (Modify) ⚠️ edit carefully

*   **Type / Scope:** Kotlin BroadcastReceiver — prayer alarm entry point.
*   **Proposed changes:**
    1.  At the end of `enableSilentModeForPrayer()` (after `scheduleSilentModeRestore` call,
        ~line 727), call a new private helper `postSilentModeNotification(context, prayerName, prayerNameAr)`.
    2.  Implement `postSilentModeNotification(context, prayerName, prayerNameAr)`:
        - Read `language` from `aura_prayer_times` via direct `context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE).getString("language", "en") ?: "en"` — matching the existing pattern at `PrayerAlarmReceiver.kt:772–773`. **Do not use `FlutterPrefs`**: that wrapper applies a `flutter.` key prefix and would read `flutter.language` from `FlutterSharedPreferences`, which is always absent here — it silently returns `"en"` and breaks Arabic for all Arabic-language users.
        - Build `dismissIntent` to `ToggleSilentModeReceiver` with action `DISMISS_SILENT` and extras `EXTRA_PRAYER_NAME` / `EXTRA_PRAYER_NAME_AR`; wrap in `PendingIntent.getBroadcast(ctx, 8100, …, FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT)`.
        - Build `extendIntent` to `ToggleSilentModeReceiver` with action `EXTEND_SILENT` and extras `EXTRA_PRAYER_NAME` / `EXTRA_PRAYER_NAME_AR`; wrap in `PendingIntent.getBroadcast(ctx, 8101, …, FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT)`.
        - `val builder = NotificationCompat.Builder(ctx, "silent_mode_control")` — use the two-argument constructor to associate the channel (the single-argument constructor is deprecated and silently drops notifications on API 26+).
        - Set small icon `R.drawable.ic_notification`, two `addAction` calls, `setOngoing(false)`, `setAutoCancel(false)`.
        - Wrap in `try { NotificationManagerCompat.from(ctx).notify(8100, builder.build()) } catch (e: Exception) { Log.e(TAG, …) }`.
        - Log `🔕 [SILENT_NOTIF] Posted notification 8100 for $prayerName`.

#### 2. `android/app/src/main/kotlin/com/aura/hala/PrayerForegroundService.kt` (Modify)

*   **Type / Scope:** Kotlin Service — foreground notification management.
*   **Proposed changes:**
    1.  In `showAdhanModeNotification()`, delete lines 592–622 (the entire `isSilentActive` block
        that reads `aura_silent_mode` prefs and calls `builder.addAction` twice, including both
        `PendingIntent` constructions). The `silentPrefs` local variable and `isSilentActive` read
        are only used in this block; delete those too.
    2.  No other changes to this function.

#### 3. `android/app/src/main/kotlin/com/aura/hala/ToggleSilentModeReceiver.kt` (Modify)

*   **Type / Scope:** Kotlin BroadcastReceiver (two classes in one file: `ToggleSilentModeReceiver` and `SilentOffReceiver`).
*   **Proposed changes:**

    **`ToggleSilentModeReceiver.dismissSilentMode()`** (~line 139, after writing `is_silent_active = false`):
    - Add `cancelSilentModeNotification(context)` call.

    **`ToggleSilentModeReceiver.extendSilentMode()`** (~line 205, after writing `silent_end_time = 0`):
    - Add `cancelSilentModeNotification(context)` call.

    **`SilentOffReceiver.onReceive()`** (~line 331, after writing `is_silent_active = false`):
    - Add `cancelSilentModeNotification(context)` call.

    **New helper — companion object of `ToggleSilentModeReceiver`:**

    `TAG` is `private const val` inside each class's own companion object; a top-level function cannot
    access it. Place the helper in `ToggleSilentModeReceiver`'s companion object. `SilentOffReceiver`
    (a separate top-level class in the same file) calls it as
    `ToggleSilentModeReceiver.cancelSilentModeNotification(context)`.

    ```kotlin
    // inside ToggleSilentModeReceiver companion object
    fun cancelSilentModeNotification(context: Context) {
        try {
            NotificationManagerCompat.from(context).cancel(8100)
            Log.d(TAG, "🔕 [SILENT_NOTIF] Cancelled notification 8100")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [SILENT_NOTIF] cancel failed: ${e.message}")
        }
    }
    ```

    `SilentOffReceiver.onReceive()` call site: `ToggleSilentModeReceiver.cancelSilentModeNotification(context)`.

#### 4. `android/app/src/main/kotlin/com/aura/hala/PrayerBootReceiver.kt` (Modify)

*   **Type / Scope:** Kotlin BroadcastReceiver — boot re-schedule.
*   **Proposed changes:**
    1.  At the top of `onReceive` (before the `Handler.postDelayed` alarm-rescheduling block,
        ~line 40), add a silent-mode cleanup block:
        ```
        // Android persists ringerMode across reboots; restore it if silent mode was active.
        val silentPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)
        if (silentPrefs.getBoolean("is_silent_active", false)) {
            val savedRingerMode = silentPrefs.getInt("saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
            try {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.ringerMode = savedRingerMode
                Log.d("PrayerBootReceiver", "🔕 [SILENT] Restored ringer mode to $savedRingerMode on boot")
            } catch (e: SecurityException) {
                // Do Not Disturb access may be missing on some OEM skins; still clear the flag below.
                Log.e("PrayerBootReceiver", "❌ [SILENT] Failed to restore ringer mode (DND access missing): ${e.message}")
            } catch (e: Exception) {
                Log.e("PrayerBootReceiver", "❌ [SILENT] Failed to restore ringer mode: ${e.message}")
            }
            // Always clear the flag, even if the ringer restore failed.
            silentPrefs.edit()
                .putBoolean("is_silent_active", false)
                .putLong("silent_end_time", 0)
                .apply()
            Log.d("PrayerBootReceiver", "🔕 [SILENT] Cleared stale silent-mode state on boot")
        }
        ```
    2.  No `NotificationManagerCompat.cancel(8100)` needed — Android removes all posted
        notifications before `BOOT_COMPLETED` fires.

#### 5. `android/app/src/main/kotlin/com/aura/hala/MainActivity.kt` (Modify)

*   **Type / Scope:** Kotlin Activity — notification channel registration.
*   **Proposed changes:**
    1.  In `createNotificationChannel()`, after the `prayer_tracking` channel is created (~line 156),
        add a new `silent_mode_control` channel:
        ```
        val silentChannel = NotificationChannel(
            "silent_mode_control",
            "Silent Mode Control",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Controls for the vibrate-during-prayer silent mode"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(silentChannel)
        ```
    2.  Log the creation with the existing `Log.d("MainActivity", "✅ [CHANNEL] …")` pattern.

#### 6. `.project-docs/contracts/notification-ids.md` (Modify)

*   **Type / Scope:** Contract document (Level A).
*   **Proposed changes:**
    1.  Add row to Notification IDs table:
        `| 8100 | Silent-mode control notification (vibrate-window action buttons) | — | PrayerAlarmReceiver.kt (postSilentModeNotification) | No | New (F68) |`
    2.  Add PendingIntent request-code note: `Silent-mode control PIs 8100/8101 (PrayerAlarmReceiver.postSilentModeNotification → ToggleSilentModeReceiver)`.
    3.  Add channel row:
        `| silent_mode_control | — | MainActivity.kt (createNotificationChannel) | New (F68) |`

#### 7. `android/app/src/main/kotlin/com/aura/hala/README.md` (Modify)

*   **Type / Scope:** EGM contract document for the Kotlin folder (Level A).
*   **Proposed changes:**
    1.  Update `ToggleSilentModeReceiver` row to note it cancels notification 8100 on `DISMISS_SILENT` / `EXTEND_SILENT`.
    2.  Update `PrayerBootReceiver` row to note it clears `is_silent_active` on boot.

---

### Verification Plan

*   **No-Dart-change verification** (run before the PR):
    ```
    git diff --stat -- lib/
    ```
    Expected: empty — no files under `lib/` are modified. `8100` (notification ID) and `silent_mode_control` (channel ID) are native-only constants.

*   **Kotlin unit tests** (`./gradlew :app:testDebugUnitTest`): must pass (25 existing tests); no
    new Kotlin tests are added for this change because the fix is a notification-posting call and a
    dead-code deletion, neither of which has a testable Kotlin unit path without Android instrumentation.

*   **Flutter analyze** (`flutter analyze`): must remain at 418 issues, 0 errors, 0 new.

*   **Build** (`flutter build apk --release --obfuscate --split-debug-info=build/debug-info`):
    must succeed.

*   **Device check** (nova 5T, API 29):
    - Enable silent mode in Settings → Prayer Settings.
    - Wait for a prayer adhan.
    - Confirm notification 8100 appears in the shade with both buttons.
    - Tap "Stop Vibration": confirm ringer restored, notification disappears.
    - Repeat: tap "Keep Vibration": confirm ringer stays on vibrate, notification disappears.
    - Repeat: wait 20 min (or shorten `silent_mode_duration`): confirm notification disappears and ringer is restored.
    - Confirm foreground service notification no longer shows dead action buttons.

---

*Drafted with EGM*

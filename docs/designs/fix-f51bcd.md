# Fix F51b + F51c + F51d — Daily summary accuracy

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f51bcd` (to be created from main)  
**Findings:** F51b (MEDIUM), F51c (MEDIUM), F51d (MEDIUM)  
**Files touched:**
- `android/app/src/main/kotlin/com/aura/hala/DailySummaryReceiver.kt`
- `android/app/src/main/kotlin/com/aura/hala/PrayerAlarmReceiver.kt`
- `android/app/src/main/kotlin/com/aura/hala/NativeNotificationReceiver.kt`

---

## F51b — Prune removes records before Firestore sync

### Problem

`DailySummaryReceiver.pruneOldPrayerStatuses()` removes every `prayer_status_*` key older than 7 days unconditionally. If the user does not open the app for a week, the native records are pruned before `_syncNativePrayerStatuses()` (Dart) can read and push them to Firestore. This is silent data loss: the Prayer Tracking calendar loses those days with no warning.

### Fix

Extend the prune window from 7 days to **30 days**. The records are tiny (≤ 1 825 string entries per year at 5 prayers/day, well within SharedPreferences capacity regardless of prune frequency). 30 days covers any realistic holiday or offline period; older data has no actionable value within the app's calendar view, which is bounded at 30 days.

A sync-marker approach (prune only entries whose date precedes a confirmed-sync timestamp written by Dart) would eliminate data loss regardless of offline duration, but requires Dart to write a confirmed-sync timestamp on every successful Firestore push and native code to read it. That complexity is not justified given the product's 30-day calendar limit.

Note: `pruneOldPrayerStatuses` runs only when the DailySummaryReceiver alarm fires. If that alarm is never armed the function never runs; at 1 825 entries/year growth remains negligible.

### Change (Kotlin)

**File:** `DailySummaryReceiver.kt:133`

```kotlin
// Before
val cutoffCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -7) }

// After
val cutoffCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -30) }
```

---

## F51c — Summary counts prayers not yet due

### Problem

`DailySummaryReceiver.onReceive()` checks all five prayers in `PRAYER_NAMES` against today's status keys. If the daily summary fires at (e.g.) 9 pm, Isha (typically 11:30 pm) has not yet occurred; the receiver counts it as "untracked" and shows an inflated count or an unnecessary card. Same can apply to Maghrib if the user sets an early summary time.

### Fix

Skip any prayer whose scheduled time (`fajr_time`, `dhuhr_time`, `asr_time`, `maghrib_time`, `isha_time` in `aura_prayer_times`, stored as millisecond strings) is both in the future **and** on today's date. The date guard protects against stale times: if the device missed a recalculation and `isha_time` still holds yesterday's epoch, `prayerMs > now` is false for all prayers that have not yet occurred today, producing the same inflated count through a different path. By requiring that the stored time falls on the current calendar day (`dateKey(…) == today`), stale values are treated as "already due" (conservative — avoids hiding a genuinely untracked prayer). A missing or zero key is also treated as past.

### Change (Kotlin)

**File:** `DailySummaryReceiver.kt` — replace the `val untracked = …` block inside `onReceive` (the block begins at the line `val untracked = DailySummaryCard.untrackedNames`)

```kotlin
// Before
val untracked = DailySummaryCard.untrackedNames(PRAYER_NAMES) { name ->
    prayerPrefs.contains("prayer_status_${name}_$today")
}

// After
val now = System.currentTimeMillis()
val untracked = DailySummaryCard.untrackedNames(PRAYER_NAMES) { name ->
    val timeKey = if (name == "Zuhr") "dhuhr_time" else "${name.lowercase()}_time"
    val prayerMs = prayerPrefs.getString(timeKey, null)?.toLongOrNull() ?: 0L
    // Not yet due today → treat as tracked (exclude from untracked count)
    val notYetDue = prayerMs > 0L && prayerMs > now &&
        dateKey(Calendar.getInstance().apply { timeInMillis = prayerMs }) == today
    notYetDue || prayerPrefs.contains("prayer_status_${name}_$today")
}
```

**Key mapping** (matches `NativePrayerCalculator` and `PrayerAlarmReceiver`):

| PRAYER_NAMES entry | SharedPreferences key |
|--------------------|----------------------|
| Fajr               | `fajr_time`           |
| Zuhr               | `dhuhr_time`          |
| Asr                | `asr_time`            |
| Maghrib            | `maghrib_time`        |
| Isha               | `isha_time`           |

**Note on Dhuhr/Zuhr naming:** `PRAYER_NAMES` uses `"Zuhr"` and status keys are written as `prayer_status_Zuhr_*`. Before merging, verify that the Flutter scheduling code passes `"Zuhr"` (not `"Dhuhr"`) to `schedulePostPrayerCheck` and `handleReminderAction`. S59 below confirms this on device.

---

## F51d — Status stored under action date, not prayer date

### Problem

Five write paths for `prayer_status_{name}_{date}` use the **current wall-clock date** (`java.util.Date()` / `java.util.Date()`):

| # | File | Method / location |
|---|------|-------------------|
| 1 | `PrayerAlarmReceiver.kt` | `handlePostPrayerCheckAction()` — Done / Late / Missed branches |
| 2 | `PrayerAlarmReceiver.kt` | `handleReminderAction()` — Prayed / Late / Missed branches |
| 3 | `PrayerAlarmReceiver.kt` | `onReceive()` `isPostCheck` arrival guard |
| 4 | `NativeNotificationReceiver.kt` | `onReceive()` `ACTION_MARK_PRAYED` branch |
| 5 | `PrayerAlarmReceiver.kt` | `markPrayerTracked()` companion function (Dart-side calls) |

If Isha fires at 11:30 pm and the user answers after midnight, `java.util.Date()` returns the **next day**. The status lands under `prayer_status_Isha_{tomorrow}` while today's summary looked for `prayer_status_Isha_{today}`.

### Shared helper

`DailySummaryReceiver.dateKey(cal: Calendar): String` already exists as an `internal` companion function (same package). Use it to derive the date key from `prayerTime` instead of `Date()`:

```kotlin
val dateMs = if (prayerTime > 0L) prayerTime else System.currentTimeMillis()
val prayerDate = DailySummaryReceiver.dateKey(Calendar.getInstance().apply { timeInMillis = dateMs })
```

The `Calendar` import is already present in `PrayerAlarmReceiver.kt`.

### Path 1 — `handlePostPrayerCheckAction()` — lines ~1041, 1048, 1055

Each of the three branches (`ACTION_POST_DONE`, `ACTION_POST_LATE`, `ACTION_POST_MISSED`) independently declares `val today = …format(java.util.Date())`. Replace all three with one declaration, computed from `prayerTime`, placed before the `when` block:

```kotlin
// Add before `when (action) {`
val dateMs = if (prayerTime > 0L) prayerTime else System.currentTimeMillis()
val prayerDate = DailySummaryReceiver.dateKey(Calendar.getInstance().apply { timeInMillis = dateMs })
```

Then in each branch replace `"prayer_status_${prayerName}_${today}"` → `"prayer_status_${prayerName}_${prayerDate}"` and **delete** the branch-local `val today` declaration.

### Path 2 — `handleReminderAction()` — lines ~963, 975, 987

Same pattern: three branch-local `val today` declarations (lines 963, 975, 987). Hoist one `prayerDate` declaration before the `when (action) {` block and delete the three branch-local `val today` declarations, substituting `prayerDate` in every `putString` call.

### Path 3 — `isPostCheck` arrival guard — lines ~501–502

```kotlin
// Before
val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
val statusKey = "prayer_status_${prayerName}_${today}"

// After
val dateMs = if (prayerTime > 0L) prayerTime else System.currentTimeMillis()
val today = DailySummaryReceiver.dateKey(Calendar.getInstance().apply { timeInMillis = dateMs })
val statusKey = "prayer_status_${prayerName}_${today}"
```

*(Keep the variable name `today` to avoid renaming the adjacent log strings that reference it.)*

### Path 4 — `NativeNotificationReceiver.kt:140–143` — `ACTION_MARK_PRAYED`

`prayerTimeMs` is already extracted at line 130. Replace the wall-clock date with a prayer-time-anchored date, and pass that same date to `onTrackingChanged`:

```kotlin
// Before
val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(Date())
prefs.edit().putString("prayer_status_${prayerName}_${today}", "on_time").apply()
Log.d(TAG, "✅ Marked $prayerName as prayed (syncs on next app open)")
DailySummaryCard.onTrackingChanged(context, DailySummaryReceiver.PRAYER_NAMES, today)

// After
val dateMs = if (prayerTimeMs > 0L) prayerTimeMs else System.currentTimeMillis()
val prayerDate = DailySummaryReceiver.dateKey(Calendar.getInstance().apply { timeInMillis = dateMs })
prefs.edit().putString("prayer_status_${prayerName}_${prayerDate}", "on_time").apply()
Log.d(TAG, "✅ Marked $prayerName as prayed (syncs on next app open)")
DailySummaryCard.onTrackingChanged(context, DailySummaryReceiver.PRAYER_NAMES, prayerDate)
```

Add `import java.util.Calendar` if not already present in the file.

### Path 5 — `markPrayerTracked()` — line ~469

This companion function is called from the Dart side (`notifyFlutterPrayerStatus`) with no prayer-time anchor. Add an optional `prayerDate` parameter (default null = use current date, so all existing callers require no change):

```kotlin
// Before
fun markPrayerTracked(context: Context, prayerName: String, status: String) {
    val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
    val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
    prefs.edit().putString("prayer_status_${prayerName}_${today}", status).apply()
    Log.d(TAG, "📋 [POST_CHECK] Marked $prayerName as $status (Flutter)")
    DailySummaryCard.onTrackingChanged(context, DailySummaryReceiver.PRAYER_NAMES, today)
}

// After
fun markPrayerTracked(context: Context, prayerName: String, status: String, prayerDate: String? = null) {
    val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
    val date = prayerDate
        ?: java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
    prefs.edit().putString("prayer_status_${prayerName}_${date}", status).apply()
    Log.d(TAG, "📋 [POST_CHECK] Marked $prayerName as $status (Flutter)")
    DailySummaryCard.onTrackingChanged(context, DailySummaryReceiver.PRAYER_NAMES, date)
}
```

Existing callers (Dart side, `DailySummaryCard.onTrackingChanged`) pass no fourth argument and continue to use the wall-clock date. This is correct for real-time Dart interactions (user is acting now). The parameter exists so that future callers with an explicit prayer date can avoid the midnight bug.

### Known limitation

When the user taps **"Later"** on a post-check card, `ACTION_POST_LATER` re-schedules by computing `remindAt = now + 15 min` and passes `fakeAnchor = remindAt - 30 min` as the new `prayerTime`. After F51d is applied, the arrival guard on the re-fired alarm derives its date key from that fake anchor. For Isha re-checks arriving past midnight + 30 minutes, the guard may mis-classify the day. This was broken before F51d too; the fix does not regress it. Resolving it properly requires threading the original adhan epoch through the `ACTION_POST_LATER` re-schedule cycle and is out of scope for this batch.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged — same `prayer_status_{name}_{YYYY-MM-DD}` format |
| `aura_prayer_times` keys read (F51c) | `fajr_time`, `dhuhr_time`, `asr_time`, `maghrib_time`, `isha_time` — all pre-existing |
| `DailySummaryReceiver.dateKey()` visibility | `internal` — accessible from `PrayerAlarmReceiver` and `NativeNotificationReceiver` (same package) |
| `markPrayerTracked` signature | Backward-compatible: new param is optional, all existing callers unchanged |
| Notification IDs / channels | Unchanged |
| Method-channel names | Unchanged |
| Firestore paths | Unchanged |
| New keys introduced | None |

---

## Tests

All tests are pure-function tests that require no Robolectric or SharedPreferences fake. The private methods (`pruneOldPrayerStatuses`, `handlePostPrayerCheckAction`, `handleReminderAction`) are covered by device checks.

| ID | Description | File |
|----|-------------|------|
| T1 | `DailySummaryReceiver.dateKey(cal)` for 11:30 pm on day D returns day D's date string | `DailySummaryReceiverTest.kt` |
| T2 | `DailySummaryReceiver.dateKey(cal)` for 11:55 pm on day D returns day D even when test runs at 12:05 am day D+1 | `DailySummaryReceiverTest.kt` |
| T3 | `DailySummaryCard.untrackedNames` with F51c-style predicate: prayer whose `prayerMs` is in the future AND on today's date → excluded from result | `DailySummaryCardTest.kt` |
| T4 | `DailySummaryCard.untrackedNames` with F51c-style predicate: prayer whose time has passed and no status key → included | `DailySummaryCardTest.kt` |
| T5 | `DailySummaryCard.untrackedNames` with F51c-style predicate: stale `prayerMs` (yesterday's date) → treated as past, included if no status key | `DailySummaryCardTest.kt` |
| T6 | `DailySummaryCard.untrackedNames` with F51c-style predicate: missing/zero time → treated as past, included if no status key | `DailySummaryCardTest.kt` |

Test files live under `android/app/src/test/kotlin/com/aura/hala/`.

---

## Device checks

| Step | Description |
|------|-------------|
| S57 | Set daily summary time to 30 min before Isha; when it fires, card count excludes Isha |
| S58 | Tap "Done" on Isha post-check after midnight; Prayer Tracking calendar shows the entry on the **previous** day |
| S59 | Tap "Done" on Zuhr/Dhuhr post-check; Prayer Tracking calendar shows the entry for Zuhr (not Dhuhr) — verifies naming consistency |

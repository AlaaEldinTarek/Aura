# Fix spec: D3 — F51n · F52i · F51p (safe picks)

Status: Draft

---

## Findings

### F51n — Arabic-Indic digits missing in native UI

**AdhanFullScreenActivity** (`AdhanFullScreenActivity.kt:93`):
Iqama countdown uses `String.format("%d:%02d", minutes, seconds)` — raw ASCII digits shown to
Arabic users.

**AzkarFullScreenActivity** (`AzkarFullScreenActivity.kt:317, :328`):
- Line 317: `tv.text = "${item.count}\n──\n${item.target}"` — raw ASCII digits for the azkar
  counter card (count done / target remaining).
- Line 328: `tv.text = if (isArabic) "$total / $done أذكار" else ...` — raw ASCII digits
  embedded in Arabic string.

### F52i — Wird reminder text says "pages" in juz mode

**Dart** (`notification_service.dart:1142`): fallback body hardcodes "صفحة اليوم" regardless
of mode. `$dailyPageGoal` is an unformatted raw digit in the Arabic string (CLAUDE.md rule).

**Native** (`NativeReminderCard.kt:80–81`): `bodyFor(KIND_WIRD, …)` unconditionally uses
`ArabicCount.pages(a)` / `"pages"` English. No juz variant exists.

### F51p safe picks — wrong small icon in two receivers

- `AzkarAlarmReceiver.kt:147`: `.setSmallIcon(R.mipmap.ic_launcher)` — launcher icon in
  notification tray (looks like app icon, not monochrome bell icon).
- `FocusModeService.kt:393`: same mipmap icon for the Focus Mode foreground notification.

All other native notifications use `R.drawable.ic_notification`.

---

## Root causes

**F51n**: Three distinct native UI files each format numbers independently and none calls
`ThemedNotification.withArabicNumerals()`.

**F52i**: `scheduleWirdReminders` has no `isJuzMode` parameter; the native card has no
`KIND_WIRD_JUZ` branch. `ArabicCount` has no juz plural forms.

**F51p**: Both receivers were written or copied before the `R.drawable.ic_notification`
convention was established; never updated.

---

## Fix

### Phase N1 — `android/app/src/main/kotlin/com/aura/hala/AdhanFullScreenActivity.kt`

In the ticker `Runnable`, after computing `minutes` / `seconds` (line 92–93), replace:
```kotlin
countdown.text = String.format("%d:%02d", minutes, seconds)
```
with:
```kotlin
val formatted = String.format("%d:%02d", minutes, seconds)
countdown.text = if (isArabic) ThemedNotification.withArabicNumerals(formatted) else formatted
```
`isArabic` is already in scope (used at line 82 and line 97).

---

### Phase N2 — `android/app/src/main/kotlin/com/aura/hala/AzkarFullScreenActivity.kt`

**Line 317** (inside the `else` branch of `bindCounter`):
```kotlin
// Before:
tv.text = "${item.count}\n──\n${item.target}"
// After:
tv.text = if (isArabic) {
    "${ThemedNotification.withArabicNumerals(item.count.toString())}\n──\n" +
        ThemedNotification.withArabicNumerals(item.target.toString())
} else {
    "${item.count}\n──\n${item.target}"
}
```

**Line 328** (`updateProgress`):
```kotlin
// Before:
tv.text = if (isArabic) "$total / $done أذكار" else "$done / $total azkar"
// After:
tv.text = if (isArabic) {
    "${ThemedNotification.withArabicNumerals(total.toString())} / " +
        "${ThemedNotification.withArabicNumerals(done.toString())} أذكار"
} else {
    "$done / $total azkar"
}
```

---

### Phase I1 — Wird juz mode text

#### `android/app/src/main/kotlin/com/aura/hala/ArabicCount.kt`

Add a juz plural helper after `minutes`:
```kotlin
fun juzParts(count: Int): String = phrase(count, "جزء", "جزءان", "أجزاء", "جزء واحد")
```

#### `android/app/src/main/kotlin/com/aura/hala/NativeReminderCard.kt`

Add `KIND_WIRD_JUZ` constant in the companion (after `KIND_WIRD`):
```kotlin
const val KIND_WIRD_JUZ = "wird_juz"
```

Add English juz helper (after `tasks`):
```kotlin
private fun juzParts(a: Int, isArabic: Boolean): String =
    if (isArabic) ArabicCount.juzParts(a) else "$a ${if (a == 1) "juz" else "juz"}"
```

Add `KIND_WIRD_JUZ` branch in `bodyFor`, before the `else`:
```kotlin
KIND_WIRD_JUZ ->
    if (isArabic) "اقرأ وردك اليومي — ${ArabicCount.juzParts(a)} اليوم" else "Read your daily Wird — ${juzParts(a, false)} today"
```

Also add `KIND_WIRD_JUZ` to `titleFor` (same title as KIND_WIRD):
```kotlin
KIND_WIRD, KIND_WIRD_JUZ -> if (isArabic) "تذكير الورد" else "Wird Reminder"
```

#### `lib/core/services/notification_service.dart`

1. Add `isJuzMode` parameter (defaults `false` for backwards compat):
```dart
Future<void> scheduleWirdReminders({
  required List<String> reminderTimes,
  required int dailyPageGoal,
  bool isJuzMode = false,   // ← new
}) async {
```

2. Fix Arabic fallback body — use `NumberFormatter.withArabicNumerals` and juz text when in
   juz mode:
```dart
final body = isArabic
    ? isJuzMode
        ? 'اقرأ وردك اليومي — ${NumberFormatter.withArabicNumerals("$dailyPageGoal")} جزء اليوم'
        : 'اقرأ وردك اليومي — ${NumberFormatter.withArabicNumerals("$dailyPageGoal")} صفحة اليوم'
    : isJuzMode
        ? 'Read your daily Wird — $dailyPageGoal juz today'
        : 'Read your daily Wird — $dailyPageGoal pages today';
```

3. Pass `'kind': isJuzMode ? 'wird_juz' : 'wird'` in the native channel call:
```dart
'kind': isJuzMode ? 'wird_juz' : 'wird',
```

---

### Phase P1 — `AzkarAlarmReceiver.kt` + `FocusModeService.kt`

**`AzkarAlarmReceiver.kt:147`**:
```kotlin
// Before:
.setSmallIcon(R.mipmap.ic_launcher)
// After:
.setSmallIcon(R.drawable.ic_notification)
```

**`FocusModeService.kt:393`**:
```kotlin
// Before:
.setSmallIcon(R.mipmap.ic_launcher)
// After:
.setSmallIcon(R.drawable.ic_notification)
```

---

## Tests

| ID | File | What it checks |
|----|------|----------------|
| T1 | test/core/services/f51n_source_test.dart | AdhanFullScreenActivity uses `withArabicNumerals` on countdown |
| T2 | (same) | AzkarFullScreenActivity counter uses `withArabicNumerals` on item.count / item.target |
| T3 | (same) | AzkarFullScreenActivity progress uses `withArabicNumerals` on total and done |
| T4 | test/core/services/f52i_source_test.dart | `scheduleWirdReminders` has `isJuzMode` param |
| T5 | (same) | Dart passes `'wird_juz'` kind when `isJuzMode` is true |
| T6 | (same) | Dart uses `NumberFormatter.withArabicNumerals` for `dailyPageGoal` in body |
| T7 | (same) | `ArabicCount.juzParts` function declared |
| T8 | (same) | `NativeReminderCard.KIND_WIRD_JUZ` constant declared |
| T9 | (same) | `NativeReminderCard.bodyFor` handles `KIND_WIRD_JUZ` |
| T10 | test/core/services/f51p_source_test.dart | AzkarAlarmReceiver uses `ic_notification` |
| T11 | (same) | FocusModeService uses `ic_notification` |

---

## Device checks

| ID | How to run | Expected |
|----|-----------|---------|
| S-F51n-1 | Switch to Arabic, trigger iqama reminder via test tool | Countdown shows Arabic-Indic digits (٠–٩) |
| S-F51n-2 | Switch to Arabic, open azkar full-screen | Counter cards and progress show Arabic-Indic digits |
| S-F52i-1 | Enable juz mode, check wird notification in shade | Notification body says "جزء واحد اليوم" not "صفحة" |
| S-F51p-1 | Long-press any azkar or focus-mode notification | Small icon is monochrome bell, not launcher logo |

---

## Contracts

No prefs keys, MethodChannels, notification IDs, channel IDs, or Firestore paths change.

`KIND_WIRD_JUZ = "wird_juz"` is a new string sent over the existing
`scheduleNativeNotification` method channel — additive, no old values removed.

---

## Phases

| Phase | File(s) | Scope |
|-------|---------|-------|
| N1 | `android/…/AdhanFullScreenActivity.kt` | Arabic-Indic iqama countdown |
| N2 | `android/…/AzkarFullScreenActivity.kt` | Arabic-Indic azkar counter + progress |
| I1 | `lib/core/services/notification_service.dart` · `android/…/ArabicCount.kt` · `android/…/NativeReminderCard.kt` | Wird juz text + Arabic numerals |
| P1 | `android/…/AzkarAlarmReceiver.kt` · `android/…/FocusModeService.kt` | Small icon mipmap → drawable |

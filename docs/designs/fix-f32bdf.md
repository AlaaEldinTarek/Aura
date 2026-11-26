# Fix spec: F32b + F32d + F32f

**Status:** Draft — not yet approved for code  
**Branch:** `fix/f32bdf` (from main 91d3ffd)  
**Files touched:** `lib/features/home/home_screen.dart`, `lib/features/prayer/prayer_screen.dart`, `test/features/home/f32bdf_source_test.dart`

---

## Findings

### F32b — Prefs write during build (home_screen.dart)
`FutureBuilder(future: _getStreak())` at line 1386 creates a **new Future on every rebuild**.  
`_getStreak()` (line 1710) writes `task_streak_count = 0` to SharedPreferences when the streak date is stale — a prefs write triggered by the build phase on every layout pass.

### F32d — Tutorial retry loop never stops after dispose (home_screen.dart)
`_launchTutorialWhenActive()` (lines 97–128) reschedules itself via `Future.delayed(300 ms)` whenever `!mounted`.  
`dispose()` (line 214) does not clear `_pendingTutorialLaunch`, so after the widget is disposed the loop runs forever because `mounted` is permanently `false` and `_pendingTutorialLaunch` is never cleared.

### F32f — Countdown ring shows "Zuhr" on Friday (prayer_screen.dart)
`CircularCountdownTimer` at line 762 passes  
`prayerName: isArabic ? nextPrayer.nameAr : nextPrayer.name`  
`nextPrayer.name` is the raw canonical name (`'Dhuhr'`/`'Zuhr'`), never `'Jumu\'ah'`.  
On Friday, the ring label should be "Jumu'ah" / "الجمعة" (CLAUDE.md rule: use `getPrayerDisplayName`).

---

## Fixes

### P1 — F32b: cache the streak future

Add a `Future<int>? _streakFuture` field to `_HomeScreenState`.  
Initialise it in `initState` (`_streakFuture = _getStreak()`).  
Refresh it whenever the streak may have changed:
- after `TaskService.instance.incrementTaskStreak()` (line 1675): `_streakFuture = _getStreak();` inside the same `setState` call.

Replace `future: _getStreak()` with `future: _streakFuture!` in the FutureBuilder.

No behaviour change: the streak value is the same; prefs writes now happen once on init and once after the last task is completed, not on every rebuild.

### P1 — F32d: clear flag on dispose

In the existing `dispose()` override (line 214), add `_pendingTutorialLaunch = false;` before `super.dispose()`.

No behaviour change: the tutorial logic is unaffected while the widget is mounted; the loop simply stops immediately on dispose.

### P1 — F32f: use getPrayerDisplayName for the ring label

Add `import '../../core/utils/prayer_time_rules.dart';` to `prayer_screen.dart` (alongside other utils imports, line 24–28 area).

Replace line 762:
```dart
// before
prayerName: isArabic ? nextPrayer.nameAr : nextPrayer.name,
// after
prayerName: getPrayerDisplayName(nextPrayer.name, isArabic: isArabic),
```

`getPrayerDisplayName` returns `'Jumu\'ah'` / `'الجمعة'` on Fridays for Dhuhr/Zuhr and the standard name otherwise.

Also add F32f to `findings.md` under F32.

---

## Tests (test/features/home/f32bdf_source_test.dart)

**T1 — F32b static guard**: the `_HomeScreenState` class has a field typed `Future<int>?` whose name contains `streak`; the `FutureBuilder` in `build` does **not** call `_getStreak()` directly (source-text test on `home_screen.dart`).

**T2 — F32d dispose clears flag**: `dispose()` body in `home_screen.dart` contains `_pendingTutorialLaunch = false` (source-text test).

**T3 — F32f ring uses getPrayerDisplayName**: `prayer_screen.dart` line in the `CircularCountdownTimer` block contains `getPrayerDisplayName` (source-text test).

---

## Contracts / risks

- No prefs key changes.  
- No Firestore changes.  
- No notification IDs changed.  
- `prayer_screen.dart` is on the "edit carefully" list (CLAUDE.md). The change is a single-line expression swap; no logic change.  
- `nextPrayer.nameAr` was the Arabic fallback. `getPrayerDisplayName(name, isArabic: true)` returns the same Arabic name for all prayers except Dhuhr/Zuhr on Fridays (where it returns `'الجمعة'` instead). This is the intended behaviour.

---

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| P1    | spec (this file) | Draft |
| P1    | F32b + F32d fixes in home_screen.dart | pending approve |
| P1    | F32f fix in prayer_screen.dart | pending approve |
| P1    | source-text tests T1–T3 | pending approve |
| P1    | F32f entry added to findings.md | pending approve |

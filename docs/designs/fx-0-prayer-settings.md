# FX-0 — Prayer settings: correct method / madhab, per-date times, full refresh

Author: Alaa Eldin Tarek · Date: 2026-11-07 · Status: Approved (2026-11-07) · Findings:
F36a, F36c, F52a, F53a, F51p · Fix-track rule: [ADR 0001](../../.project-docs/decisions/0001-fix-track-before-refactor.md)
· Decision record: [fx-0-decisions.md](fx-0-decisions.md) · Modules:
[prayer.md](../../.project-docs/modules/prayer.md), [notifications-native.md](../../.project-docs/modules/notifications-native.md)
· Contracts: [prefs-keys.md](../../.project-docs/contracts/prefs-keys.md),
[method-channels.md](../../.project-docs/contracts/method-channels.md)

**Terms used in this spec**
- *Approval levels* (project rule): Level A = docs; Level B = tooling and test infrastructure, approved with the
  phrase "approve B" (unrelated to Option B below); Level C = production code and test cases, approved with
  "approve phase FX-0". One level never implies another.
- *`makkah`*: the internal enum name for Umm al-Qura.
- *Post-prayer check*: a notification about 30 min after a prayer asking whether it was prayed (Done / Late /
  Missed); it is an AlarmManager alarm with request code = prayer code + 2000.
- *Pn*: Problem item n. *F-numbers*: entries in `.project-docs/reference/findings.md`.
- *§ Changes n*: subsection n of Technical Plan › Changes. *Item n*: item n of the Detailed Implementation Plan.
  *Commit n*: entry n of § Commit order.
- *Code lines*: lines that are not blank and do not start with `//`, `/*`, `*`, `import`, `export`, `part` or
  `package` (after trimming). Used for the Kotlin port estimate and stop rule (item 13), on both sides.
- *Evidence tags*: `VERIFIED-static` (read in code, not run), `VERIFIED-run` (executed), `UNVERIFIED`.

## Overview
Aura calculates prayer times in two places: Dart (the `adhan` package, 2.0.0+1) for the UI, widgets and the cached
days, and Kotlin (`NativePrayerCalculator`) for alarms when the app is not running. FX-0 makes both produce the
times the user selected in settings, for the date asked for, and makes every settings change take effect right away
in the UI, the alarms, the widgets and the native data.

The `adhan` package is the source of truth. App output must equal package output plus the documented app adjustments
(today only Umm al-Qura Dhuhr +3 min). Kotlin must match the package within ±1 min for every method, including
Moonsighting Committee, verified by new tests.

## Problem
1. **Wrong Asr for Hanafi users (F36a).** The settings screens store `'Hanafi'`, but the notifier compares it with the
   lowercase enum name `hanafi`, so it always falls back to Shafi and sends `'shafi'` to native. A Hanafi user sees
   and hears Asr at the Shafi time, which is earlier.
2. **Wrong method for five UI choices (F36a).** `'MoonsightingCommittee'`, `'Singapore'` and `'Turkey'` fall back to
   Muslim World League; `'Qatar'` maps to Umm al-Qura and `'Dubai'` to Kuwait. Users of these methods get another
   method's times.
3. **Settings changes don't take effect (F36c, F52a).** The prayer settings page saves without recalculating. The
   Settings page recalculates, but the once-per-day side-effects guard skips alarms, post-prayer checks, widgets,
   native data and the cached days. `/iqama_settings` saves and never reloads. Old times stay active until the next
   resume or the next day.
4. **Times for other dates are today's times shifted (F53a).** The service always calculates today and adds whole
   days, so the cached days 1–2 are off by the daily change in prayer times. Native alarms use these cached values
   when the app was not opened. This shift does not cause a 1-hour error across DST (exact 24 h on an absolute
   instant; see item 20 for the F53a correction).
5. **Native times differ from Dart times for every method (F51p).** Kotlin recognises only 9 method names, ignores
   method adjustments (e.g. MWL Dhuhr +1), uses sunset for Tehran Maghrib instead of 4.5°, uses a 1/7-night
   high-latitude rule instead of the package's middle-of-the-night bound, truncates minutes instead of rounding, uses
   a less precise solar-position formula, has no Qatar (90-min Isha) or Moonsighting Committee (seasonal) logic, and
   uses one UTC offset per day. An alarm can fire at a different minute than the time shown in the app. The single
   per-day offset causes a 1-hour error on DST days in zones that change clocks after the 00:05 recalculation (e.g.
   London, Toronto); Cairo changes at midnight and is not affected.

## Goals
1. Every UI method maps to its exact `adhan` method; the stored madhab (`'Hanafi'` / `'Shafi'`) is applied as stored.
   Tests: app output == package output + documented app adjustments, for every method × madhab.
2. Kotlin matches the package within ±1 min for every method (including Moonsighting Committee) at every city and
   date of the golden fixture (list in § Changes 7). Reason: the adhan users hear must equal the time
   the app shows, also on the fallback path (author rule, 2026-11-07). Each native divergence in Problem 5 is listed
   and resolved.
3. Any method, madhab or iqama change, from the Settings page or the prayer settings page, immediately recalculates and
   refreshes adhan alarms, post-prayer checks, widgets, native data (`updatePrayerTimes`) and the cached days.
4. Times for any date are calculated for that date, with no whole-day shift.
5. Method and madhab strings are a contract: any change to them updates Dart, Kotlin and `.project-docs/contracts/`
   in one commit.
6. Dart precomputes 7 days for native (Option B, chosen 2026-11-07): the week covers normal gaps between opens; a
   larger window is possible but grows the prefs rewrite done on every open.
7. Play Store release notes cover every user whose times change: Hanafi Asr, and users of Qatar, Dubai, Turkey,
   Singapore and Moonsighting Committee. Native parity and the per-date fix also move alarm times for other users
   (about 1–2 min per cached day, and 1 h across DST only when Kotlin calculates); the notes cover them with one
   general line, no technical details:
   - EN: "More accurate adhan timing when the app isn't open, including daylight-saving changes."
   - AR: "تحسين دقة توقيت الأذان عندما لا يكون التطبيق مفتوحًا، بما في ذلك أيام تغيير التوقيت الصيفي."

## Non-Goals
- New features, new UI or an in-app notice about changed times (release notes only). The one UI text change is the
  Dubai label (§ Changes 1): its "(approximate)" qualifier becomes false, so the author ruled it in scope.
- Prefs key renames, new prefs keys, Firestore schema changes, notification ID or channel changes, MethodChannel
  changes.
- Umm al-Qura Ramadan Isha +30 min (package note; not applied today).
- Changing the Umm al-Qura Dhuhr +3 min adjustment (kept, applied identically in Dart and Kotlin).
- Iqama countdown for alarms armed for tomorrow (new finding F54a, MEDIUM, see Risks).
- Other prayer findings (e.g. F36b stale next prayer, F52b after-midnight statuses, F49f duplicate enums, F51p's
  Jumu'ah symptom) unless a change below requires touching them.

## Open Questions
- None as of 2026-11-07.

## Critical User Journeys (CUJs)
### CUJ 1: Hanafi user gets the Hanafi Asr
- **Given**: Asr madhab is stored as `'Hanafi'`; the app has a location.
- **When**: the app calculates times (cold start, resume, or native recalculation at 00:05).
- **Then**: the Asr shown, the widget Asr and the Asr adhan alarm all equal the package's Hanafi Asr for that date.

### CUJ 2: User changes method or madhab
- **Given**: today's alarms are set for method X; some of today's prayers are still ahead.
- **When**: the user picks method Y (or the other madhab) on the Settings page or the prayer settings page.
- **Then**: without restarting, the screens, widgets, foreground notification, adhan alarms and cached days use
  method Y. No adhan alarm fires at a method-X time. A prayer whose new time is already past does not fire.
  Exceptions: (a) a post-prayer check whose new time + 30 min is already past keeps its old alarm and fires once;
  (b) if a prayer's old time already fired and its new time is later (Shafi → Hanafi after Asr), today's Asr is armed
  again and a second adhan is prevented only by the existing 6-hour duplicate guard; that post-check may ask twice.

### CUJ 3: User changes iqama minutes
- **Given**: iqama for Maghrib is 5 min; today's Maghrib is still ahead.
- **When**: the user sets it to 10 min in `/iqama_settings`.
- **Then**: today's Maghrib adhan screen and the foreground notification count down to adhan + 10 min.

### CUJ 4: App not opened for several days, across a DST change
- **Given**: the user last opened the app on day D; DST starts on day D+2.
- **When**: the adhan alarms fire on D+1 to D+3 while the app stays closed.
- **Then**: each alarm fires at the package time for that date (cached path: exact), including the day DST starts.

### CUJ 5: User of a corrected method (Qatar, Dubai, Turkey, Singapore, Moonsighting Committee)
- **Given**: the stored method is one of these five.
- **When**: the user updates to the FX-0 release and opens the app.
- **Then**: the shown times and the alarms equal that method's package times; the release notes cover the change.

## Technical Plan (Architecture)
### Current flow and where it breaks
```text
 Settings page / prayer settings page / Iqama screen
        │ writes prefs (calculation_method, asr_madhab, iqama_minutes)
        ▼
 PrayerTimesNotifier.loadPrayerTimes(now)
   method mapping   ── 5 UI values mapped wrong .................... (P2)
   madhab mapping   ── 'Hanafi' ≠ 'hanafi' → Shafi ................. (P1)
        │
        ▼
 PrayerTimesService.getPrayerTimes(date)
   today's times + whole-day shift ................................ (P4)
        │
        ▼
 side effects (once per day per notifier: skipped on 2nd load) ..... (P3)
   ├─ post-prayer checks, adhan alarms (future times only, no cancel)
   ├─ daily task digest, Firestore record cleanup
   ├─ widgets, desktop timers
   ├─ updatePrayerTimes → native prefs: *_time, *_iqama_time, prayer_calc_method, prayer_asr_madhab
   └─ cacheAccuratePrayerTimes (platform channel, handled in MainActivity) → cached_{date}_* for today, +1, +2
        │
        ▼
 Kotlin (00:05 DailyRecalcReceiver, WorkManager, foreground stale check, after Fajr/Isha)
   NativePrayerCalculator.calculateAndSave
     cached day ?: own calculation  ── own astronomy differs ........ (P5)
     reschedule adhan alarms
```

### Options — chosen: B (author, 2026-11-07)
**Option A — Kotlin parity, cache stays at today + 2.** Described and rejected as Alt-1.

**Option B — Dart precomputes 7 days; Kotlin is the fallback.** The cache holds today … +6 (42 keys; same key format,
same channel). Kotlin uses its own calculation only when the needed day is not cached (normally after 6 days without
an open; on the evening of day +6 after Isha it already needs day +7) and logs a fallback line when it does. Kotlin
still matches the package (Goal 2), so the fallback is as accurate as the cache.

| | A | B |
| --- | --- | --- |
| Cache window | 3 days, 18 prefs strings | 7 days, 42 prefs strings |
| Kotlin work | full parity | the same full parity |
| When Kotlin times reach users | after 2 days without opening | after 6 days without opening |
| Failure: Kotlin parity bug, or a future method change missed in Kotlin | reaches users after 2 days closed | reaches users after 6 days closed |
| Failure: Dart calculation bug | affects 3 cached days | affects 7 cached days (same single source, same tests) |

### Changes (chosen design, Option B)
#### 1. Method mapping (P2)
Five values are added to the internal `CalculationMethod` enum: `qatar`, `dubai`, `turkey`, `singapore`,
`moonsightingCommittee`. One public mapping function turns each stored UI string into its own value (`'Qatar'` no
longer → `makkah`, `'Dubai'` no longer → `kuwait`), and each value maps to its package method. The enum names are
what native receives as `prayer_calc_method`, so they are contract strings; Kotlin's method table gains the same five
names in the same commit. Stored prefs values do not change. The picker's English name `'Dubai (approximate)'`
becomes `'Dubai'`; the Arabic name `'دبي'` already has no qualifier; the stored value `'Dubai'` does not change.

#### 2. Madhab (P1)
A public mapping function matches the stored madhab case-insensitively (`'Hanafi'` → `hanafi`), so native receives
`'hanafi'`, which Kotlin already expects. Stored values do not change.

#### 3. Per-date calculation (P4)
Each date is calculated for itself with the package's date-based constructor, so every cached day has its own sun
position, and each instant converts to local time with its own UTC offset.

#### 4. Refresh on every input change (P3)
**Fingerprint.** The once-per-day guard becomes an input fingerprint: today's date + method + madhab + iqama minutes
+ the seven days' calculated times. Method and madhab stay in it even though they change the times, so native always
receives the new strings. Putting the calculated times in it covers method, madhab, location and code-level
adjustment changes (adjustments change only with an app update) with one rule; iqama is in it directly. The window,
the fingerprint and the next-occurrence selection always use the wall-clock local date, independent of the `date`
argument of `loadPrayerTimes` (all live callers pass `DateTime.now()`).

**Which effects it gates.** Only prayer-derived effects run on a fingerprint change: post-prayer checks, adhan
alarms, widgets, desktop timers, `updatePrayerTimes` and the cached days. The daily task digest (reads Firestore)
and the future-record cleanup (deletes Firestore records) keep the once-per-day date guard unchanged.

**Concurrency and failure.** The fingerprint is compared and stored synchronously before the async side effects
start (as the date guard is today). Each run takes a generation number (a static counter, shared by all notifier
instances); before each platform write it checks that it is still the latest run and stops otherwise. Order inside a
run: widgets and desktop timers, `updatePrayerTimes`, then the cache write, then adhan alarms and post-checks, each in
its own try/catch, so a native recalculation that runs in between reads the new data (item 10). A failed write is not retried by the same notifier; the next app open or resume creates a new notifier with an
empty fingerprint and rewrites everything (accepted risk).

**Triggers.**
- method / madhab: the Settings page and the prayer settings page save, then call `loadPrayerTimes(DateTime.now())`;
- iqama: `/iqama_settings` saves, then calls `loadPrayerTimes(DateTime.now())` (today it does not reload);
- location: picked up by the next `loadPrayerTimes` (screen open, settings save, resume) after the 15-min location
  cache expires and the new fix moves the times; the per-minute tick does not fetch a location; the desktop location
  dialog already recreates the notifier;
- app open and resume: the notifier is recreated with an empty fingerprint, so every open rewrites all 7 days (today's
  behaviour for 3 days, kept).

**Overwrite.** The cache write removes every `cached_*` key and writes the new set in one native editor commit, so
old days never survive (`MainActivity.kt:698–704`, `VERIFIED-static`).

#### 5. Stale alarms
The scheduler skips past times and never cancels, so a change that moves a prayer earlier (Hanafi → Shafi Asr) would
leave the old, later alarm armed (`VERIFIED-static`; device `UNVERIFIED`). "Cancel all, then schedule the future ones"
is not safe: after Isha every prayer of today is past, so it would also cancel the tomorrow-Fajr alarm set by native
code and schedule nothing. Instead:
- **Adhan alarms**: each of the five prayers (request codes 1001, 1003–1006; 1002 = Sunrise has no adhan alarm and is
  untouched) is scheduled at its **next occurrence** — today's time if still ahead, else tomorrow's from cached day
  +1. Android replaces an alarm whose `PendingIntent` is equal (same component, no action, same request code), so the
  new alarm replaces the old one.
- **Post-prayer checks**: never cancelled. If the new time + 30 min is still ahead, the normal schedule call replaces
  the old check (equal `PendingIntent`, request code + 2000). If it has already passed, the old check is kept and
  fires once at its old time (author, 2026-11-07). The cancel call is not used because it also dismisses a check
  notification that is already showing.
- **Later new time after the old one fired** (Shafi → Hanafi after Asr): today's Asr is armed again; a second adhan
  is prevented only by the existing 6-hour duplicate guard in the alarm receiver, which FX-0 relies on and does not
  change. The post-check may ask twice.
- **Pre-prayer reminders**: no reminder alarm is scheduled automatically. The reminder channel is called only by the
  user's "remind me later" snooze; it is user-started, short-lived and out of scope.
- **Rule (author, 2026-11-07):** no alarm is ever cancelled without its replacement already scheduled. FX-0 adds no
  cancel call.

Same notification IDs; no new IDs or channels. Desktop gets the same refresh, because the provider already calls the
desktop scheduler inside the side effects (item 10); no desktop file changes.

#### 6. Kotlin parity (P5)
Each divergence is resolved by porting the package's logic line by line into a new Kotlin folder `adhan/` that
mirrors the package's files, keeping the package's MIT licence notice (item 13). Alt-6, a JVM library, is the
fallback if the port grows beyond the limit in item 13:

| Divergence | Today (Kotlin) | Package | Change |
| --- | --- | --- | --- |
| Method parameters | 9 names, angles only | 12 methods, angles / interval / Maghrib angle / adjustments | method table copied from the package |
| Method adjustments | ignored (except makkah Dhuhr +3) | per method (e.g. MWL Dhuhr +1, Turkey 4 prayers) | applied; makkah keeps +3 |
| Tehran Maghrib | sunset | 4.5° below horizon | Maghrib angle per method |
| High latitude | 1/7 night only when the angle is unreachable, plus a hard clamp | night-portion bound applied every day | package bound logic replaces fallback and clamp |
| Minutes | truncated | rounded to nearest minute (one mode for all methods) | round the same way |
| UTC offset | one per day | per instant | compute in UTC, convert per instant |
| Solar position | low-precision formula | package solar coordinates / solar time | ported |
| Qatar Isha | unknown name → MWL | Maghrib + 90 min | fixed-interval Isha |
| Moonsighting Committee | unknown name → MWL | seasonal Fajr/Isha bounds, ≥ 55° rule | ported exactly |

#### 7. Tests
- **Mapping:** every UI method string × `'Shafi'` / `'Hanafi'` through the two public mapping functions, then the
  service; output equals the fixture rows (app == package + documented adjustments; Umm al-Qura Dhuhr +3, nothing
  else).
- **Per-date:** each of 7 consecutive days equals the package for that date, compared as epoch ms; the Cairo windows
  start 2026-04-21 and 2026-10-26, so they contain its 2026 DST days (item 4).
- **Golden fixture:** a generator script writes package output (+ documented adjustments) for every city × date ×
  method × madhab:

  | City | Lat | Lng | IANA zone |
  | --- | --- | --- | --- |
  | Cairo | 30.0444 | 31.2357 | Africa/Cairo |
  | Makkah | 21.4225 | 39.8262 | Asia/Riyadh |
  | Doha | 25.2854 | 51.5310 | Asia/Qatar |
  | Dubai | 25.2048 | 55.2708 | Asia/Dubai |
  | Istanbul | 41.0082 | 28.9784 | Europe/Istanbul |
  | Singapore | 1.3521 | 103.8198 | Asia/Singapore |
  | Karachi | 24.8607 | 67.0011 | Asia/Karachi |
  | Tehran | 35.6892 | 51.3890 | Asia/Tehran |
  | Toronto | 43.6532 | −79.3832 | America/Toronto |
  | New York | 40.7128 | −74.0060 | America/New_York |
  | London | 51.5074 | −0.1278 | Europe/London |
  | Birmingham (UK) | 52.4862 | −1.8904 | Europe/London |
  | Oslo | 59.9139 | 10.7522 | Europe/Oslo |

  Year 2026. 10 dates: 4 seasonal (2026-03-20, 2026-06-21, 2026-09-23, 2026-12-21) and 6 DST change days
  (2026-04-24 / 2026-10-29 Cairo, 2026-03-29 / 2026-10-25 London, 2026-03-08 / 2026-11-01 Toronto and New York).
  Methods: all 14 internal names (the 12 package-backed ones plus `fixedAngle` = Egyptian parameters and
  `proportional` = MWL parameters, as in Dart). Every date is generated for every city, Oslo included:
  13 × 10 × 14 × 2 = 3,640 rows.
- **Kotlin parity:** a JVM test checks every fixture row within ±1 min, passing the row's IANA zone to the
  calculation, and asserts each DST date's exact transition instant (table in item 6; guards the hard-coded dates).
- **Refresh:** the trigger tests in item 9 (Detailed Implementation Plan).
- Kotlin JVM tests need `android/app/src/test/` and one test-only dependency, `testImplementation("junit:junit:4.13.2")`
  (Level B; the "approve B" request names exactly this). Nothing is added to `implementation`, so the release APK is
  unchanged.

Neither option changes notification IDs, channels, MethodChannels or prefs key formats. The only contract change is
the five new `prayer_calc_method` strings, committed with Dart, Kotlin and `contracts/` together.

### Delivery
- **Branch and PR:** all work on `fix/fx-0-prayer-settings`, merged by PR (the author pushes and merges).
- **Order:** the 13 commits in § Commit order (Detailed Implementation Plan). Every commit builds and passes its
  tests; the PR is merged only as a whole.
- **Device scenarios, run before (current build, baseline) and after (FX-0 build)** on the nova 5T (API 29).
  Existing ones from `.project-docs/reference/device-checklist.md`: S01 (adhan at the shown time), S06 (post-prayer
  check about 30 min after the new time), S11 (Jumu'ah reminder still fires — regression only), S13 (widgets show
  the new times), S17 (boot reschedule), S18 (stale recalculation across midnight). New ones, added to the checklist:
  - S29 Hanafi Asr: set Hanafi → shown Asr, widget and adhan match the package Hanafi time.
  - S30 No stale alarm: with Hanafi set and Shafi Asr already past, switch to Shafi → no Asr adhan fires today
    (check `dumpsys alarm` before and after).
  - S31 Iqama change: before today's Maghrib, change Maghrib iqama → today's Maghrib adhan screen counts down to the
    new iqama time.
  - S32 App closed for days: open once, then advance the device date 3 and 6 days without opening → alarms match
    the package times for those dates (cached path, no fallback log); `cached_*` keys hold only today … +6.
  - S33 Corrected methods: for Qatar, Dubai, Turkey, Singapore and Moonsighting Committee, compare shown times with
    the package output for the device's location.
  - S34 Tomorrow's Fajr after Isha: open the app after Isha → `dumpsys alarm` shows ID 1001 armed for tomorrow's
    Fajr.
  - S35 Later Asr after the old one fired: with Shafi set and Shafi Asr already fired, switch to Hanafi → no second
    Asr adhan today.

## Alternatives Considered
### Alt-1: Kotlin parity with the cache kept at today + 2 (Option A)
- **Pros**: no change to the cache window; 18 prefs strings instead of 42.
- **Cons**: the same full Kotlin parity as B, so no Kotlin work is saved; Kotlin's own times reach users after 2 days
  without opening the app; a future method change missed in Kotlin shows up after 2 days.
- **Reason for rejection**: rejected by the author (2026-11-07, [decision record](fx-0-decisions.md), decision 7): B
  fixes F53a structurally, because Dart's per-date times cover the whole week, and takes Kotlin off the daily path.

### Alt-2: A separate "reload after settings change" entry point
- **Pros**: smallest change to the notifier; the settings screens call one method.
- **Cons**: catches only the screens that call it; a location change would still hit the once-per-day guard.
- **Reason for rejection**: rejected by the author when approving the Technical Plan (2026-11-07): the fingerprint
  (§ Changes 4) covers method, madhab, iqama, location and adjustment changes with one rule.

### Alt-3: A Kotlin approximation of Moonsighting Committee with a 2-min ceiling
- **Pros**: no port of the seasonal logic.
- **Cons**: without the seasonal terms the error at London/Toronto would very likely exceed 2 min (the seasonal Isha
  bound moves by tens of minutes over the year); the exact package logic is about 60 lines of piecewise-linear math.
- **Reason for rejection**: rejected by the author during review resolution (2026-11-07; replaces the approximation
  chosen earlier in the [decision record](fx-0-decisions.md), decision 1).

### Alt-4: An in-app notice about changed times
- **Pros**: users of the corrected methods and Hanafi users would see why their times moved.
- **Cons**: adds UI (new screen or dialog, new strings in both languages), which the Non-Goals exclude.
- **Reason for rejection**: rejected by the author ([decision record](fx-0-decisions.md), decision 4): release notes
  only (Goal 7).

### Alt-5: Drop the Umm al-Qura Dhuhr +3 min so the app equals the package exactly
- **Pros**: one less adjustment.
- **Cons**: Umm al-Qura users' Dhuhr would move 3 min earlier than the official Umm al-Qura calendar the offset was
  added to match.
- **Reason for rejection**: rejected by the author ([decision record](fx-0-decisions.md), decision 5): kept and
  applied identically in Dart and Kotlin.

### Alt-6: A JVM Adhan library instead of a hand port
- **Pros**: exact results for every method without porting.
- **Cons**: a release (`implementation`) dependency: the APK changes and a licence and supply-chain review is needed;
  FX-0 allows only a test-only dependency.
- **Reason for rejection**: rejected by the author (2026-11-07) in favour of a line-by-line port; it is the fallback to
  revisit if the port exceeds the limit in item 13.

## Risks & Mitigations
| Risk | Mitigation |
| --- | --- |
| Dart calculation bug spreads to 7 cached days | mapping, per-date and fixture tests (§ Changes 7) |
| Kotlin fallback bug or a method change missed in Kotlin | ±1 min parity test on every fixture row; fallback log line |
| A refresh write fails | next app open / resume rewrites everything (accepted) |
| Overlapping refresh runs write old values last | synchronous fingerprint + generation check before each write |
| Stale post-check fires once at the old time | accepted (rule: never cancel without replacement); CUJ 2 exception |
| Second adhan when a prayer moves later after firing | existing 6-hour duplicate guard (relied on, unchanged); S35 |
| Iqama countdown for alarms armed for tomorrow uses today's iqama instant (existing gap, now also reached by next-occurrence scheduling) | out of FX-0; logged as F54a (MEDIUM); CUJ 3 / S31 limited to today |
| DST-eve cache run skips a calendar day | calendar-day arithmetic; DST-eve test (item 9) |
| Kotlin port grows far beyond its estimate | stop and ask (item 13); Alt-6 is the fallback |

## Non-Functional Requirements
- **Performance**: 7 package calculations per load (pure math, no I/O) instead of 3; 42 prefs strings instead of 18.
  Loads happen on app open, resume, input changes, screen opens, and every minute between Isha and midnight (the
  next-prayer tick); each computes 7 days to build the fingerprint; side effects run only when it changes.
- **Rollout**: no migration. Stored prefs values are unchanged; the five new `prayer_calc_method` strings are written
  on the first app open after the update. Kotlin's math changes at install; only its method/madhab inputs stay old
  until that first open.
- **Rollback**: Android blocks installing a lower versionCode, so rollback = ship the previous code with a higher
  versionCode. It reads the same stored values; its Kotlin maps the five new strings to MWL until its first open, when
  its refresh overwrites the cached days.
- **Security and privacy**: no change (coordinates already stored locally for native).

## Additional Resources
- [fx-0-decisions.md](fx-0-decisions.md) · [ADR 0001](../../.project-docs/decisions/0001-fix-track-before-refactor.md)
  · [findings.md](../../.project-docs/reference/findings.md) (F36a, F36c, F52a, F53a, F51p, F54a)
- Package source of truth: `adhan-2.0.0+1/lib/src/` in the pub cache (18 files ported, list in item 13); licence
  `adhan-2.0.0+1/LICENSE` (MIT, "Copyright (c) 2020 Riajul Islam")
- [prayer.md](../../.project-docs/modules/prayer.md) · [notifications-native.md](../../.project-docs/modules/notifications-native.md)
  · [prefs-keys.md](../../.project-docs/contracts/prefs-keys.md) · [method-channels.md](../../.project-docs/contracts/method-channels.md)
  · [device-checklist.md](../../.project-docs/reference/device-checklist.md)
- Review reports: `.project-docs/reference/reviews/fx-0/`

## Future Improvements
- **Jumu'ah reminder on Friday's own Zuhr**: it uses the last stored `dhuhr_time` (F51p, second symptom); with 7
  cached days it could read `cached_{friday}_dhuhr`.
- **One method enum** (F49f): the UI `AdhanCalculationMethod` and the internal `CalculationMethod` duplicate each
  other; FX-0 extends the internal one to keep the change small.
- **Single alarm writer**: Dart publishes data only and native schedules all adhan alarms from the cache (removes the
  two-writer race; needs a channel change).
- **Resolved parameters**: Dart sends the resolved method parameters to Kotlin, so Kotlin needs no method table
  (channel contract change).
- **Iqama per date** (F54a).
- **Dead code, no caller found** (refactor phase P6 cleanup; not deleted in FX-0): `PrayerTimesNotifier.updateNextPrayer`,
  `setCalculationMethod`, `setAsrMadhab`; `PrayerAlarmService.scheduleReminderAlarm`;
  `NotificationService.scheduleDailyPrayers`; `_PrayerScreenState._saveCalculationSettings` (`prayer_screen.dart:372`).
- **Umm al-Qura Ramadan Isha +30 min** (package note), if the author wants it later.

## Detailed Implementation Plan
All work on `fix/fx-0-prayer-settings`. Commits land in the order of § Commit order; items are grouped by step for
reading. Levels: step 1 = B ("approve B"); steps 2–3 = C ("approve phase FX-0"); step 4 = A, except item 15, which
lands in the C contract commit (commit 4).

### Target Scope & File Boundary
The implementation may touch only these files:

| Level | Files |
| --- | --- |
| B | `android/app/build.gradle.kts` (only `testImplementation("junit:junit:4.13.2")`), `tool/generate_prayer_parity_fixture.dart` (new), `test/fixtures/prayer_parity.csv` (new) |
| C, tests | `test/core/services/prayer_calculation_test.dart` (new), `test/core/utils/prayer_refresh_test.dart` (new), `android/app/src/test/kotlin/com/aura/hala/NativePrayerCalculatorParityTest.kt` (new) |
| C, Dart | `lib/core/models/prayer_settings.dart`, `lib/core/services/prayer_times_service.dart`, `lib/core/utils/prayer_refresh.dart` (new), `lib/core/providers/prayer_times_provider.dart`, `lib/features/prayer/prayer_screen.dart` (only `_PrayerSettingsPageState._saveCalculationSettings`), `lib/features/settings/iqama_settings_screen.dart`, `lib/features/settings/adhan_calculation_method.dart` (only the Dubai `nameEn`) |
| C, Kotlin | `android/app/src/main/kotlin/com/aura/hala/NativePrayerCalculator.kt`; new folder `android/app/src/main/kotlin/com/aura/hala/adhan/`: the 18 `.kt` files listed in item 13 and `LICENSE` |
| A | `.project-docs/contracts/prefs-keys.md` (exception: lands in the C contract commit, commit 4; its line-reference refresh lands in commit 13), `.project-docs/modules/prayer.md`, `.project-docs/modules/notifications-native.md`, `.project-docs/reference/device-checklist.md`, `.project-docs/reference/findings.md`, 8 folder READMEs (`lib/core/{models,services,providers,utils}`, `lib/features/{prayer,settings}`, `android/app/src/main/kotlin/com/aura/hala`, `android/app/src/main/kotlin/com/aura/hala/adhan` (new)), `docs/designs/fx-0-prayer-settings.md`, `docs/designs/README.md` |

Out of bounds (no changes): `settings_screen.dart` (already reloads after save, `:295–300`),
`prayer_alarm_service.dart` (already schedules every entry it receives and skips past ones, `:151–170`),
`MainActivity.kt`, `PrayerAlarmReceiver.kt`, `JumuahReminderReceiver.kt`, `DailyRecalcReceiver.kt`,
`PrayerForegroundService.kt`, `main_wrapper_screen.dart`, desktop files, translations, notification IDs and
channels, MethodChannels, and every other file. No existing test references the changed code (search of `test/`
for `CalculationMethod`, `AsrMadhab`, `getPrayerTimes`, `cached_`, `_lastSideEffectsDate`: no match), so no
existing test changes. If a fix needs a file outside this list, implementation stops and asks.

### Commit order
Rule: every commit on the branch builds (`flutter build apk` for commits touching Dart or Kotlin) and passes its
tests (`flutter test`, and `./gradlew :app:testDebugUnitTest` from commit 1 on). The PR is merged only as a whole.
Each test is committed together with the fix that makes it pass (Step 2).

| # | Commit (summary) | Level | Items |
| --- | --- | --- | --- |
| 1 | Add JUnit test dependency for Kotlin unit tests | B | 1 |
| 2 | Add prayer parity fixture generator and fixture | B | 2, 3 |
| 3 | Calculate prayer times for the requested date | C | 8 (per-date part), 4 (per-date and Umm al-Qura tests) |
| 4 | Add five calculation methods and case-insensitive madhab (contract) | C + A | 7, 8 (mapping cases), 10 (delegation), 13 (interim Kotlin names), 15, 4 (mapping tests) |
| 5 | Drop "approximate" from the Dubai method label | C | 14 |
| 6 | Add pure prayer refresh helpers | C | 9, 5 |
| 7 | Replace once-per-day guard with input fingerprint | C | 10 (fingerprint, generation, daily guard) |
| 8 | Cache seven days of prayer times for native | C | 10 (`cacheDays`, `buildNativeCache`) |
| 9 | Schedule adhan alarms at next occurrence | C | 10 (effect order, `nextOccurrences`, `postChecksToSchedule`) |
| 10 | Reload prayer times after prayer settings save | C | 11 |
| 11 | Reload prayer times after iqama save | C | 12 |
| 12 | Port adhan calculation to Kotlin | C | 13 (port, method table, logs; replaces the interim), 6 |
| 13 | Document FX-0 prayer settings changes | A | 16–20, prefs-keys line refs |

Why this order: the mapping tests (commit 4) compare against fixture dates, so they need the per-date calculation
(commit 3). The contract commit holds every side of the five new strings: Dart enum and mapping, the service switch,
the provider delegation, Kotlin's method table and `prefs-keys.md`.

**Interim Kotlin mapping (commits 4–11 only).** Commit 4 changes the strings Dart sends, so Kotlin maps each new
name to exactly what that user's Kotlin calculation does today, each line commented
`// FX-0 interim: replaced by the adhan port (commit 12)`:

| New name | Interim Kotlin behaviour (= today's for that user) |
| --- | --- |
| `qatar` | makkah: `methodAngles` → `Triple(18.5, 90.0, true)` (Isha = Maghrib + 90 min), and the Dhuhr +3 condition (`:152`) becomes `methodName == "makkah" \|\| methodName == "qatar"` |
| `dubai` | kuwait: `Triple(18.0, 17.5, false)` |
| `turkey`, `singapore`, `moonsightingCommittee` | MWL: `Triple(18.0, 17.0, false)`, no Dhuhr adjustment (today's `else` branch) |

Every commit therefore keeps today's native times for every user until commit 12, which deletes `methodAngles` and
the Dhuhr condition with the rest of the old math.

### Step 1 — Test infrastructure (Level B, "approve B")
#### 1. `android/app/build.gradle.kts` (Modify)
- **Proposed Changes**: add exactly one test-only line, `testImplementation("junit:junit:4.13.2")`. No `testOptions`
  change: the tested Kotlin code makes no Android calls (item 13). No `implementation` change; release APK
  unchanged. Why: `android/app/src/` has only `main`, `debug`, `profile`.
#### 2. `tool/generate_prayer_parity_fixture.dart` (Create)
- **Type / Scope**: pure Dart script, run by hand: `dart run tool/generate_prayer_parity_fixture.dart`. Writes
  `test/fixtures/prayer_parity.csv` (overwrites).
- **Proposed Changes**: imports only `package:adhan/adhan.dart` as `adhan`. Holds its own copy of the internal-name →
  package-method map (14 names; `fixedAngle` → `egyptian`, `proportional` → `muslim_world_league`) and the Umm
  al-Qura Dhuhr +3, because it cannot import `prayer_times_service.dart` (that file imports
  `package:flutter/foundation.dart`, which `dart run` cannot load). For each city × date × method × madhab in
  § Changes 7, it calls
  `adhan.PrayerTimes(adhan.Coordinates(lat, lng), adhan.DateComponents(y, m, d), params)` and writes one CSV row:

  ```text
  city,lat,lng,tz,date,method,madhab,fajr,sunrise,dhuhr,asr,maghrib,isha
  ```
  `lat` / `lng` exactly as in the city table, ASCII `-`; `tz` the IANA id; `date` `yyyy-MM-dd`; `method` / `madhab`
  the contract strings (internal enum names; `shafi` / `hanafi`); the six times as epoch ms. Run on a host with UTC
  offset ≥ 0 (the author's machine, Africa/Cairo): the package's `dayOfYear` depends on the host offset, and the
  difference elsewhere is under 0.25 min but can flip a rounded minute.
#### 3. `test/fixtures/prayer_parity.csv` (Create)
- **Proposed Changes**: output of item 2 (13 cities × 10 dates × 14 methods × 2 madhabs = 3,640 rows + header),
  checked in. The Kotlin test reads it at `../../test/fixtures/prayer_parity.csv` from the Gradle module directory
  `android/app`.

### Step 2 — Tests (Level C; written first, committed with their fix)
Each test is written before its fix and run once against the pre-fix code to see it fail. The PR description
includes the pre-fix failing output of **every** new test (items 4, 5, 6; one block per test, `flutter test` /
Gradle output trimmed to the failing assertion). A test that passes before its fix is reported in the PR as such,
with the reason. The test is then committed together with the fix that makes it pass (§ Commit order), so every
commit stays green. Any test that runs `PrayerTimesNotifier` resets the static generation counter in `setUp` via
`PrayerTimesNotifier.resetGenerationForTest()` (item 10). For that local red run only, these compiling stubs are used and never committed:
- `prayer_settings.dart`: the five enum values with their `displayName` / `displayNameAr` cases (item 7) and the two
  mapping functions returning **today's** mapping;
- `prayer_times_service.dart`: the five cases in the adhan-method switch (item 8), still mapped as today (Qatar →
  `umm_al_qura`, Dubai → `kuwait`, Turkey, Singapore and Moonsighting Committee → `muslim_world_league`);
- `prayer_refresh.dart`: the helper signatures (item 9) returning today's behaviour;
- `NativePrayerCalculator.kt`: `internal data class PrayerResult` and `internal fun calculate(...)` with the item-13
  signature wrapping today's math.

#### 4. `test/core/services/prayer_calculation_test.dart` (Create)
- **Proposed Changes**:
  - mapping (commit 4): for every UI method string (12 picker values) × `'Shafi'` / `'Hanafi'`:
    `calculationMethodFromPref` + `asrMadhabFromPref`, then `PrayerTimesService.getPrayerTimes` for every fixture
    city and date → each time's epoch ms equals the fixture row exactly (fails before the fix for Hanafi and for
    Qatar, Dubai, Turkey, Singapore and Moonsighting Committee);
  - per-date (commit 3): for a base date D and i = 0 … 6, `getPrayerTimes(date: D + i calendar days)` equals
    `adhan.PrayerTimes(…, adhan.DateComponents(that date), …)` exactly, as epoch ms (fails before the fix on
    days ≥ 1). Base dates: Cairo 2026-04-21 and 2026-10-26 (windows contain 2026-04-24 and 2026-10-29), MWL, Shafi.
    What it proves: each day is calculated for its own date. It does not prove the Cairo wall-clock conversion
    across DST, because Dart converts with the test host's zone; that is covered by the Kotlin test (item 6), which
    passes the zone explicitly;
  - Umm al-Qura (commit 3): Dhuhr = package + 3 min; for every other `CalculationMethod` value present at that
    commit, the times equal the package exactly (commit 4 extends the loop to the five new values).
#### 5. `test/core/utils/prayer_refresh_test.dart` (Create)
- **Proposed Changes**: the tests listed in item 9, against the pure helpers of item 9 (commit 6).
#### 6. `android/app/src/test/kotlin/com/aura/hala/NativePrayerCalculatorParityTest.kt` (Create)
- **Proposed Changes** (commit 12):
  - reads the fixture; for each row calls `NativePrayerCalculator.calculate(lat, lng, y, m, d,
    TimeZone.getTimeZone(tz), method, madhab)` and asserts all six times within ±1 min (60,000 ms) of the row
    (every method, Moonsighting Committee and Oslo included). Fails before the port for every method that has
    adjustments, and wherever rounding or solar-position differences exceed 1 min;
  - DST check, with `java.time`: for each (zone, date D) below, `start = D.atStartOfDay(zone).toInstant()`,
    `end = D.plusDays(1).atStartOfDay(zone).toInstant()`,
    `t = zone.rules.nextTransition(start.minusSeconds(1)).instant`; assert `t` equals the expected instant and
    `start ≤ t < end`. The zone → dates map is hard-coded in the test (Birmingham uses Europe/London, so it is
    covered by the London rows):

    | Zone | Date D | Local change | Expected transition (UTC) |
    | --- | --- | --- | --- |
    | Africa/Cairo | 2026-04-24 | 00:00 → 01:00 (start of D does not exist; `start` = 2026-04-23T22:00Z) | 2026-04-23T22:00:00Z |
    | Africa/Cairo | 2026-10-29 | 24:00 → 23:00 (end of D) | 2026-10-29T21:00:00Z |
    | Europe/London | 2026-03-29 | 01:00 → 02:00 | 2026-03-29T01:00:00Z |
    | Europe/London | 2026-10-25 | 02:00 → 01:00 | 2026-10-25T01:00:00Z |
    | America/Toronto, America/New_York | 2026-03-08 | 02:00 → 03:00 | 2026-03-08T07:00:00Z |
    | America/Toronto, America/New_York | 2026-11-01 | 02:00 → 01:00 | 2026-11-01T06:00:00Z |

    `VERIFIED-run` 2026-11-07 with this exact check in `jshell` (JDK 17.0.10): all eight (zone, date) pairs return
    the expected instant inside [`start`, `end`). A naive check fails for Cairo: D = 2026-04-24 has no local 00:00,
    and the 2026-10-29 change happens at local 24:00, which a check on the next day's date would misplace.

### Step 3 — Fixes (Level C; one commit per logical change)
#### 7. `lib/core/models/prayer_settings.dart` (Modify)
- **Proposed Changes**:
  - five enum values `qatar`, `dubai`, `turkey`, `singapore`, `moonsightingCommittee`;
  - `displayName` (`:42–63`) / `displayNameAr` (`:65–86`) cases reuse the picker strings: Qatar / `'قطر'`, Dubai /
    `'دبي'`, Turkey / `'تركيا'`, Singapore / `'سنغافورة'`, Moonsighting Committee / `'لجنة الرؤية'`;
  - `CalculationMethod calculationMethodFromPref(String? value)`: UI values `'MuslimWorldLeague'` →
    `muslimWorldLeague`, `'Egyptian'` → `egyptian`, `'Karachi'` → `karachi`, `'UmmAlQura'` → `makkah`,
    `'NorthAmerica'` → `isna`, `'Kuwait'` → `kuwait`, `'Tehran'` → `tehran`, `'Qatar'` → `qatar`, `'Dubai'` →
    `dubai`, `'Turkey'` → `turkey`, `'Singapore'` → `singapore`, `'MoonsightingCommittee'` →
    `moonsightingCommittee`; an exact enum name is accepted as today; null / unknown → `muslimWorldLeague`;
  - `AsrMadhab asrMadhabFromPref(String? value)`: case-insensitive `shafi` / `hanafi`; null / unknown → `shafi`.
  The file has no imports today and stays pure Dart. Commit 4.
#### 8. `lib/core/services/prayer_times_service.dart` (Modify)
- **Proposed Changes**:
  - commit 3: replace `adhan.PrayerTimes.today` + day shift (`:79–112`) with
    `adhan.PrayerTimes(coordinates, adhan.DateComponents.from(date), params)`; keep the makkah Dhuhr +3 (`:72–74`);
  - commit 4: `_mapToAdhanCalculationMethod` (declared `:253`) maps the five new values to `qatar`, `dubai`,
    `turkey`, `singapore`, `moon_sighting_committee`. Hazard: the method is an exhaustive switch — adding enum values
    without these cases does not compile, so both land in commit 4.
#### 9. `lib/core/utils/prayer_refresh.dart` (Create) and its tests (item 5)
- **Type / Scope**: pure helpers (imports only `../models/prayer_time.dart` and `../models/prayer_settings.dart`; no
  Flutter, no platform calls). A separate file, not `prayer_time_rules.dart`, because that file imports
  `flutter/material.dart`. Commit 6.
- **Proposed Changes**:
  - `String sideEffectsFingerprint({required DateTime today, required CalculationMethod method, required AsrMadhab madhab, required Map<String, int> iqama, required List<List<PrayerTime>> days})`
    — joins the inputs and every prayer's epoch ms into one string;
  - `List<DateTime> cacheDays(DateTime now, {int count = 7})` — `DateTime(now.year, now.month, now.day + i)` for
    i = 0 … count − 1 (calendar days, not `add(Duration(days: i))`);
  - `Map<String, String> buildNativeCache(List<(DateTime, List<PrayerTime>)> days)` — keys
    `cached_{yyyy-MM-dd}_{name}`, `Zuhr` → `dhuhr`, value epoch ms as string (moved from
    `prayer_times_provider.dart:403–426`, same key format);
  - `List<PrayerTime> nextOccurrences(List<PrayerTime> today, List<PrayerTime> tomorrow, DateTime now)` — the five
    prayers (no Sunrise), each today's if after `now`, else tomorrow's;
  - `List<PrayerTime> postChecksToSchedule(List<PrayerTime> today, DateTime now)` — prayers (no Sunrise) whose time
    + 30 min is after `now`;
  - `bool isLatest(int run, int latest)` — the write gate for the generation check (`run == latest`).
- **Tests (item 5)**, each input → expected result:
  - method change: `days` computed for MWL vs Egyptian → fingerprints differ;
  - madhab: Shafi vs Hanafi days → differ;
  - iqama: `{'Maghrib': 5}` vs `{'Maghrib': 10}` → differ;
  - location: days for Cairo vs Alexandria coordinates → differ;
  - adjustment: days computed with Dhuhr +0 vs +3 → differ;
  - app open: an empty previous fingerprint never equals a computed one → run;
  - same inputs twice → equal → no run;
  - overlap: two runs with generations 1 and 2 where run 1 finishes last → the write gate admits only run 2
    (`isLatest`);
  - `cacheDays` with `now` = 2026-03-28 23:30 (London DST eve) and 2026-04-23 23:30 (Cairo DST eve) → 7 distinct
    consecutive dates. This checks the calendar arithmetic only: it exercises a real DST shift only when the test
    process runs in that zone, and the result must hold in any zone;
  - `buildNativeCache` over 7 days → exactly 42 keys, values equal the inputs;
  - `nextOccurrences` before Fajr, between Dhuhr and Asr, after Isha → all five from the right day;
  - `postChecksToSchedule` at times where Asr + 30 min is ahead / past.
  "No old `cached_*` key survives" relies on the native write removing all `cached_*` keys first
  (`MainActivity.kt:698–704`, `VERIFIED-static`) and is checked on device in S32, not in a Dart test.
#### 10. `lib/core/providers/prayer_times_provider.dart` (Modify)
- **Proposed Changes**:
  - commit 4: `_getCalculationMethod` (`:516–549`) and `_getAsrMadhab` (`:552–559`) delegate to the item-7
    functions;
  - commit 7 (fingerprint): remove the field `_lastSideEffectsDate` (`:80`) and its guard (`:255–257`). Add
    `static int _generation = 0` (static, so a run of a disposed notifier also loses to a newer notifier's run after
    resume) with `@visibleForTesting static void resetGenerationForTest() => _generation = 0;` (called in `setUp` of
    every test that runs the notifier), `String? _lastFingerprint` and `String? _lastDailyEffectsDate`. In `loadPrayerTimes`, before the async
    block: compute the fingerprint; if it equals `_lastFingerprint`, return; else store it and take
    `final run = ++_generation`, all synchronously. Inside the block, before each platform write:
    `if (!isLatest(run, _generation)) return;`. The daily task digest (`:281–316`) and `cleanupFuturePrayerRecords`
    (`:351–363`) stay in the same async block, after the prayer-derived effects, in that order; they are gated by
    `_lastDailyEffectsDate` (key `yyyy-M-d` of the wall-clock date, checked and set synchronously next to the
    fingerprint, same logic as today's guard) and not by the generation;
  - commit 8 (cache): `final days = cacheDays(DateTime.now())`; each day is calculated once with the same location,
    method, madhab and iqama minutes; `days[0]` reuses `prayerTimes` when the `date` argument is the wall-clock date
    (all live callers), else it is calculated. `cacheAccuratePrayerTimes` receives `buildNativeCache(days)` (replaces
    the loop `:403–426`, no second calculation);
  - commit 9 (order and alarms): prayer-derived effects run in this order, each in its own try/catch with its
    debugPrint: widgets (`:336–349`) and desktop timers (`:326–334`) with `updatedPrayerTimes`;
    `updatePrayerTimes` (`:365–394`) with `updatedPrayerTimes`; the cache write; adhan alarms with
    `nextOccurrences(days[0], days[1], now)` (`:318–323` moves here); post-checks with
    `postChecksToSchedule(days[0], now)` (`:259–280` moves here). `updatedPrayerTimes` is the state list (built
    from the `date` argument, with `isNext` / `isCurrent`); `days[0]` holds the same times for every live caller;
  - `updatePrayerTimes` keeps sending `method.name` / `madhab.name` (from commit 4: the new names and `'hanafi'`).
#### 11. `lib/features/prayer/prayer_screen.dart` (Modify)
- **Proposed Changes** (commit 10): `_PrayerSettingsPageState._saveCalculationSettings` (`:1544–1557`) becomes:

  ```dart
  Future<void> _saveCalculationSettings() async {
    // Read before the first await: no BuildContext use across an async gap.
    final notifier = ProviderScope.containerOf(context, listen: false)
        .read(prayerTimesProvider.notifier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.keyCalculationMethod, _calculationMethod);
    await prefs.setString(AppConstants.keyAsrMadhab, _asrMadhab);
    debugPrint('Saved calculation settings: $_calculationMethod, $_asrMadhab');

    // Close the method dialog right after saving, then reload.
    if (context.mounted) Navigator.pop(context);
    try {
      await notifier.loadPrayerTimes(DateTime.now());
    } catch (e) {
      debugPrint('PrayerSettings: reload failed — $e');
    }
  }
  ```
  The only `context` use after an `await` is guarded by `context.mounted`, so `use_build_context_synchronously`
  stays clean (no new analyzer issues). The dialog closes within the two prefs writes, not after the reload (which
  can fetch GPS), so a manual close or a second pick during the reload cannot make a delayed `pop` close the page.
  `prayerTimesProvider` is a plain `StateNotifierProvider` (not autoDispose, `prayer_times_provider.dart:589`), so the
  notifier read before the pop stays valid. If the reload fails, the prefs stay saved and the new method applies on
  the next load (resume or screen open). No widget-type change (`ProviderScope.containerOf` needs no `ref`);
  `_showPrayerSettings` unchanged.
#### 12. `lib/features/settings/iqama_settings_screen.dart` (Modify)
- **Proposed Changes** (commit 11): add `import '../../core/providers/prayer_times_provider.dart';`. In
  `_saveIqamaSettings` (`:275–292`): first line `final notifier = ref.read(prayerTimesProvider.notifier);` (before
  the first `await`); after `prefs.setString`: `await notifier.loadPrayerTimes(DateTime.now());` in its own
  try/catch (`debugPrint('IqamaSettings: reload failed — $e')`; if it fails, the minutes stay saved and apply on the
  next load). Already a `ConsumerStatefulWidget`; no `context` use is added.
#### 13. `android/app/src/main/kotlin/com/aura/hala/NativePrayerCalculator.kt` (Modify) and `adhan/` (Create)
- **Proposed Changes** (commit 4: interim names, see § Commit order; commit 12: everything below):
  - `NativePrayerCalculator.kt`: `internal data class PrayerResult` (today `private`, `:87`; fields are epoch ms) and
    `internal fun calculate(lat: Double, lng: Double, year: Int, month: Int, day: Int, zone: java.util.TimeZone, method: String, madhab: String): PrayerResult`.
    The old `private fun calculate(lat, lng, cal, methodName, madhabName)` (`:93–162`), the astronomical helpers
    and utilities (`:189–258`: `julianDay` … `methodAngles`, `rad`, `deg`, `normalizeHours`, `toEpoch`) are removed, including the 1/7-night fallback and hard clamp
    (`NativePrayerCalculator.kt:118–145`). `cachedOrComputed` (`:165–171`) calls the new `calculate` with y-m-d and
    `cal.timeZone` from its `Calendar`. `calculateAndSave` keeps its signature and its cache-first order. `calculate`
    and everything it calls make no `android.*` calls (no `Log`);
  - app mapping in `NativePrayerCalculator.kt`: `private fun methodParams(name: String): CalculationParameters?`
    returns the package parameters for the 12 package-backed names, Egyptian parameters for `fixedAngle`, MWL
    parameters for `proportional`, and `null` for an unknown name; `makkah` adds Dhuhr +3 min; madhab `hanafi` →
    the ported `Madhab` hanafi value (shadow length 2), anything else → shafi. `calculateAndSave` resolves `methodParams(methodName)`
    once; `null` → MWL parameters and a new `Log.w(TAG, "⚠️ Unknown method '$methodName' — using MWL")`; `calculate`
    receives only resolved names;
  - when the cached day is missing and the calculation runs, `calculateAndSave` logs
    `⚠️ No cached times for {date} — using native fallback` under the existing `NativePrayerCalc` tag (new);
  - **port, mirror structure**: one Kotlin file per ported Dart file, same name in PascalCase, same subfolder, in
    `android/app/src/main/kotlin/com/aura/hala/adhan/` (packages `com.aura.hala.adhan`, `.data`, `.extensions`,
    `.internal`; every declaration `internal`). Ported line by line; only unused members are left out:

    | Dart file (`adhan-2.0.0+1/lib/src/`) | Kotlin file (`adhan/`) | Code lines |
    | --- | --- | --- |
    | `prayer_times.dart` (without `today` / `utc` / `utcOffset` `:65–108` and `currentPrayer` … `timeForPrayer` `:269–333`) | `PrayerTimes.kt` | 223 |
    | `calculation_method.dart` | `CalculationMethod.kt` | 110 |
    | `calculation_parameters.dart` | `CalculationParameters.kt` | 55 |
    | `prayer_adjustments.dart` | `PrayerAdjustments.kt` | 15 |
    | `madhab.dart` | `Madhab.kt` | 18 |
    | `high_latitude_rule.dart` | `HighLatitudeRule.kt` | 5 |
    | `coordinates.dart` | `Coordinates.kt` | 16 |
    | `data/date_components.dart` | `data/DateComponents.kt` | 16 |
    | `data/time_components.dart` | `data/TimeComponents.kt` | 19 |
    | `data/calendar_util.dart` | `data/CalendarUtil.kt` | 16 |
    | `extensions/datetime.dart` | `extensions/DateTime.kt` | 37 |
    | `internal/astronomical.dart` | `internal/Astronomical.kt` | 144 |
    | `internal/calendrical_helper.dart` | `internal/CalendricalHelper.kt` | 20 |
    | `internal/double_util.dart` | `internal/DoubleUtil.kt` | 14 |
    | `internal/math.dart` | `internal/Math.kt` | 4 |
    | `internal/shadow_length.dart` | `internal/ShadowLength.kt` | 9 |
    | `internal/solar_coordinates.dart` | `internal/SolarCoordinates.kt` | 27 |
    | `internal/solar_time.dart` | `internal/SolarTime.kt` | 76 |
    | **Total** (raw lines 1,306) | 18 files | **824** |

    Not ported: `adhan.dart`, `adhan_base.dart`, `prayer.dart`, `qibla.dart`, `sunnah_times.dart`,
    `internal/qibla_util.dart`;
  - **header** in each of the 18 files:
    `// Ported from adhan 2.0.0+1 (pub.dev), lib/src/<path>.dart — line-by-line port.` and
    `// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.`;
  - **licence**: adhan 2.0.0+1 is MIT licensed (`adhan-2.0.0+1/LICENSE`: "MIT License / Copyright (c) 2020 Riajul
    Islam", `VERIFIED-static`). `adhan/LICENSE` is a verbatim copy of that file. The Dart package stays a dependency,
    so its notice is already in the app's Flutter licence registry; no UI change;
  - **semantics to keep exact**: `TimeComponents.fromDouble` truncates (`floor`) hours, minutes and seconds;
    `dayOfYear` and `copyWith` from `extensions/datetime.dart` (a minute of 60 rolls into the next hour, as Dart's
    `DateTime` constructor does; use `java.time` `plusMinutes`, not field setters); Dart `round()` is half away from
    zero, so `DoubleUtil.kt` adds `dartRound(x) = if (x >= 0) floor(x + 0.5) else -floor(-x + 0.5)` and every Dart
    `.round()` uses it (not `Math.round`, which rounds −2.5 to −2, nor `kotlin.math.round`, which rounds half to
    even). Times are computed in UTC and converted with `zone` per instant;
  - **size limit**: estimate 824 code lines (1,306 raw), measured from the package files above. Stop rule: if the
    Kotlin code lines in `adhan/` exceed about 1,650 (measured the same way, § Terms), implementation stops and asks
    the author; Alt-6 (a JVM library) is the fallback to revisit. Measured once after the port and reported in the PR.
#### 14. `lib/features/settings/adhan_calculation_method.dart` (Modify)
- **Proposed Changes** (commit 5): `nameEn: 'Dubai (approximate)'` (`:35`) → `'Dubai'`; `value` unchanged.

### Step 4 — Contracts and docs (Level A; item 15 in commit 4, the rest in commit 13)
#### 15. `.project-docs/contracts/prefs-keys.md` (Modify)
- Commit 4: `prayer_calc_method`: list the accepted strings — the 9 current `CalculationMethod` names plus the 5 new
  ones; `prayer_asr_madhab`: `'shafi'` / `'hanafi'`; `cached_{yyyy-MM-dd}_{name}`: today … +6, Dart writer column →
  `prayer_times_provider.dart` → `buildNativeCache` (`prayer_refresh.dart`) →
  `BackgroundServiceManager.cacheAccuratePrayerTimes` (`background_service_manager.dart:121–127`) →
  `MainActivity.kt:698–704`.
- Commit 13: refresh the `NativePrayerCalculator.kt` line references after the port: the reader of `cached_*`
  (today `:173–178`) and the writer of `*_time` (today `:61–66`).
#### 16. `.project-docs/modules/prayer.md`, `.project-docs/modules/notifications-native.md` (Modify)
- `prayer.md`: method and madhab mapping (both functions, the 14 internal names), per-date calculation, fingerprint
  and gated effects, the 7-day cache.
- `notifications-native.md`: next-occurrence adhan alarms, the post-check rule (never cancelled), the Kotlin port in
  `adhan/` (mirror structure, licence), the fallback and unknown-method log lines.
#### 17. Folder READMEs (Modify / Create)
- Modify: `lib/core/models/README.md`, `lib/core/services/README.md`, `lib/core/providers/README.md`,
  `lib/core/utils/README.md` (new `prayer_refresh.dart`), `lib/features/prayer/README.md`,
  `lib/features/settings/README.md`, `android/app/src/main/kotlin/com/aura/hala/README.md`.
- Create: `android/app/src/main/kotlin/com/aura/hala/adhan/README.md` (source package and version, file mirror
  table, licence, "do not edit except to re-port").
- Each folder README documents its files (project rule: folder READMEs stay current with the code).
#### 18. `.project-docs/reference/device-checklist.md` (Modify)
- S29–S35 (Delivery section) were added early, 2026-11-07, for the baseline run; commit 13 records the FX-0 results.
#### 19. `.project-docs/reference/findings.md` (Modify)
- Already recorded with the spec approval (2026-11-07): the F53a DST correction and F54a (MEDIUM; an alarm armed for
  tomorrow reads today's `*_iqama_time`). Commit 13: mark F36a, F36c, F52a, F53a fixed with the PR.
#### 20. `docs/designs/fx-0-prayer-settings.md` (Modify) and `docs/designs/README.md` (Modify)
- Status is Approved (2026-11-07, set with the spec commit); commit 13 adds the spec to the README list and
  updates anything the implementation changed.

Release notes (Goal 7) are not a repo file; the author pastes the text into the Play Console.

### Verification Plan
- **Per commit**: build and tests as in § Commit order; a commit that fails either is fixed before the next commit.
- **Build**: `flutter build apk --release --obfuscate --split-debug-info=build/debug-info`; Windows build per
  `.project-docs/modules/desktop.md` (desktop shares the Dart changes).
- **Unit tests**: `flutter test` (items 4, 5 + the existing 64 tests: count from `.project-docs/STATE.md`,
  2026-11-07); `./gradlew :app:testDebugUnitTest` in `android/` (item 6).
- **Static analysis**: `flutter analyze` — no new issues over the baseline of 425 (`.project-docs/STATE.md`,
  2026-11-07); `dart format --output=none --set-exit-if-changed` on touched files.
- **Port size**: code lines of `adhan/*.kt` (§ Terms) against the 1,650 stop rule (item 13); reported in the PR.
- **Device**: before/after runs of S01, S06, S11, S13, S17, S18, S29–S35 on the nova 5T (API 29); results recorded
  in the checklist. Nothing is reported as passed unless it ran.

---

*Drafted with EGM*

# Stage 6 — Comprehension Test Report

**Target:** `docs/designs/fix-settings-bridge.md` (FeatureRange 1–429, DetailedRange 430–605)
**Reviewer:** `egm-comprehension` — completed · read the target only, no other files · **Date:** 2026-11-09

### What this proposes

The Flutter side of the app stores user settings in one file, `FlutterSharedPreferences`, under keys that start
with `flutter.`. The Android side reads some of those settings, but for several of them it looks in a different
file, uses a different key, keeps its own copy, or ignores the setting. The fix makes Android read four settings
(`silent_mode_enabled`, `adhan_enabled`, `selected_adhan_id`, `background_notification_enabled`) directly from
`FlutterSharedPreferences` through the existing `FlutterPrefs` helper, every time it needs them, with no native copy.

The reciter file is found from the selected id plus the download folder by a new pure `AdhanFiles.resolve`.
Previewing a reciter becomes a separate `previewAdhan {id}` channel method that changes nothing stored, guarded by
a playback-kind flag (`AdhanPlaybackState`). The fix also:
- removes four old adhan channel methods,
- gates the boot, app-update and nightly restarts of the foreground service on the Dart setting,
- makes all three Dart senders use one Zuhr key rule (`dhuhr_time`),
- points the silent-mode receiver's language at the same pushed copy the other native readers use,
- deletes a dead boot check.

The work ships as one PR with five commits split by repair type, tests written first, plus named device checks
S25, S26, S42 and S43.

### How the existing system works, per this document

Dart writes all settings to `FlutterSharedPreferences`. Android partly reads them through `FlutterPrefs` and partly
through private files (`aura_prefs`, `aura_silent_mode`, `aura_prayer_times`) that only some code paths fill or
that nothing writes at all.

As a result:
- Silent mode is read from a file nothing writes, so it is always on.
- The reciter path lives only in memory, and preview overwrites it.
- `adhan_enabled` is stored twice, and Android reads the `aura_prefs` copy.
- Boot, app update and the nightly recalculation restart the foreground service regardless of the user's choice,
  and clear the `fg_user_stopped` flag.
- Two of three Dart senders push `zuhr_time` while every Android reader expects `dhuhr_time`.
- The silent-mode receiver reads `language` from a file nothing writes.
- The boot receiver checks a `notifications_enabled` key nothing writes.

Native language reads use a copy that Dart pushes as part of `updatePrayerTimes`. Kotlin unit tests are plain
JUnit, so they cannot exercise `SharedPreferences`.

The reviewer could paraphrase every section, so there are no Blockers.

## Findings

### CO-1 — When the language copy is refreshed is not stated; Goal 6 cannot be checked — Major
* **Scope:** Goal 6 (98–102); §7 (298–301); data flow (191); Alternatives D/E (359, 369, "push gap"); Non-Goal F67
  (149–150).
* **Gap:** Goal 6 promises the receiver's messages "follow the app language", using the channel-pushed
  `aura_prayer_times.language`. The only push shown is inside `updatePrayerTimes` on a prayer refresh (191). The doc
  never says whether a language change pushes the copy at once or only at the next refresh, and "push gap" is
  undefined. The single Arabic S25 run could pass or fail depending on timing.
* **Recommendation:** State when Dart pushes `language` to `aura_prayer_times`; define "push gap"; either narrow Goal 6
  to "after the push" or make S25 change the language right before the adhan.

### CO-2 — Nothing states that current reciter ids and file names follow the resolver's rules — Major
* **Scope:** Goal 2 (59–70); Goal 8 (113–114); §3 (212–216); data flow (188); test 24 (527–529).
* **Gap:** F49b depends on downloads being written as exactly `adhans/adhan_<id>.mp3` and every id matching
  `^[a-z0-9_]+$`. Line 67 says `adhans/<fileName>` without tying `fileName` to the id; the doc never says where ids
  come from or that all current ids pass. A mismatch silently plays built-in — the bug being fixed.
* **Recommendation:** Name where reciter ids are defined and the Dart line that builds the file name; state that every
  current id matches, or that a Dart test asserts it.

### CO-3 — Goal 3's fallback proof points to a device step that does not test Goal 3 — Major
* **Scope:** Goal 3 proof (76–78); playback-flag steps (a)–(d) (283–286); test 27 fallback (535–538); test 26 (532–534).
* **Gap:** If the screen cannot be pumped, line 538 falls back to test 26 and S26 step (d). Step (d) checks that a
  prayer adhan interrupts a preview, not that the selected (not the previewed) reciter plays. Test 26 tests the
  service, not the screen. The Goal 3 device check (line 78) is not one of steps (a)–(d).
* **Recommendation:** Add a named S26 step, e.g. "(e) select A, preview B, let the adhan fire → A plays", and point
  line 538 at it.

### CO-4 — Folder-name confirmation contradicts itself; `PathUtils` not fully qualified — Nit
* **Scope:** 69–70 vs 113, 216, 542.
* **Recommendation:** One wording ("derived from engine `PathUtils.java`, confirmed on device by S26/S43") and the
  class name `io.flutter.util.PathUtils`.

### CO-5 — Project process terms used without definition — Nit
* **Scope:** 4 (`/egm:egm-review`, "approve phase"), 6 ("Level C"), 401 ("Level B"), 315/468/491 ("edit carefully"),
  414/435 ("CLAUDE.md native-key rule").
* **Recommendation:** One-line gloss each, or link the defining file.

### CO-6 — Finding id F10 not described — Nit
* **Scope:** 273. **Recommendation:** "F10: unused handler class".

### CO-7 — S25 and S26 used before they are described — Nit
* **Scope:** 25 and Goals 1–3, 6. **Recommendation:** At first use, give the checklist path and a one-line purpose.

### CO-8 — Line references disagree between sections — Nit
* **Scope:** `getLanguage` `:253–255` (98) vs `:253–256` (496); boot check `:59–65` (104) vs `:58–65` (305, 555).
* **Recommendation:** Make the ranges agree.

### CO-9 — Problem table does not say which Zuhr sender is already correct — Nit
* **Scope:** row 5 (34) vs Goal 5 (88–93). **Recommendation:** Name the two wrong sites and the correct one in row 5.

### CO-10 — Android background facts assumed — Nit
* **Scope:** 33 ("user stopped" flag), 174 ("legacy plugin"), Goal 4 (79–82).
* **Gap:** `fg_user_stopped` named only at 274 and who sets it is unstated; "legacy plugin" not tied to
  `SharedPreferences` vs `SharedPreferencesAsync`; Goal 4 does not say how a running service stops when the user turns
  the setting off (Dart channel call).
* **Recommendation:** One clause for each.

**Verdict:** Paraphrasable and connected. Fix the three Majors (language refresh timing, reciter id/file-name
conformance, Goal 3 proof step) before approval; Nits are clarity polish.

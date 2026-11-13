# Wird Marker: Single Marker, Versioned Sync Guard, Undo, Khatma and Restart

*   **Author:** Alaa Eldin Tarek
*   **Status:** Proposed
*   **Date:** 2026-11-13

--------------------------------------------------------------------------------

## Overview

A Wird is the user's daily Quran reading plan. In page mode, the app today tracks progress by linking the Wird to one of three bookmark colors (red, orange, green). Bookmarks of that color advance the plan. This release replaces that link with one Wird marker per user. The marker has its own shape, is drawn in a color the user picks from a preset grid, and is separate from ordinary bookmarks. Red, orange and green stay as ordinary reference bookmarks and never count toward the Wird.

The release also adds one-step undo, a "Complete khatma?" prompt when the reader closes on page 604, a Restart action, and a small sync guard so a stale device cannot overwrite a newer Restart or khatma. Full multi-device sync is a separate later item.

This document is self-contained: it cites only files tracked in the repository.

Decisions already made by the product owner (2026-11-13):

*   **One marker, page mode only.** Juz toggles are unchanged. The old color link is removed. There is no migration and no notice, because there are no real users yet.
*   **Modes (decided 2026-11-13).** The mode is the existing Wird setting `WirdSettings.wirdUnit` (`WirdUnit.page` or `WirdUnit.juz`, `lib/core/models/wird.dart:1`). The user changes it with the Page/Juz segmented button in the Wird settings section (`wird_tab.dart:1220`, saved by the provider at `wird_provider.dart:128`). This release adds no new toggle. Switching to juz mode hides every marker control (ribbon, "Move Wird marker here", undo snackbar and button, "Restart Wird", the close-on-604 prompt) but keeps the marker record and the undo record, locally and in the cloud, and marker sync continues. Switching back to page mode shows the marker again exactly as it was. Streak, history, `totalDaysCompleted` and the khatma totals do not depend on the mode. "Reset All Progress" works in both modes and clears a hidden marker too.
*   **Marker display (decided 2026-11-13).** A fixed ribbon drawn in the reader's top-level `Stack` (`quran_reader_screen.dart:421`) after the `PageView`, shown only when `_currentPage == markerPage` (page mode). Its `top` is the measured top bar height (from `_topBarKey`) while `_showUI` is true, else 0. It sits at `right: 8`, about 14 dp wide and at most 30 dp tall, in the outer margin of the RTL mushaf, so it is intended not to cover the first text line or the top bar controls (confirmed only by the acceptance check below). It does not zoom, pan or swipe with the page (accepted limit). Acceptance: on pages 2, 3 and 604 at 320 dp and 360 dp widths and in a narrow Windows window, in light and dark mode, it overlaps no glyph of line 1 and no top bar control. If it fails, the owner decides the fallback (not the top bar icon without approval).
*   **Setup (decided 2026-11-13).** The "Add from Bookmarks" button on the Wird page stays. It lists the user's ordinary bookmarks (all colors). The chosen bookmark's page becomes the start page and the marker page once the user has also picked a color; nothing is saved until then, and cancelling either sheet changes nothing. No pages are counted at setup. **Setup is blocked while a marker exists (decided 2026-11-13):** the page-mode "Add from Bookmarks" button is replaced by the hint "To choose a new starting page, restart your Wird first", and the user must use Restart Wird, which deletes the marker, before a new setup. If the user has no bookmarks, the sheet shows "Add a bookmark in the reader first" with an "Open reader" button. These strings exist in English and Arabic.
*   **Color (decided 2026-11-13).** A preset grid of about 12 colors, no hex field and no free picker. The colors are chosen to contrast with the page in light and dark mode, and they exclude shades close to the reference red, green and orange. No new dependency and no `pubspec.*` change. Restart deletes the color, and the user picks a new one.
*   **Moving the marker.** The reader has no long-press today. Tapping a verse calls `onAyahTap` (`quran_reader_screen.dart:819-835, 468`), which opens the verse sheet. "Move Wird marker here" is added to that sheet. If a forward move adds more pages than the daily goal, the app first asks "Count N pages as read?".
*   **Counting.** Moving the marker forward counts the pages passed. Moving from page 31 to page 36 adds pages 31 to 35. Progress = stored running page total + (marker page - start page). The marker never moves backward, except through undo, a finished khatma, and Restart.
*   **Streak and daily progress.** Today's count is the pages added today minus any undone. A day counts toward the streak when today's pages reach the daily goal. Restart leaves streak, history and juz untouched.
*   **Manual recording.** "Mark day complete" stays as a streak-only action with no page credit, and "undo complete" reverses it. Manual page entry is removed in page mode.
*   **Undo.** "Undo last move" restores the previous marker position and removes the pages that move added. It covers one step, today's last move only, and is not available after midnight. A signed-in user pushes the undo immediately (read, compare, plain write) and needs a connection ("Connect to undo" when offline). Guests have no sync, so undo always works for them. A khatma move cannot be undone.
*   **Khatma.** Reaching page 604 completes a khatma for any start page. Closing the reader on page 604 asks "Complete khatma?". Yes counts every page through 604, then moves the marker and the start page to 1. The prompt asks "Count N pages as read?" with N = `604 - m + 1`, and says so when the marker is already on 604 (N is then 1). It replaces the big-move confirmation. Yes cannot be undone (decided 2026-11-13). No changes nothing. A user whose start page is 31 completes a khatma after 574 pages.
*   **Restart Wird.** Writes a record with no marker and a higher cycle number (both Restart and Reset All always bump the cycle, decided 2026-11-13), increments the version, resets progress and the record's khatma data to zero, and deletes the color. It never touches the juz-mode khatma fields.
*   **Reset All Progress (decided 2026-11-13).** The existing button stays, and it moves to the last row of the Wird tab settings section (`_buildSettingsSection`, `wird_tab.dart:1200`), in red, in both modes. Restart Wird sits above it in the same section, separated by a divider (decided 2026-11-13). It clears everything: streak, totals, history, completed juz, the juz khatma fields, and the marker record (cycle bumps, marker null, color deleted, running total and page khatmas zero). Restart Wird stays on the Wird page and resets only the marker record. Each confirmation dialog states exactly what it deletes: Restart Wird keeps streak and history, and Reset All Progress deletes everything. The new dialog strings exist in English and Arabic.
*   **Versioned marker record.** One record holds the marker page, start page, running page total, khatma count, khatma dates, cycle number, version number and owner id, and applies as a unit. The color is part of this record. The record holds page-mode khatmas only. The record lives in its own cloud document plus one local key.
*   **Juz-mode khatmas (decided 2026-11-13).** Juz mode keeps the legacy `wird_khatm_count` and `wird_khatm_dates` fields unchanged (`wird_tab.dart:149` `resetJuzForKhatma` writes them). The stats, khatma dua and celebration screens show one combined total (juz + page) and one merged date list sorted by date. The legacy fields' stale-push risk is pre-existing and stays in the deferred sync item.
*   **Merge rule.** Restart, Reset All Progress and khatma increment the cycle number. Every marker change increments the version number. Compare cycle first, then version. Push only if the local (cycle, version) is greater than the cloud's, after reading the cloud first. Pull applies when the cloud's is greater than or equal to the local one (decided 2026-11-13): when both are equal, the cloud wins and its record replaces the local one. If the read before a push fails, the marker is kept locally and the push retries on the next start.
*   **Owner and guest rules.** On pull, if the local owner differs from the signed-in account, the local Wird is discarded and the cloud copy is used. On first sign-in, if the account has no cloud Wird, the account claims the guest marker. If the cloud has a Wird, the cloud wins.

## The Problem

The current link between a Wird and a bookmark color causes three kinds of trouble.

1.  **The Wird depends on ordinary bookmarks.** Any bookmark in the linked color can advance the plan. A user cannot keep that color for reference marks, and the code must track which bookmarked pages were already counted. That counted-page set has already produced bugs (fixed in the F38 group on `fix/quran-khatma-wird`). The F38 fixes patched the symptoms of the old model without changing it.
2.  **Reading progress can be lost or counted twice with no way back.** There is no undo. The khatma prompt fires only on a back-press at page 604, only when today's goal is not yet met, and its "yes" path adds the daily goal again instead of the real pages left.
3.  **Sync can overwrite newer state.** The Wird state is pushed to Firestore as a whole document with no version check, and errors are swallowed (`syncToFirestore` returns nothing). A device that was offline can overwrite a Restart or a finished khatma made on another device.

The proposed solution is one marker per user, with progress derived from a small versioned record. A user taps a verse and chooses "Move Wird marker here" in the verse sheet, undoes the last move, and finishes or restarts a khatma through explicit actions. A cycle number and a version number let each device decide whether its copy or the cloud's copy is newer.

## Goals

*   One marker per user in a color picked from a preset grid, with its own shape and separate from bookmarks. Setup through the Wird page. Move through "Move Wird marker here" in the verse sheet that a verse tap opens. Derived progress. Page mode only.
*   Red, green and orange stay reference-only bookmarks and never count toward the Wird.
*   Progress is the stored running page total plus (marker page - start page). The running total is kept in the versioned record and grows at each khatma by the pages counted in that cycle (start page through 604).
*   One-step undo for today's last move (a connection is required for signed-in users). Big-move confirmation at the daily goal. Streak credit tied to the daily goal. "Mark day complete" as a streak-only action. Khatma through the close-reader prompt on page 604.
*   Restart Wird: writes a record with no marker and a higher cycle number, increments the version, resets progress and the record's khatma data to zero, and deletes the color. Streak, history and juz (including juz-mode khatmas) stay untouched.
*   Reset All Progress is kept as a separate full wipe in a less prominent place. It clears the marker record (cycle bumps), the juz khatma fields and everything else. Both confirmation dialogs state exactly what they delete, with English and Arabic strings.
*   A (cycle, version) comparison with read-before-push and a checked pull. The owner id check. The guest claim rule. A result-returning push for the marker record.
*   Page-mode khatma count and dates stored in the versioned record. Juz-mode khatmas stay in the legacy fields. The stats, khatma dua and celebration screens show one combined total (juz + page) and one merged date list sorted by date.
*   Removal of the old color link and of manual page entry in page mode.
*   F38e (stats average unit in juz mode, `wird_provider.dart:16-26`, `quran_stats_screen.dart:142-144`) is in scope. The stats average uses the stored page total in page mode, and the spec defines what the juz-mode average divides and in which unit.
*   English and Arabic strings for every new label, with Arabic numerals.
*   Bookmarks are not synced in this release and stay device-local.
*   Behavior outside the Wird marker (prayer, tasks, focus mode, juz mode, other Firestore documents) stays as it is.

## Non-Goals

Deferred to the later sync and bookmark-sync item:

*   Transactional push and compare-then-apply pull for other Wird fields.
*   Sign-out push before clearing, success reporting for sign-out, pending-clear and dirty flags, and a guard on every sign-out path.
*   A guest-to-account merge dialog. This release claims the guest marker if the cloud is empty, otherwise the cloud wins.
*   Synced today's pages. Each device shows its own today.
*   Bookmark sync, and what the next account sees of device-local bookmarks.
*   Sync observability (status line, move log, analytics). No `firestore.rules` change is needed for this release (see "Current state").

Fixed in separate changes, sequenced around this design:

*   **F38d** (English weekday labels, `quran_stats_screen.dart:384-392`): fixed before this spec.
*   **F38b** (`scrollToAyaNo` unused, `quran_reader_screen.dart`): fixed after this spec, so the two changes do not conflict in the reader file.

Out of scope for this design:

*   Half-page counting, backward-mark rules, the counted-page set, and a marker in juz mode.
*   Counting several colors at once, and up to 5 colors.
*   Migration of existing links, a notice for existing users, and support for older app builds.
*   Undo of a khatma move.

## Open Questions

Decided 2026-11-13 (replaces the earlier decision to keep the transaction guard): no `runTransaction`, no operation queue and no Windows spike. The marker push reads the cloud record with `Source.server` and writes plainly. The race window this leaves is accepted and listed in Risks. Validation of pulled records stays. The Overview keeps calling the guard small.

Each item below is still unresolved. Every other question is decided and recorded in the Overview, the Technical Plan or the Detailed Implementation Plan.

*   **Ribbon placement (UNVERIFIED, device check):** the geometry and the acceptance rule are decided in the Overview. Whether the ribbon meets them on the listed pages and widths is not yet checked, and it cannot be until a build exists.
*   **Offline push behavior (UNVERIFIED, device check):** the marker push is a `Source.server` read followed by a plain `set()`. An offline read fails, so no write follows. The SDK's documented behavior is that a plain offline `set()` stays queued with persistence at its default (no override exists in `lib/`). The window between a successful read and the write is the accepted race (Risks 3 and 11). The device check in the Verification Plan confirms that an offline move returns within about 5 s and keeps the marker locally.
*   **Track route:** this feature adds UI and a Firestore document, which `CLAUDE.md` forbids without an approved spec and "approve phase PN". ADR 0001 has no exception clause. The owner approved the ordering on 2026-11-13 (this feature ahead of the remaining HIGH fixes and the refactor) through ADR 0002 (text in Detailed Implementation item 21, a Level A docs change), status "accepted (user, 2026-11-13)". ADR 0001 is not edited.

--------------------------------------------------------------------------------

## Technical Plan (Architecture)

Facts below marked VERIFIED were read in code on 2026-11-13. Line numbers refer to the files as they are on `main`.

### Current state (what the plan replaces)

*   `WirdSettings` carries `linkedBookmarkColor` and `countedBookmarkPages` (`lib/core/models/wird.dart:9-10`). The Wird tab watches bookmarks inside `build()` and calls `syncBookmarkPages` for any uncounted page (`wird_tab.dart:171-213`).
*   `recordPagesRead` adds pages to today's history entry, increments the streak on first completion, and adds to `wird_total_pages_read` (`wird_service.dart:61-116`). `markDayComplete` credits a full daily goal of pages (`:118-160`).
*   `syncToFirestore` pushes one whole document, `users/{uid}/wird/data`, with `SetOptions(merge: true)` and no version check, and swallows errors (`wird_service.dart:490-512`). `syncFromFirestore` overwrites local data with a 5 s timeout (`:514-560`).
*   The pull runs at provider start (`wird_provider.dart:42-57`) and at sign-in (`auth_provider.dart:89`). A guest's local Wird is pushed only when the user document is newly created (`auth_provider.dart:116-121`). The reconnect hook pushes with `syncToFirestore` (`sync_service.dart:27-31`).
*   Juz mode records khatmas through `recordKhatma` into `wird_khatm_count` and `wird_khatm_dates` (`wird_service.dart:316-325`, `wird_tab.dart:149`).
*   Each `Ayah` has one `page`, and `getAyahsByPage` filters on `a.page == page` (`quran_models.dart:11`, `quran_service.dart:57-60`). The verse sheet receives that `Ayah` from `onAyahTap` (`quran_reader_screen.dart:207-222`).
*   `firestore.rules` has one rule, `match /users/{userId}/{document=**}`, which covers any new document under `users/{uid}/wird/`. No rules change is needed (VERIFIED).
*   **Readers of `wird_total_pages_read`** (symbol search over `lib/`, `test/` and `android/`, run 2026-11-13, VERIFIED): `achievement_service.dart:267, 281, 288` read the prefs key directly to award `wird_khatma` (at least 604 pages), `wird_pages_100` and `wird_pages_300`; `wird_service.dart:18, 444, 502, 540-541` read and write it (`_totalPagesKey`, `getFullState`, `syncToFirestore`, `syncFromFirestore`). `wird_provider.dart:16` and `wird_tab.dart:1159` use only the model field `WirdState.totalPagesRead`. There is no hit in `test/` or `android/`. The marker design must keep the three achievements working (Detailed items 5 and 22).

### Design in one picture

```text
  Reader                          Wird tab                    Settings / danger zone
  ------                          --------                    ----------------------
  verse tap -> verse sheet        Add from Bookmarks          Reset All Progress
   "Move Wird marker here"        Restart Wird                (full wipe)
  close on page 604               Undo last move
   "Complete khatma?"             Mark day complete / undo
  fixed ribbon overlay            color grid (12)
          \                          |                         /
           v                         v                        v
        WirdNotifier (provider)  -- WirdState { marker, undo, derived totals }
                         |
                         v
        WirdMarkerLogic  (pure functions, injected clock, unit tests)
          applySetup / applyMove / applyUndo / applyKhatma / applyRestart (also Reset All)
          progressTotal / khatmaPages / decideSync / shouldRemoveStreakCredit / validate
                         |
          +--------------+------------------+
          v                                 v
   WirdService (existing)           WirdMarkerService (new)
   history, streak, juz,            local key  wird_marker
   legacy khatma fields,            local key  wird_marker_undo   (never synced)
   wird/data blind push             cloud doc  users/{uid}/wird/marker
                                    guarded push / checked pull, 5 s timeout
```

### The marker record

One immutable value, `WirdMarkerRecord`, stored as one JSON string in the local key `wird_marker` and as one document at `users/{uid}/wird/marker`. A new document is a different path from `wird/data`, so the blind whole-document push and the stale settings write cannot touch it.

| Field | Type | Meaning |
| --- | --- | --- |
| `markerPage` | int or null | Current marker page, 1 to 604. Null after Restart or Reset All Progress, and before setup. |
| `startPage` | int | Page the current cycle started on. Becomes 1 after a khatma. |
| `runningTotal` | int | Pages counted in finished khatma cycles. Starts at 0. |
| `khatmaCount` | int | Page-mode khatmas in this record. |
| `khatmaDates` | list of `YYYY-MM-DD` | One date per page-mode khatma. |
| `cycle` | int | Raised only by khatma, Restart and Reset All Progress. |
| `version` | int | Raised by every change (setup, move, undo, khatma, Restart, Reset). |
| `ownerId` | string or null | Account uid. Null for a guest marker. |
| `color` | int (ARGB) or null | The Wird color. Null when there is no marker. Stored as a value, so a later palette change does not recolor an existing marker. |

The color sits in the record because Restart deletes it and a khatma keeps it. `updatedAt` is not stored: ordering never depends on a device clock.

Derived values (pure functions, never stored):

*   **Progress total** = `runningTotal + (markerPage - startPage)` when a marker exists, else `runningTotal`. This replaces `wird_total_pages_read` in page mode. The stats average reads this value.
*   **Pages counted by a move** from page `m` to page `t` (with `t > m`) = `t - m`. Page 31 to 36 adds pages 31 to 35, which is 5.
*   **Pages counted by "Complete khatma?"** from marker page `m` = `604 - m + 1`. Marker 590 counts pages 590 to 604, which is 15. A marker already on 604 counts 1.
*   **Running total after a khatma** = `runningTotal + (604 - startPage + 1)`. Start 31 adds 574.

### State changes

All changes are pure functions from a record to a new record. The service saves the result and then updates today's history and the streak. Each function takes the date as a parameter, so tests control the clock.

| Action | Marker record change | Today's pages and streak |
| --- | --- | --- |
| Setup (chosen bookmark page `p`, color `c`; only when no marker exists, else fails `MARKER_EXISTS`) | `markerPage = p`, `startPage = p`, `color = c`, `ownerId` = current uid or null, `version + 1`, `cycle` unchanged | No pages counted |
| Move to `t` (`t > markerPage`, `t <= 604`) | `markerPage = t`, `version + 1` | Add `t - m` pages. Streak credit if today reaches the daily goal. Save an undo record. |
| Undo last move | `markerPage = previous`, `version + 1` | Remove the move's pages from today. If today drops below the goal and today's credit came from pages, remove today's streak credit. Clear the undo record. |
| Complete khatma (Yes) | `markerPage = 1`, `startPage = 1`, `runningTotal` grows as above, `khatmaCount + 1`, today's date appended, `cycle + 1`, `version + 1`, color kept | Add `604 - m + 1` pages. No undo record is written, and any existing one is cleared. |
| Restart Wird | `markerPage = null`, `color = null`, `runningTotal = 0`, `khatmaCount = 0`, `khatmaDates = []`, `cycle + 1`, `version + 1` | Streak, history, juz and juz-mode khatma fields are unchanged. Undo record cleared. |
| Reset All Progress | Same record change as Restart (also creates the record when none exists) | Also clears streak, totals, history, completed juz and the juz-mode khatma fields (as `resetAllProgress` does today) |
| Mark day complete | None | Today becomes completed with no page credit. The history entry gets `manualCredit = true`. Streak credit is given. |
| Undo complete | None | Reverses the streak credit and the completed flag. No pages change. |

Rules that hold for every action:

*   The marker never moves backward except through undo, a khatma and Restart or Reset All Progress. "Move Wird marker here" is hidden or disabled when the tapped verse's `ayah.page` is at or behind the marker, when no marker exists, and in juz mode.
*   A forward move that adds more pages than the daily goal asks "Count N pages as read?" first. Declining changes nothing. The khatma prompt replaces this confirmation and shows its own page count.
*   Today's credit: a day is completed when `pagesRead >= dailyPageGoal` or `manualCredit` is true. Undo of a move may remove streak credit only when `manualCredit` is false. The `manualCredit` flag is a new optional field in the local history JSON (`wird_progress_history`), defaulting to false when absent, and is not synced.
*   Undo is one step. A second move overwrites the undo record. The undo record holds the previous marker page, the pages added, the local date key, and whether that move granted streak credit. It is local only (`wird_marker_undo`). Undo is refused after midnight, because the stored date key differs from today's.
*   Page mode only (see "Modes" in the Overview). The marker actions are hidden in juz mode, and the marker record and undo record are kept, not cleared, when the user switches modes. Manual page entry in page mode is removed, together with its callers (`wird_tab.dart:696, 1043, 1095, 1131`).

**Behavior when there is no marker (decided 2026-11-13).** "No marker" means either no record at all (a juz-mode user who never set up, or a fresh install) or a record whose `markerPage` is null (after Restart). Every function has one defined result:

| Function | No record (`null`) | Record with `markerPage == null` |
| --- | --- | --- |
| `progressTotal` | 0 | `runningTotal` |
| `applySetup` | starts from `empty()` (all zero, `cycle 0`, `version 0`), sets the marker, `version 1` | sets the marker, keeps `runningTotal`, khatma data and `cycle`, `version + 1` (this is the only case where setup works: it is the state after Restart) |
| `applyMove`, `applyKhatma` | fails `NO_MARKER` | fails `NO_MARKER` |
| `applyUndo` | fails `NO_UNDO` if there is no undo record, else `STALE_RECORD` | `STALE_RECORD` (Restart clears the undo record, so this means it is stale) |
| `applyRestart` (Restart Wird and Reset All) | starts from `empty()` and returns a record with no marker, `cycle 1`, `version 1` and the given `ownerId` (a tombstone that wins over older cloud state) | always bumps `cycle` and `version` and clears marker, color, total and khatma data, even when they are already empty |
| `shouldRemoveStreakCredit` | false when the undo record is null | does not depend on the marker page |
| `decideSync` | `NOTHING` if the cloud has no record, `APPLY_CLOUD` if it has one | as for a normal record |
| `mergeKhatmas`, `averagePerCompletedDay` | legacy values only | legacy values plus the record's |

Reset All Progress therefore always works: `WirdService.resetAllProgress()` wipes streak, totals, history, juz and the legacy khatma fields whatever the marker state is, and the marker step always saves a record with a bumped cycle (a juz-mode or never-set-up user gets a tombstone record with `cycle 1`). Because the cycle is higher than any older cloud record, it wins at the next sync (decided 2026-11-13). If the cloud holds a higher cycle this device has not pulled, the cloud wins as for any record (Risk 12).

### Sync: guarded push and checked pull

Ordering uses the pair (`cycle`, `version`): compare `cycle` first, then `version`.

```text
syncMarker(uid):                      # run at provider start, at sign-in,
  cloud = read users/{uid}/wird/marker   # and on the reconnect hook
          (Source.server, 5 s timeout: an offline read fails, it never returns a stale cache)
  if read failed:      keep local, report "skipped"; retry at next start or reconnect
  if cloud invalid:    keep local, report "skippedInvalidCloud", never push over it (see validation below)
  if cloud absent:     if local is a guest marker (ownerId null)  -> claim: ownerId = uid, write
                       else if local ownerId != uid               -> discard local (empty Wird)
                       else                                       -> write (first write for this account)
  if cloud present:    if local ownerId != uid (including a guest marker)
                                                                  -> discard local, apply cloud
                       else compare (cycle, version):
                         local > cloud   -> plain write of the local record
                         cloud >= local  -> apply cloud   (equal: the cloud wins)

pushIfNewer(uid, record):             # used by undo; one Source.server read, then a plain write
  cloud = read users/{uid}/wird/marker (Source.server, 5 s timeout)
  read failed or cloud invalid                    -> return failed
  cloud exists and compare(record, cloud) <= 0    -> write nothing, return notNewer(cloud)
  else set(doc, record)                           # full replacement, no merge, 5 s timeout
  any error or timeout on the write becomes `failed`
```

*   **Push is a read, a compare and a plain write (decided 2026-11-13).** There is no `runTransaction`, no operation queue and no single-flight rule. The guard is: skip the write if the `Source.server` read fails, or if the cloud record's (cycle, version) is greater than or equal to the local one; otherwise write plainly. `syncMarker` reads once and then writes without a second read. `pushIfNewer` (undo) does its own read and compare.
*   **Accepted race window (decided 2026-11-13).** Between the read and the write another device can write. A write that times out locally can still land later, and an offline plain `set()` stays queued in the SDK. A timed-out undo can therefore land in the cloud while the app showed "Connect to undo". A sync that applies a pulled record can overwrite a move saved on this device while the read was running. None of these is prevented in this release; they are listed in Risks 3, 4 and 11.
*   **Pulled and loaded records are validated (decided 2026-11-13).** A record is valid only if: `markerPage` is null or 1 to 604; when `markerPage` is set, `startPage` is 1 to `markerPage`; `runningTotal` and `khatmaCount` are 0 or more; `cycle` and `version` are 0 or more; every `khatmaDates` entry matches `YYYY-MM-DD`; `color` is null or an int that fits 32 bits; and, for a cloud record, `ownerId` equals the signed-in uid. The pure `validate(r)` checks everything except the owner; `validateCloud(r, uid)` is `validate(r) && r.ownerId == uid`. The uid is the one `WirdMarkerService` reads from its injectable uid source (`String? Function()`, default `FirebaseAuth.instance.currentUser?.uid`, `guest_user` treated as none) and passes into every cloud call, so `readServer(uid)` and `pushIfNewer(uid, record)` apply `validateCloud` themselves: a cloud document that fails it is returned as `invalid`, and a `notNewer(cloudRecord)` is saved locally only after it passes `validateCloud`, otherwise the result is `failed`. An invalid cloud record is skipped (`skippedInvalidCloud`, logged), neither applied nor overwritten. An invalid or unparseable local `wird_marker` string loads as no record (logged), so the next sync can apply a valid cloud record.
*   **No separate dirty flag.** The comparison is the retry: an unpushed local change has a higher version than the cloud, so the next sync pushes it.
*   **Result-returning push (decided 2026-11-13).** `pushIfNewer` returns a result value (`pushed`, `notNewer` with the cloud record, `failed`). The sync step returns `skippedReadFailed` when the pre-read fails. Nothing else in the Wird or settings push path changes.
*   **Undo for a signed-in user** builds the undone record in memory, runs `pushIfNewer`, and saves locally only if the result is `pushed`. If the result is `failed` (offline, read or write error, timeout, or an invalid cloud record), the app shows "Connect to undo" and changes nothing. If the result is `notNewer`, the cloud is ahead: the app applies the cloud record, clears the undo record and shows the "another device has newer progress" message. Guests (no uid) skip the cloud step and undo always works.
*   **Other changes** (move, khatma, Restart, setup) save locally first, then start `syncMarker` without waiting for it (fire and forget, wrapped in try/catch, so it never throws into the caller). A failed push is retried by the next start or reconnect. Every `syncMarker` call site (`WirdNotifier._init`, `auth_provider.dart:89` and `:121`, `sync_service.dart:30`) calls it with `unawaited(...)`, so a slow read never delays sign-in, start-up or the offline-queue replay in `SyncService`.
*   **The existing blind push** (`wird/data`) keeps carrying settings, streak, completed juz and the legacy khatma fields as today. It stops carrying `totalPagesRead`, which no longer has a source in page mode. `linkedBookmarkColor` and `countedBookmarkPages` leave `WirdSettings.toJson`. `fromJson` ignores them if present, so older cloud documents still load. No cleanup of old fields is done.
*   **Call sites that change:** `WirdNotifier._init` (`wird_provider.dart:42-57`), `auth_provider.dart:89` and `:121`, and `sync_service.dart:27-31`.

### Khatma totals shown to the user

`WirdState.khatmCount` becomes the legacy juz count plus the record's `khatmaCount`. `WirdState.khatmDates` becomes the union of the legacy dates and the record's dates, sorted ascending by date string. The stats screen (`quran_stats_screen.dart:79`), the khatma dua screen (`khatma_dua_screen.dart:35-36, 123-138`) and the celebration screen read these combined values. Page-mode Restart never writes the legacy fields. Reset All Progress does.

### Stats (F38e)

*   **Page mode:** `totalPages` = progress total, `averageDaily` = progress total / `totalDaysCompleted`, shown in pages (`wird_provider.dart:16-25`, `quran_stats_screen.dart:142-144`).
*   **Juz mode:** today `averageDaily` divides `wird_total_pages_read` by days, but the screen labels it "juz" (`quran_stats_screen.dart:142-143`). Juz mode never writes pages (`toggleJuzCompleted` at `wird_service.dart:234-299` changes only the completed-juz list, today's juz list and the day count), so the number is wrong. **Decided 2026-11-13:** the juz-mode average is `(legacy wird_khatm_count x 30 + count of currently checked juz) / totalDaysCompleted`. No new storage. It uses only the legacy khatma count and never the record's page-mode khatma count.
    *   It depends on `resetJuzForKhatma` clearing the juz toggles at each khatma (`wird_provider.dart:197-204`, VERIFIED), so a finished khatma moves from "checked juz" into "legacy count x 30" without double counting.
    *   `totalDaysCompleted` includes days completed in page mode, so a user who switches modes sees a slightly lower juz average (accepted).
    *   After this release the legacy count holds juz-mode khatmas only. A legacy count written by an older build's page-mode khatma is also multiplied by 30 (accepted, as there are no real users yet).
    *   **Denominator (decided 2026-11-13):** it stays `totalDaysCompleted`, including days completed with "Mark day complete". Such days add no pages, so they lower the average. No new counter and no migration.
    *   **Label (decided 2026-11-13):** the stat is labeled "Average per completed day" in both modes, in English and Arabic. The existing key `quran_stats_avg_daily` (`quran_stats_screen.dart:141`) gets the new text in both translation files.

### Reader and Wird tab changes

*   **Verse sheet** (`_AyahSheet`, `quran_reader_screen.dart:944-1062`): add a "Move Wird marker here" action. It calls the provider with `ayah.page`. Because every `Ayah` has exactly one page, a verse that continues onto the next page uses the page stored on that `Ayah`. Which of the two pages the data assigns is not verified, but the rule "use `ayah.page`" does not depend on it.
*   **Ribbon (corrected 2026-11-13):** drawn in the reader's top-level `Stack` (`quran_reader_screen.dart:421-555`) after the `PageView`, not inside `_MushafPageState`. Inside the page it would sit under the top bar and would fade and rotate with each page's swipe transform (`:431-463`). It is shown when `_currentPage == markerPage` in page mode, with `top` equal to the measured top bar height (`_topBarKey`) while `_showUI` is true, else 0, `right: 8`, about 14 dp wide and at most 30 dp tall. It reads the marker from `wirdStateProvider`, uses `AppConstants` colors for its outline so it stays visible in dark mode, and the stored color for its fill.
*   **Close prompt:** the `showWirdPrompt` condition (`quran_reader_screen.dart:313-316`) becomes "page mode, marker exists, current page is 604". The dialog title is "Count N pages as read?" with N = `604 - m + 1` (Arabic numerals through `NumberFormatter`). The body says the khatma completes and cannot be undone. When the marker is already on page 604 the body uses a second text: the marker is already on page 604, so only this page is counted. Yes calls the provider's khatma action, then shows `KhatmaCelebrationScreen` with the combined count. The old call pair `recordPageKhatma` plus `markComplete` is removed.
    *   **No goal gate (decided 2026-11-13).** The current condition `!wirdAlreadyDone` (`quran_reader_screen.dart:316`) is removed, so the prompt shows on every close at page 604 with a marker, even if today's goal is met or the marker is already on 604. A kept gate would make page 604 uncountable for a user who already met today's goal.
    *   **"Keep reading" stays.** The dialog keeps its three buttons (`quran_reader_screen.dart:331-344`): keep reading (stay in the reader, change nothing), No (close the reader, change nothing) and Yes. Only the title, body and Yes text change, and they state the page count.
*   **Replace-bookmark dialog** (`quran_reader_screen.dart:244-292`): kept for red, green and orange. **Decided 2026-11-13:** the title becomes "Bookmark" and the question becomes "Add another bookmark or replace one?", so neither mentions the Wird or "using" a color. The strings are new in English and Arabic, and the product owner reviews the Arabic. The old `wird_bookmark_mode_*` strings (and `wird_bookmark_pages_title`, if nothing else uses it) are removed after a search shows no other use.
*   **Wird tab:** remove the bookmark auto-sync block (`wird_tab.dart:171-213`), `_syncInProgress`, the manual page entry dialog and its callers, and the choose-one helper `countedPagesAfterChooseOne` (`wird_tab.dart:26`). "Add from Bookmarks" opens a list of ordinary bookmarks (all colors), then the 12-color grid, then sets the marker. With no bookmarks it shows the empty state with an "Open reader" button. New controls: "Undo last move" (separate from the existing "undo complete" control, which stays and is shown only when today's entry has `manualCredit`; the `_showUndo` flag is removed), "Restart Wird" with its dialog, and a relocated "Reset All Progress" with its own dialog. Each dialog lists exactly what it deletes.
    *   **Undo placement (decided 2026-11-13):** two entry points that call the same provider method `undoMove()`. After each move, the reader shows a snackbar with an "Undo" action. The Wird tab shows an "Undo last move" button all day while a valid undo record exists for today. Both share one connection check ("Connect to undo" when a signed-in user is offline) and one result message. The snackbar layout is checked on a phone and a Windows window.
    *   **Placement (decided 2026-11-13):** "Restart Wird" and "Reset All Progress" are the last two rows of `_buildSettingsSection` (`wird_tab.dart:1200`), separated by a divider, with Reset All Progress last and in red, in both modes. The two existing copies of the reset button (`wird_tab.dart:530`, `:1074`) are removed. "Restart Wird" is hidden in juz mode, because juz mode has no marker.
    *   **Connection (decided 2026-11-13):** Restart and Reset All Progress need no connection. Each writes a higher cycle, so it wins over older state, saves locally, and the push retries at the next start or reconnect like a move. Only undo needs a connection, because it moves the marker backward.
    *   **Juz mode:** the juz-mode "Add from Bookmarks" button and sheet (`_showBookmarkPagesSheetJuz`, `wird_tab.dart:516, 588`) are removed together with `markJuzFromBookmarks`, because the color link they use no longer exists. Manual juz toggles are unchanged. "Mark day complete" in juz mode becomes streak-only like page mode.
*   **Color grid:** about 12 fixed colors, chosen once for contrast against the page in light and dark mode, excluding shades near the reference red (`0xFFE53935`), orange (`0xFFFB8C00`) and green (`0xFF43A047`) used by `_AyahSheet._colorMap`. No new dependency.
*   **Strings:** every new label goes through `.tr()` with keys added to `assets/translations/en.json` and `ar.json`. Numbers in Arabic go through `NumberFormatter`.

### Contracts and docs that change in the same commits

*   `.project-docs/contracts/firestore-paths.md`: new row for `users/{uid}/wird/marker`.
*   `.project-docs/contracts/prefs-keys.md`: new keys `wird_marker` and `wird_marker_undo`.
*   Folder and module docs that describe the old link: `lib/features/quran/README.md`, `lib/core/services/README.md` (line 72, "cloud wins"), `lib/core/providers/README.md`, `.project-docs/modules/wird.md` and `quran-wird.md`.
*   `STATE.md` lines 30-33 (the reserved-color and up-to-5-colors notes, now superseded), and ADR 0001 or a new ADR for the ordering decision.

## Risks and Mitigations

Each row names a failure, what limits it, and what remains. "Device check" means the Verification Plan checks it once a build exists; nothing here has been run.

| # | Failure mode | Mitigation | Residual risk (accepted) |
| --- | --- | --- | --- |
| 1 | A stale device's offline moves in an older cycle are dropped without a message when it pulls a higher cycle. | The (cycle, version) compare picks one winner. | The loser sees its marker change with no explanation. |
| 2 | Within one cycle the device with the higher version wins even if another device's marker is further. Equal versions: the cloud wins. Two devices that each move once offline both reach the same version, and one device's move is silently dropped (decided 2026-11-13: accepted). | None in this release (Alternative M was rejected). | Silent loss of one move; today's pages and streak stay per device and can disagree with the marker. |
| 3 | A failed push waits for the next start, sign-in or reconnect. | The comparison is the retry, so nothing is forgotten. | An online, foreground app does not retry on its own. A write that times out locally can still land later, and an offline plain `set()` stays queued in the SDK, so it can land after a newer cycle was written elsewhere (decided 2026-11-13: accepted race window). The next sync then applies the cloud record on this device. |
| 4 | Undo gaps: a pull that applies a different record can leave an undo record from another history; a timed-out undo write can still land, so the cloud holds the undone record while the device shows "Connect to undo". | The undo record is valid only for the same `cycle` and `versionAfterMove`, only today, and is cleared by any applied pull, discard, khatma and Restart. | After a timed-out undo, the next pull moves the marker back while today's pages and streak are not adjusted. |
| 5 | The marker, today's history, the streak and the undo record are saved as separate local writes, so a crash between them leaves them out of step. | Order: marker first, then history and streak, then the undo record. | No repair at start-up; a move may lack streak credit or undo. |
| 6 | The page that "Move Wird marker here" credits for a verse that spans two pages depends on which page the data gives that verse (`ayah.page`). | The rule is fixed: use `ayah.page`. | Unverified, so a spanning verse can credit one page too many or too few. Device check: open a verse that crosses a page break and compare the pages credited. |
| 7 | The ribbon does not zoom with the page and can sit over page content on very small windows or at large text scale. | Fixed geometry in the outer margin, with an acceptance rule. | Unverified until a build exists. If it fails, the owner decides the fallback. |
| 8 | "Yes" on the close-on-604 prompt cannot be undone, raises the cycle and so overrides other devices. A marker far from 604 gives a large count. | The prompt shows the exact page count and says it cannot be undone; the user must tap Yes. | A user who taps Yes without reading still completes a khatma. |
| 9 | Security: the catch-all `firestore.rules` rule lets any signed-in client of that account write the marker document, including an older build, and a user can edit their own document by hand. | The record carries `ownerId`, which must equal the uid; `validate` rejects malformed records; the guard is client-side only. | A tampered or older-build write is accepted if its (cycle, version) is higher. The data is the user's own and affects only their Wird and three achievements. A rules check was weighed (Alternative AC) and deferred. |
| 10 | Cost: each start, sign-in and reconnect does one server read and at most one write of a document under 1 KB; an undo adds one more read. | None: a reconnect that flaps runs `syncMarker` each time, which is one read when nothing changed. | About one read per start, sign-in or reconnect and one write per change. No quota estimate beyond that. |
| 11 | Race window of the plain write (decided 2026-11-13): a sync that applies a pulled record can overwrite a move saved on this device while the cloud read ran, because there is no operation queue; two devices can write between another's read and write. | The `Source.server` read before every write, and the (cycle, version) compare. | One device's recent move can be lost or reverted. Offline behavior on Windows is unverified (device check). |
| 12 | Reset All wipes streak, totals, history and juz locally and bumps the marker cycle, but `wird/data` is still pushed by a blind `merge: true`, so a stale device can restore streak and juz khatmas. A device with a higher cloud cycle it has not pulled keeps that record until it syncs. | The marker cycle bump wins at every sync. | Reset All is not a cloud wipe of `wird/data` (deferred sync item). |
| 13 | The ribbon and the palette contrast were measured against `AppConstants.surface`; the mushaf page may use another background. | Palette check against both surfaces. | Device check on real pages in light and dark mode. |
| 14 | Existing users see page-mode totals restart from the new record. | None. | Accepted because there are no real users yet. |
| 15 | Sign-out is deferred (Non-Goals). A guest using the device after sign-out continues the previous account's marker; a guest move keeps the old `ownerId`, and that account's next sign-in could push it. `auth_provider.dart:208-211` has no Wird handling (VERIFIED). | `decideSync` discards a local record whose `ownerId` differs from the signed-in account. | The next user briefly sees the previous account's marker until their first sync. |
| 16 | The juz-mode average multiplies the legacy khatma count by 30, so a legacy count written by an older build's page-mode khatma is also multiplied by 30. | None. | Accepted because there are no real users yet. |

--------------------------------------------------------------------------------

## Alternatives Considered

Each alternative below was weighed while drafting this design. Every reason for rejection states the trade-off that decided it. Only files tracked in the repository are cited (code under `lib/`, `.project-docs/`, `CLAUDE.md`).

### Model and counting

#### Alternative A: Several Wird-color bookmarks with a counted-page set (the current model)

*   **Pros**: Keeps the current model. Bookmarks the user already has can count.
*   **Cons**: Any bookmark in the linked color advances the plan. The counted-page set must stay in step with bookmarks and has already produced bugs (the F38 group, PR #18). Every sync rule must reason about a set.
*   **Reason for Rejection**: One marker with derived progress removes the set and every rule that keeps it in step. The price is a new record, new UI and a new cloud document.

#### Alternative B: Half-page rule and whole-page backward rules

*   **Pros**: Handles marks placed mid-page and moves backward.
*   **Cons**: Needs a position inside the page and rules for what a backward mark means.
*   **Reason for Rejection**: With one forward-only marker there is no mark to place mid-page, so the position and backward rules have nothing to decide. Backward movement exists only through undo, khatma and Restart.

#### Alternative C: Keep the old red, orange and green link

*   **Pros**: No change for the user. No new UI.
*   **Cons**: Keeps the three problems in "The Problem": bookmark dependence, no undo, unguarded sync.
*   **Reason for Rejection**: It leaves all three problems in place. The only saving is the work of this release.

#### Alternative D: Reserved color hidden from the bookmark picker (`STATE.md`, reserved-color notes) and up to 5 colors

*   **Pros**: The Wird still uses a bookmark, so existing bookmark storage and the bookmark picker apply.
*   **Cons**: Needs rules for existing bookmarks already in the reserved color, and the bookmark picker changes. The Wird still depends on bookmark data that is device-local and not synced.
*   **Reason for Rejection**: A marker that is not a bookmark has no bookmark rules to maintain, and it can live in its own synced record. The cost is a second concept (marker) next to bookmarks.

#### Alternative E: Migrate existing links or show a notice

*   **Pros**: Existing links keep working with a message.
*   **Cons**: Migration code and strings for a state that is being removed.
*   **Reason for Rejection**: The cost is code and strings that run once per existing user. The owner states there are no real users yet, so the new build ignores the legacy fields.

#### Alternative F: Count every khatma as 604 pages by definition

*   **Pros**: Nothing extra to store.
*   **Cons**: Total pages and the stats average overstate reading by (start page - 1) for each khatma that began after page 1.
*   **Reason for Rejection**: A stored running page total is exact. The cost is one more field in the record.

#### Alternative G: Wrap to page 1 after 604, and complete the khatma when the marker returns to the start page

*   **Pros**: A khatma is always 604 pages for any start page.
*   **Cons**: Needs a lap value in the record. The marker stops being forward-only at the wrap. A tap on a low page after a high marker is ambiguous (forward wrap or backward move).
*   **Reason for Rejection**: Reaching page 604 completes a khatma for any start page, which keeps the marker forward-only and needs no lap value. The cost is a khatma shorter than 604 pages when the start page is not 1, stated in the khatma rule.

#### Alternative H: "Mark day complete" with page credit, and manual page entry in page mode

*   **Pros**: Lets a user record reading done outside the app.
*   **Cons**: A second source of pages next to the marker, so progress no longer derives from the marker alone. Needs rules for how manual pages and the marker interact.
*   **Reason for Rejection**: The marker stays the only source of pages. "Mark day complete" becomes streak-only, and a user who read outside the app loses exact page credit for it.

#### Alternative I: Undo of a khatma move

*   **Pros**: A mistaken "Yes" could be reversed.
*   **Cons**: Needs the previous cycle, start page, running total and khatma date restored, and the cycle bump has already overridden other devices.
*   **Reason for Rejection**: The restore would have to cross devices, which this release does not do. The prompt shows the exact page count and says it cannot be undone instead (Risk 8).

#### Alternative J: Big-move confirmation on the khatma prompt

*   **Pros**: One confirmation rule for all forward moves.
*   **Cons**: A khatma move count is already known and is shown in its own prompt, so two prompts would ask the same question.
*   **Reason for Rejection**: The khatma prompt shows its own page count and replaces the big-move confirmation.

#### Alternative K: Marker for juz mode

*   **Pros**: One tracking model for both modes.
*   **Cons**: Juz mode keeps its own counters and toggles, which the marker would have to replace.
*   **Reason for Rejection**: Replacing the juz toggles is a larger change than the three problems need. Juz mode keeps its toggles, and the marker is hidden there.

### Sync and storage

#### Alternative L: Device-timestamp ordering

*   **Pros**: Simple. No counters.
*   **Cons**: A device with a wrong clock can win or lose against newer changes. A server timestamp avoids the skew but is only known after a successful write, so it cannot order offline edits.
*   **Reason for Rejection**: Clock skew makes the winner arbitrary, and a server timestamp does not work offline.

#### Alternative M: Move counter plus restart number, and furthest-marker merge

*   **Pros**: A further marker wins, which matches "furthest reading". Two offline moves would not drop one.
*   **Cons**: Needs a move counter and a furthest-marker rule, and it cannot express undo, because undo lowers the marker.
*   **Reason for Rejection**: A cycle number plus a version number can express undo and Restart. The cost is the accepted loss of one device's move when two devices reach the same version (Risk 2).

#### Alternative N: One version number only

*   **Pros**: One field, simpler comparison.
*   **Cons**: A stale device with more offline changes could revert a Restart or khatma.
*   **Reason for Rejection**: A separate cycle number makes Restart and khatma win over any number of old-cycle edits, for the cost of one more field.

#### Alternative O: Full multi-device sync in this release

*   **Pros**: Fixes sync for all Wird fields at once.
*   **Cons**: Needs transactional push for every Wird field, sign-out handling, a guest merge dialog and bookmark sync, which multiplies the review and test surface.
*   **Reason for Rejection**: Too large for this release. The guard covers the marker document only, and the other Wird fields keep their known stale-push risk (Risk 12).

#### Alternative P: Offline undo for signed-in users

*   **Pros**: Undo always works.
*   **Cons**: An offline undo bumps the version while the cloud is unknown, and can lose a race with another device, the same race a forward move has (Risk 2).
*   **Reason for Rejection**: Undo is the one action that moves the marker backward, so it is checked against the cloud first. The cost is that a signed-in user cannot undo offline ("Connect to undo"). Guests have no sync, so their undo always works.

#### Alternative Q: Always discard a guest marker on first sign-in

*   **Pros**: Simple. No claim rule.
*   **Cons**: A guest's reading is lost when they create an account.
*   **Reason for Rejection**: Losing reading on sign-up is worse than one extra rule. The account claims the guest marker when the cloud has no Wird. If the cloud has a Wird, the cloud wins.

#### Alternative R: Marker in the settings map or in the existing Wird document

*   **Pros**: No new document path or contract row.
*   **Cons**: The blind whole-document push (`wird_service.dart:498-508`) and a stale settings write (`:38-47`) can overwrite the marker.
*   **Reason for Rejection**: A separate cloud document keeps those writes away from the marker. The cost is one new path and one contract row.

#### Alternative S: Page-mode khatma dates and count outside the versioned record

*   **Pros**: Fewer fields in the record.
*   **Cons**: A reverted marker can leave a higher khatma count behind.
*   **Reason for Rejection**: Keeping count and dates in the record makes a Restart or an older-cycle pull replace them together with the marker.

#### Alternative T: Juz-mode khatmas written into the record

*   **Pros**: One source for all khatmas.
*   **Cons**: A juz-mode user has no marker. A page-mode Restart would erase juz khatma history. A page-mode device could overwrite juz khatmas through the cycle rule.
*   **Reason for Rejection**: Page-mode khatmas live in the record and juz-mode khatmas keep the legacy fields. The cost is a merge step (`mergeKhatmas`) for the combined count and date list.

#### Alternative U: Legacy khatma fields for both modes, nothing in the record

*   **Pros**: No change to khatma storage. No merge step.
*   **Cons**: A reverted or restarted marker can leave a higher page-mode khatma count behind, and khatma data stays on the unguarded push.
*   **Reason for Rejection**: Page-mode khatma data needs the record's version guard. The cost is the merge step and the juz-average inaccuracy in Risk 16.

### Controls and screens

#### Alternative V: Free color picker, by package or hand-built

*   **Pros**: Any color. A package needs little code.
*   **Cons**: The app has no picker package. A package adds a dependency and a `pubspec.lock` change and may not support Windows. A hand-built HSV picker needs its own layout, RTL and contrast tests. A hex field is awkward to type on a phone.
*   **Reason for Rejection**: A preset grid of 12 colors, checked once for contrast, needs no dependency and no per-color test at run time. The cost is a fixed set of colors.

#### Alternative W: Replace the Reset All Progress button with Restart Wird, or leave it unchanged

*   **Pros**: Replace: one destructive button. Unchanged: no work.
*   **Cons**: Replace: no way to wipe streak, history and juz. Unchanged: a full wipe leaves the marker, running total and page khatmas behind, so progress and streak disagree.
*   **Reason for Rejection**: Both buttons stay. Restart Wird resets only the marker record and Reset All Progress clears everything, including the record. The cost is two destructive controls, each with a dialog that states what it deletes.

#### Alternative X: Setup by page number, or by color first and placing the marker in the reader

*   **Pros**: Page number: works with no bookmarks. Color first: no bookmark needed and no typing.
*   **Cons**: Page number: a mistyped page is hard to correct because the marker only moves forward, and it brings back manual number entry. Color first: a marker can exist with no page, so every screen needs a "not placed" state.
*   **Reason for Rejection**: Setup from a bookmark needs no typing and no "not placed" state. The cost is that a user with no bookmarks must first add one in the reader, which the empty state explains with an "Open reader" button.

#### Alternative Y: Marker drawn inside the page, or shown as an icon in the top bar

*   **Pros**: Inside the page: looks attached to the page and zooms with it. Top-bar icon: no geometry and no overlap with the page.
*   **Cons**: Inside the page: the anchor can leave the visible area after zooming, pages 1 and 2 need a second anchor, and desktop padding shifts it. Top-bar icon: not drawn on the page, easy to miss, and little room beside the desktop zoom controls.
*   **Reason for Rejection**: A fixed ribbon in the reader's `Stack` has no zoom anchor to track. The cost is that it does not zoom or pan with the page (Risk 7).

#### Alternative Z: Undo only from the Wird tab, or only from a reader snackbar

*   **Pros**: One entry point, one place to test.
*   **Cons**: Wird tab only: a user who just moved the marker must leave the reader to undo. Snackbar only: it disappears after a few seconds, so "today's last move, any time before midnight" is not met.
*   **Reason for Rejection**: Both entry points call the same `undoMove()` and share one result mapping. The cost is a second control to build and test.

#### Alternative AA: Firestore transaction (`runTransaction`) and an operation queue for the marker push

*   **Pros**: A transaction reads from the server, compares and writes in one step, and fails offline instead of queuing. A queue and single-flight rule would stop a pulled record from overwriting a move saved during the cloud read.
*   **Cons**: No code in `lib/` uses `runTransaction` today, and its offline behavior on Windows is not known. A call that times out on the client can still commit, so the guard is not absolute. The queue, single-flight rule, cloud interface and a throwaway platform test add many moving parts for one small record.
*   **Reason for Rejection**: The push is a `Source.server` read, a compare and a plain `set()`. The cost is a race window that is accepted and listed in Risks 3 and 11: a write that times out can still land, an offline `set()` stays queued in the SDK, and a pull can overwrite a move saved during the read.

#### Alternative AB: Ribbon drawn inside `_MushafPage`

*   **Pros**: Moves with the page when the user swipes. No new state in the reader screen.
*   **Cons**: The top bar sits above the page in the reader's `Stack`, so the ribbon is hidden while the bar shows. It also fades and rotates with each page's swipe transform.
*   **Reason for Rejection**: The ribbon is drawn in the reader's top-level `Stack` after the `PageView`, offset below the top bar while it shows. The cost is one new measured offset (`_topBarKey`).

#### Alternative AC: Monotonic version check in `firestore.rules`

*   **Pros**: The guard holds for every client, including an older build. A plain write would be enough with no client-side read.
*   **Cons**: A separate rules deploy and emulator tests are needed. A rejected write returns a permission error that the app must map to `notNewer`. The rule must handle document creation. `firestore.rules` is outside this release's file list.
*   **Reason for Rejection**: Not now. It needs a rules deploy and tests that this release does not otherwise touch. It can be reconsidered in the later sync item, together with the other Wird documents.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

Scope: Dart only. No Kotlin, no MethodChannel, no notification or alarm change, no `pubspec.*` change, and `pubspec.lock` is preserved. Every `lib/` and `test/` change is Level C: it needs an approved spec and "approve phase PN" for each phase below. Docs are Level A.

### Phases (one PR, one commit per logical change)

Branch: `feat/wird-marker` from `main`. Rule for every phase (decided 2026-11-13): the app compiles and `flutter test` passes at the end of each phase. Order inside the PR: add new code first (P2, P3), switch the callers (P4a, P4b), delete old code last (P5). Public or shared members that other files call (service and provider methods, model fields, strings, tests) are deleted only in P5. A private member that becomes unreferenced is deleted in the same commit that removes its last caller, so no phase adds an unused-element warning.

The numbering P1 is not used any more: the Windows spike was dropped on 2026-11-13, and the labels P2 to P6 are kept so that existing references stay valid.

| Phase | Content | Items | Gate |
| --- | --- | --- | --- |
| P0 | This spec through `/egm:egm-review` and `/egm:egm-resolve`; the ADR 0002 file and the `decisions/README.md` line are created here, and nowhere else | 21 (ADR only) | Owner approves the spec and the ordering exception |
| P2 | Additive only: models, pure functions and their tests (move, undo, khatma, restart, no-marker rules, validation, sync decision, streak decision, averages, khatma merge, `composeWirdState`). New fields on `WirdState`, `WirdProgress` have defaults, so existing code is untouched. | 1, 2, 4 (add part), 15, 18 (add cases) | "approve phase P2" |
| P3 | Additive only: `WirdMarkerService` (validation, cloud seam), new `WirdService` methods beside the old ones (`creditPages` and `removePages` still mirror the pages into `wird_total_pages_read`, so achievements keep working), new provider actions beside the old ones, sync call sites (start, sign-in, reconnect, all `unawaited`). The provider does not use `composeWirdState` yet, so every displayed value is unchanged. With no marker the new sync calls do nothing. | 3, 5 (add part), 6 (add part), 7, 8, 16, 17 (`creditPages` and `removePages` cases), 21 (the two contract rows only) | "approve phase P3" |
| P4a | Switch the callers (reader and Wird tab) and the state source: marker widgets and the palette (with `wird_marker_palette_test.dart`), reader, Wird tab, the two `KhatmaCelebrationScreen` call sites, strings (new and changed keys except `quran_stats_avg_daily`), the provider switch to `_reload()` and `composeWirdState` (so `totalPagesRead` is now the derived total), `resetAllProgress` calls `WirdMarkerService.resetAll`, and the `markDayComplete`, `undoComplete` and `toggleJuzCompleted` rule changes. `creditPages` and `removePages` keep mirroring `wird_total_pages_read`, so the achievements still read a valid number. After P4a no screen calls the old link or manual-entry methods. | 5 (rules part), 6 (switch part), 9, 10, 11, 13, 14 (new and changed keys), 17 (remaining cases), 19, 24 (compose and action cases) | "approve phase P4a" |
| P4b | Stats and achievements: `quranStatsProvider` uses `averagePerCompletedDay`, the label key `quran_stats_avg_daily`, `achievement_service.dart` reads the marker (khatma count and derived total), and then nothing writes or reads `wird_total_pages_read`: `creditPages`, `removePages` and `resetAllProgress` stop writing it, `getFullState`, `syncToFirestore` and `syncFromFirestore` stop using it. The achievement change and the end of the mirror are in this one phase, so achievements work in every build. | 5 (key part), 6 (stats part), 12, 14 (`quran_stats_avg_daily`), 21 (the `wird_total_pages_read` note only), 22, 23, 24 (stats case) | "approve phase P4b" |
| P5 | Delete old code: `recordPagesRead`, `syncBookmarkPages`, `setLinkedBookmarkColor`, `markJuzFromBookmarks`, `recordPageKhatma`, `linkedBookmarkColor`, `countedBookmarkPages`, `clearLinkedColor`, `_totalPagesKey`, `countedPagesAfterChooseOne` with its test, the unused strings | 4 (remove part), 5 (remove part), 6 (remove part), 14 (removed keys), 18 (legacy-field cases), 20 | "approve phase P5" |
| P6 | Docs and device checks (the ADR and the contract rows are not repeated here) | 21 (remaining docs), Verification Plan | "approve phase P6" |

### Design decisions fixed for implementation

*   **Local keys:** `wird_marker` (JSON string, the record) and `wird_marker_undo` (JSON string, the undo record, local only, never synced). Both live in the `wird_` prefix already used by `wird_service.dart`.
*   **Cloud document:** `users/{uid}/wird/marker`, one document, written only by a plain `set()` after a `Source.server` read and compare (`syncMarker`, `pushIfNewer`), no `merge` (a write replaces the whole record). The document stores the nine record fields only.
*   **Undo record fields:** `previousPage`, `pagesAdded`, `dateKey`, `grantedStreakCredit`, `cycle`, `versionAfterMove`. Undo is allowed only if the live record still has the same `cycle` and `version` as `versionAfterMove`, so a pull or another change invalidates it. This closes the case of undoing a move that a pulled cloud record has already replaced.
*   **Cloud access seam:** an interface `WirdMarkerCloud` with `readServer(uid)` (a `get` with `GetOptions(source: Source.server)`, 5 s timeout, returns `CloudRead`; it applies `validateCloud(record, uid)` and returns `invalid` on failure) and `write(uid, record)` (a plain `set()` with no merge, 5 s timeout, returns `ok` or `failed`). Both turn every error into a result value. The production class wraps `FirebaseFirestore`. `pushIfNewer(uid, record)` is a method of `WirdMarkerService`, not of the interface: it calls `readServer`, applies the compare rule and calls `write`. Tests use a fake `WirdMarkerCloud` that stores one record and can be set to fail; the compare rule is tested through the real `pushIfNewer`. This avoids a new test dependency.
*   **Validation:** one pure `validate(record)` and `validateCloud(record, uid)` in `wird_marker_logic.dart`, used on every cloud and local load. There is no operation queue and no single-flight rule (decided 2026-11-13). The rules are in "Sync: guarded push and checked pull".
*   **Achievements (decided 2026-11-13):** `achievement_service.dart` stops reading the prefs key `wird_total_pages_read`. `wird_khatma` is awarded when the marker record's `khatmaCount` is at least 1 (page-mode khatmas only; juz-mode khatmas never wrote pages, so they did not award it before either). `wird_pages_100` and `wird_pages_300` use the derived progress total (thresholds 100 and 300). The service gets two local reads, `WirdMarkerService.instance.khatmaCountLocal()` and `progressTotalLocal()`, which load the local `wird_marker` record (no cloud call). Details are in item 22. Restart and Reset All lower the total and the count, and already earned achievements stay earned.
*   **Clock and test injection (decided 2026-11-13):** `WirdService` keeps its private constructor and its production singleton `WirdService.instance`, and gains a second constructor `@visibleForTesting WirdService.forTesting({DateTime Function()? now})`; both set a private `_now` field that defaults to `DateTime.now`. Every `DateTime.now()` call in `wird_service.dart` (10 today, counted by grep) goes through `_now`. `WirdMarkerService` has the same shape: `WirdMarkerService.instance` builds the real parts (the Firestore cloud class, `DateTime.now`, the uid reader, `WirdService.instance`), and `WirdMarkerService.forTesting({required WirdMarkerCloud cloud, required WirdService wird, DateTime Function()? now, String? Function()? uid})` takes fakes. It has no `@visibleForTesting` annotation, because `WirdNotifier` also calls it when it is given a uid source or a cloud object (the annotation would raise an analyzer warning in `lib/`). Tests build their own instances and never touch the singletons. Pure functions take the date as a `YYYY-MM-DD` string.
*   **Provider injection (decided 2026-11-13):** `WirdNotifier` gets an optional-argument constructor `WirdNotifier({WirdService? wird, WirdMarkerService? marker, String? Function()? uid, WirdMarkerCloud? cloud})`. Defaults: `wird = WirdService.instance`; `uid` reads `FirebaseAuth.instance.currentUser?.uid` with `guest_user` treated as none; `marker = WirdMarkerService.instance` unless `uid` or `cloud` is given, in which case it is `WirdMarkerService.forTesting(cloud: cloud ?? the production cloud, wird: wird, uid: uid)`. The uid read in `_init` (`wird_provider.dart:45`) uses the injected `uid` source, so no `FirebaseAuth` call runs in a test. `wirdStateProvider` still returns `WirdNotifier()`. A new `wirdServiceProvider = Provider<WirdService>((ref) => WirdService.instance)` is added, and `quranStatsProvider` reads `ref.watch(wirdServiceProvider)` instead of `WirdService.instance` for `getWeeklyPageData`, `getWeeklyJuzData` and `getBestStreak`. A test overrides with `wirdStateProvider.overrideWith((ref) => WirdNotifier(wird: fake, marker: fake, uid: () => 'u1'))` and `wirdServiceProvider.overrideWithValue(fake)`. This replaces the claim that tests never touch the singletons: production code still uses them, tests do not.
*   **Guest and uid:** the default uid reader of `WirdMarkerService` is `FirebaseAuth.instance.currentUser?.uid`, treated as "no uid" when null or `guest_user` (the same test as `wird_provider.dart:46`). It is injectable (see above), so signed-in cases run in tests without Firebase. A guest marker has `ownerId = null`.
*   **`ownerId` in every flow (decided 2026-11-13):**

| Flow | `ownerId` rule |
| --- | --- |
| `placeMarker` (setup) | set to the current uid, or null for a guest |
| `moveMarker`, `completeKhatma`, `restartWird`, `resetAll` | unchanged (the record keeps the owner it has) |
| `undoMove` | if signed in and `ownerId == uid`: undo with a cloud push. If `ownerId` is null (a guest-made marker not yet claimed): undo locally, no cloud call; a later claim pushes the undone record. If `ownerId` is another uid: fails `STALE_RECORD` |
| `syncMarker` write | before any write, the signed-in uid must equal `ownerId`. `CLAIM_AND_PUSH` first saves `record.copy(ownerId: uid)` locally and writes that copy, so the local and cloud copies agree. If the write then fails, the local `ownerId` is already the uid, so the next sync uses `PUSH` |
| `syncMarker` pull | `APPLY_CLOUD` saves the cloud record as is (its `ownerId` is the uid, checked by `validate`). `DISCARD_LOCAL` clears the local record and undo |
| `pushIfNewer` and `WirdMarkerCloud.write` | refuse (`failed`) a record whose `ownerId` is not the uid they were called with |
| sign-out | unchanged (a deferred sync item) |

*   **Cloud document encoding (decided 2026-11-13):** the document at `users/{uid}/wird/marker` and the local key `wird_marker` hold the same map: `markerPage` (int or null), `startPage` (int), `runningTotal` (int), `khatmaCount` (int), `khatmaDates` (list of strings), `cycle` (int), `version` (int), `ownerId` (string; never null in the cloud), `color` (int or null: the 32-bit ARGB value from `Color.toARGB32()`; if the SDK in use lacks it, the `value` getter). Nulls are written as explicit nulls. The local key stores `jsonEncode` of the map. `fromJson` fills a missing key with its default (`markerPage` null, `startPage` 1, `runningTotal` 0, `khatmaCount` 0, `khatmaDates` empty, `cycle` 0, `version` 0, `ownerId` null, `color` null), ignores extra keys, and returns null for a non-map, unparseable or wrongly typed value; it does not repair values. `validate` then decides whether the record is usable. There is no `updatedAt`. Each cloud call (`readServer`, `write`) is wrapped in `Future.timeout(5 s)`; on timeout the result is `failed`.
*   **UI refresh after sync (decided 2026-11-13):** `WirdMarkerService` has a `ValueNotifier<int> revision`, incremented after every local `save`, `clear` and `clearUndo` of the marker or undo record, whoever triggered it (the provider, `auth_provider.dart`, `sync_service.dart`). `save` does not bump `revision` when the new value equals the stored one, and `clearUndo` bumps it only when an undo record existed. `WirdNotifier` attaches the listener once, in its constructor (not in `_init`, because `refresh()` calls `_init()` again), calls `_reload()` on each change, and removes the listener in `dispose`. Every provider action also calls `_reload()` itself after the service call returns, because history and streak changes do not bump `revision`. `_reload()` is: `base = WirdService.getFullState()`, then `state = composeWirdState(base, marker.load(), marker.loadUndo())`. Every other place in the provider that now calls `getFullState` (for example `resetJuzForKhatma`, `wird_provider.dart:200`) calls `_reload()` instead. `_init` does not wait for `syncMarker`: it loads local state, shows it, starts `syncMarker()` without awaiting it, and the listener updates the screen when the sync changes the record. Start-up is therefore never blocked by the 5 s timeouts.

*   **"Mark Complete" and "Undo complete" (decided 2026-11-13).** One completion rule for both modes: `isCompleted = (unit count >= goal) or manualCredit`, where the unit count is `pagesRead` against `dailyPageGoal` in page mode and `juzCompletedToday.length` against `dailyJuzGoal` in juz mode, chosen by `settings.wirdUnit`.
    *   `markDayComplete`: if today's entry exists and is already completed, it does nothing (no `manualCredit`, no streak change). Otherwise it sets `manualCredit = true` and `isCompleted = true`, gives the streak credit and adds 1 to `wird_total_days_completed`. It adds no pages and no juz. Entry values: an existing incomplete entry keeps its `pagesRead`, `juzCompletedToday`, `startPage` and `currentPage`. A new entry (no entry today) is `WirdProgress(date: now, pagesRead: 0, startPage: 1, currentPage: 1, isCompleted: true, manualCredit: true)`; the old values (`pagesRead` and `currentPage` set to the daily goal, `startPage: 1`, `wird_service.dart:128-139`) are removed. The old add of the daily goal to `wird_total_pages_read` (`wird_service.dart:151-154`) is deleted in P4a, so a manual completion no longer changes the page total.
    *   `undoComplete`: allowed only when today's entry has `manualCredit = true`. It sets `manualCredit = false` and recomputes `isCompleted` with the rule above. If the day is still complete, the streak and day count are untouched. If not, it rolls back the streak credit and the day count as the existing `undoComplete` does. Pages and juz are untouched.
    *   `toggleJuzCompleted`: `nowCompleted = (juzToday.length >= dailyJuzGoal) or todayProgress.manualCredit`, so unchecking a juz on a manually credited day does not remove the streak.
    *   **One controller for the button:** the "undo complete" control in `_buildCompletedBanner` is shown if and only if today's entry has `manualCredit == true`. The local flag `_showUndo` (`wird_tab.dart:72`) and its four assignments (lines 321, 492, 583, 1053) are deleted. A day completed by pages or juz shows no such button. This is a visible change to the completed banner.
*   **`creditPages` and `removePages` (decided 2026-11-13):** both live in `WirdService`, work on today's history entry (matched by date key) and keep the existing streak and totals code paths.
    *   `Future<CreditResult> creditPages(int pages, {required int fromPage, required int toPage})`, where `CreditResult` has `grantedStreakCredit` (bool) and `progress` (the saved `WirdProgress`). On the first entry of the day it sets history `startPage = fromPage` (the marker page before the move, or the marker page before a khatma) and always sets `currentPage = toPage`. It adds `pages` to `pagesRead`, sets `isCompleted = pagesRead >= dailyPageGoal or manualCredit`, and when the day becomes complete for the first time it increments the streak (existing `_incrementStreak`) and `wird_total_days_completed`, and returns `grantedStreakCredit = true`; otherwise false. Until P4b it also adds `pages` to `wird_total_pages_read`, with the same condition as the old `recordPagesRead` (`wird_service.dart:100-112`): the add happens unless the day was already complete before this call. Like every other mutator in the service (`wird_service.dart:46, 114, 159, 208, 222, 298`), it ends with `_pushToCloud().catchError(...)` so streak and totals reach the cloud.
    *   `Future<void> removePages(int pages, {required String dateKey, required bool removeCredit, required int restoreCurrentPage})`. If there is no entry for `dateKey`, it does nothing. Otherwise `pagesRead = max(0, pagesRead - pages)`, `currentPage = restoreCurrentPage` (the undo record's `previousPage`) and `startPage` is unchanged. It recomputes `isCompleted` with the completion rule. If `removeCredit` is true and the entry went from completed to not completed, it rolls back the streak credit with the shared private `_rollbackStreakCredit(prefs, today)` and then subtracts 1 from `wird_total_days_completed` (not below 0), as `undoComplete` does. `_rollbackStreakCredit` keeps the existing guard from `undoComplete` (`wird_service.dart:186-201`): it acts only when `streakDate == today`; then it decrements the streak count (not below 0) and, if the count before was 1 or less, removes `streakDate`, otherwise sets `streakDate` to `_yesterdayKey()`. The day count is decremented by the callers, outside the helper, as in the existing code. In P4a `undoComplete` and `toggleJuzCompleted` (which has an inlined copy of the same code at `:282-296`) both switch to the helper; their behavior does not change, and the existing cases for both pin that. `removeCredit` is computed by the caller with `shouldRemoveStreakCredit(undo, todayPagesAfter, dailyGoal)`, where `todayPagesAfter` is `pagesRead - undo.pagesAdded`. Until P4b it also subtracts `pages` from `wird_total_pages_read` (not below 0). It ends with `_pushToCloud().catchError(...)` like `creditPages`.
*   **"Connect to undo" and the undo button (decided 2026-11-13):** `composeWirdState(base, record, undo, today)` drops an undo record whose `dateKey` is not today or whose `cycle` and `versionAfterMove` differ from the live record, so the UI never shows an undo that cannot run. "Undo last move" (Wird tab) is shown while `state.undo != null`; its label is `wird_undo_connect` while the user is signed in and `connectivityProvider` reports offline, else `wird_undo_last_move`. Tapping it, in either label, calls `undoMove()`; the button is disabled only while that call runs. A `NeedsConnection` result shows a snackbar with `wird_undo_connect`. The button disappears at midnight at the next state reload (app resume or any state change); there is no timer, and a tap on a stale undo returns `STALE_DAY` and shows `wird_undo_stale` (accepted).
*   **Undo result mapping (decided 2026-11-13):** one function `void showUndoOutcome(BuildContext context, UndoOutcome outcome)` in `wird_marker_widgets.dart` maps an outcome to a `SnackBar` with the string in "Result and outcome types" (`Done` shows `wird_undo_done`, `CloudNewer` shows `wird_undo_cloud_newer`, `NeedsConnection` shows `wird_undo_connect`, and `Failed(...)` shows `wird_undo_stale`). The reader (after the snackbar's "Undo" action) and the Wird tab (both buttons) call it, so there is one mapping.
*   **Streak decision on undo of a move:** remove today's streak credit only when `grantedStreakCredit` is true and today's pages after the undo are below the daily goal. A move that did not grant credit (credit already existed, from pages or from "Mark day complete") never removes it.
*   **Color palette (values fixed 2026-11-13):** a constant list of 12 `Color` values, `kWirdMarkerPalette`, in `wird_marker_widgets.dart`. Final values, each computed with the two formulas below (script run 2026-11-13, not committed): `1E88E5`, `00838F`, `827717`, `BA68C8`, `964EDE`, `D620D6`, `DE378B`, `A17448`, `5F7A43`, `4F80B0`, `607D8B`, `7272CF` (all with alpha `FF`). Smallest contrast over the two surfaces is 3.37:1 (`BA68C8` on light) and 3.45:1 (`5F7A43` on dark); smallest distance to a reference color is 30.2 (`5F7A43` to green); smallest distance between two palette colors is 19.0. `wird_marker_palette_test.dart` asserts both the rules below and the exact list of 12 values, so changing a value means changing the test and this paragraph in one commit. The figures above come from a script that is not committed. They are unreproduced until the test runs in P4a; if the test computes a different figure, the test result is correct and this paragraph is corrected. The rules:
    *   **Contrast:** WCAG 2.x contrast ratio, `(L1 + 0.05) / (L2 + 0.05)` with relative luminance from sRGB, at least 3.0 against each background. Backgrounds: `AppConstants.surface(false)` = `0xFFFFF8EB` and `AppConstants.surface(true)` = `0xFF1E1E1E` (VERIFIED, `app_constants.dart:35, 43`). Whether the mushaf page paints exactly these colors is a device check.
    *   **Distance:** CIE76 (Euclidean distance in CIE L*a*b*, D65, from sRGB) of at least 25 from each of `0xFFE53935`, `0xFFFB8C00` and `0xFF43A047`. The threshold of 25 is a design choice that keeps palette colors far from the reference colors (a CIE76 difference of about 2.3 is the usual just-noticeable difference); the smallest distance in the chosen set is 30.2.
    *   No duplicate values. There is no "nearest passing shade" step: a value that fails is a defect in the constant list and is fixed there.
*   **Combined khatma values:** `khatmCount = juzKhatmCount + record.khatmaCount`, `khatmDates = sorted(legacyDates + record.khatmaDates)` (string sort works for `YYYY-MM-DD`). The dua screen keeps its existing guard (`dateIndex < khatmDates.length`) for a count and a date list of different lengths.
*   **Stats input mapping (decided 2026-11-13):** `quranStatsProvider` calls `averagePerCompletedDay(unit: wirdState.settings.wirdUnit, progressTotal: wirdState.totalPagesRead, juzKhatmCount: wirdState.juzKhatmCount, checkedJuzCount: wirdState.allCompletedJuz.length, totalDaysCompleted: wirdState.totalDaysCompleted)`. `QuranStatsData.totalPages` is `wirdState.totalPagesRead` (the derived total from P4a), `khatmCount` is `wirdState.khatmCount` (combined), and `weeklyPages`, `weeklyJuz`, `bestStreak`, `allCompletedJuz`, `wirdUnit` and `currentStreak` come from the same sources as today. `QuranStatsData` gets no new field.
*   **Average:** page mode: `progressTotal / totalDaysCompleted`. Juz mode: `(juzKhatmCount * 30 + checkedJuzCount) / totalDaysCompleted`. Both return 0.0 when `totalDaysCompleted` is 0. The label is "Average per completed day" in both modes.

### Pseudocode for the pure functions (`wird_marker_logic.dart`)

```text
compare(a, b):            # a, b are records; a null record is lowest
  cycle first, then version -> -1 / 0 / 1

progressTotal(r):         r == null -> 0
                          r.markerPage == null -> r.runningTotal
                          else r.runningTotal + (r.markerPage - r.startPage)

applyMove(r, target, today):
  fail NO_MARKER      if r == null or r.markerPage == null
  fail NOT_FORWARD    if target <= r.markerPage
  fail OUT_OF_RANGE   if target > 604
  pages = target - r.markerPage
  return (r.copy(markerPage: target, version: r.version + 1), pagesAdded: pages)

needsBigMoveConfirm(pagesAdded, dailyGoal) = pagesAdded > dailyGoal

empty() = record(markerPage: null, startPage: 1, runningTotal: 0, khatmaCount: 0,
                 khatmaDates: [], cycle: 0, version: 0, ownerId: null, color: null)

validate(r) -> bool       # rules in "Pulled and loaded records are validated"; used on every load and pull
validateCloud(r, uid) = validate(r) and r.ownerId == uid

khatmaPages(r) = 604 - r.markerPage + 1                 # pages counted by Yes
applyKhatma(r, today):
  fail NO_MARKER      if r == null or r.markerPage == null
  pages = khatmaPages(r)
  return r.copy(markerPage: 1, startPage: 1,
                runningTotal: r.runningTotal + (604 - r.startPage + 1),
                khatmaCount: +1, khatmaDates: + today,
                cycle: +1, version: +1), pagesAdded: pages

applyRestart(r, ownerId):  # also used by Reset All Progress; never returns null
  base = r ?? empty().copy(ownerId: ownerId)
  return base.copy(markerPage: null, color: null, runningTotal: 0,
                   khatmaCount: 0, khatmaDates: [], cycle: +1, version: +1)
                   # always bumps, even when everything is already empty (decided 2026-11-13)
                   # startPage is kept as the old value but unused while markerPage is null

applySetup(r, page, color, ownerId):
  fail MARKER_EXISTS  if r != null and r.markerPage != null   # Restart first
  base = r ?? empty()
  return base.copy(markerPage: page, startPage: page, color: color,
                   ownerId: ownerId, version: +1)
                   # runningTotal, khatma data and cycle are kept as the record had them

applyUndo(r, undo, today):
  fail NO_UNDO              if undo == null
  fail STALE_RECORD         if r == null or r.markerPage == null
  fail STALE_DAY            if undo.dateKey != today
  fail STALE_RECORD         if r.cycle != undo.cycle or r.version != undo.versionAfterMove
  return r.copy(markerPage: undo.previousPage, version: +1)

shouldRemoveStreakCredit(undo, todayPagesAfter, dailyGoal) =
  undo != null and undo.grantedStreakCredit and todayPagesAfter < dailyGoal

decideSync(local, cloudRead, uid):
  cloudRead failed                       -> SKIP_READ_FAILED
  cloudRead invalid (not validate())     -> SKIP_INVALID_CLOUD
  cloud absent:
      local == null                      -> NOTHING
      local.ownerId == null              -> CLAIM_AND_PUSH   (save local.copy(ownerId: uid), then push it)
      local.ownerId != uid               -> DISCARD_LOCAL
      else                               -> PUSH
  cloud present:
      local == null or local.ownerId != uid -> APPLY_CLOUD
      compare(local, cloud) > 0          -> PUSH
      else                               -> APPLY_CLOUD       # equal or lower: cloud wins

mergeKhatmas(legacyCount, legacyDates, record) -> (count, sortedDates)
averagePerCompletedDay(mode, ...)      as in "Average" above
```

The "Behavior when there is no marker" table in the Technical Plan is the contract for `null` records and `null` marker pages in every function above.

#### Result and outcome types (decided 2026-11-13)

One place for every value. A pure function returns `MarkerResult<T>`, a sealed type with `Ok(value)` and `Err(MarkerFailure)`.

| Type | Values | Returned by |
| --- | --- | --- |
| `MarkerFailure` (enum) | `NO_MARKER`, `MARKER_EXISTS`, `NOT_FORWARD`, `OUT_OF_RANGE`, `NO_UNDO`, `STALE_DAY`, `STALE_RECORD` | pure functions, inside `Err` |
| `MarkerSyncDecision` (enum) | `NOTHING`, `CLAIM_AND_PUSH`, `DISCARD_LOCAL`, `PUSH`, `APPLY_CLOUD`, `SKIP_READ_FAILED`, `SKIP_INVALID_CLOUD` | `decideSync` |
| `CloudRead` (sealed) | `failed`, `invalid`, `absent`, `present(record)` | `WirdMarkerCloud.readServer` |
| `MarkerPushResult` (sealed) | `pushed`, `notNewer(cloudRecord)`, `failed` (any error, including the 5 s timeout) | `WirdMarkerService.pushIfNewer` (`WirdMarkerCloud.write` returns `pushed` or `failed`) |
| `CreditResult` | `grantedStreakCredit` (bool), `progress` (`WirdProgress`) | `WirdService.creditPages` |
| `MarkerSyncResult` | fields `decision` and `push` (a `MarkerPushResult`, or null when nothing was written); the named case `localOnly` means no uid | `syncMarker` |
| `MoveOutcome` (sealed) | `Moved(pagesAdded, markerPage, grantedStreakCredit)`, `Failed(MarkerFailure)` | `moveMarker` |
| `KhatmaOutcome` (sealed) | `Completed(pagesAdded, khatmCount)` where `khatmCount` is the combined total, `Failed(MarkerFailure)` | `completeKhatma` |
| `PlaceOutcome` (sealed) | `Placed`, `Failed(MarkerFailure)` | `placeMarker` |
| `UndoOutcome` (sealed) | `Done`, `CloudNewer`, `NeedsConnection`, `Failed(MarkerFailure)` | `undoMove` |

`restartWird` and `resetAll` return `Future<void>`.

Mapping of an `UndoOutcome` to the user: `Done` shows `wird_undo_done`; `CloudNewer` shows `wird_undo_cloud_newer`; `NeedsConnection` shows `wird_undo_connect`; `Failed(NO_UNDO | STALE_DAY | STALE_RECORD | NO_MARKER)` shows `wird_undo_stale`. A `Failed` from `moveMarker`, `completeKhatma` or `placeMarker` has no user text, because the controls that call them are hidden in those states; it is logged with the `[WIRD]` prefix.

Signatures of the pure functions (`wird_marker_logic.dart`):

```text
int compare(WirdMarkerRecord? a, WirdMarkerRecord? b)
bool validate(WirdMarkerRecord r)
bool validateCloud(WirdMarkerRecord r, String uid)
int progressTotal(WirdMarkerRecord? r)
MarkerResult<WirdMarkerRecord> applySetup(WirdMarkerRecord? r, int page, int color, String? ownerId)
MarkerResult<({WirdMarkerRecord record, int pagesAdded})> applyMove(WirdMarkerRecord? r, int target, String today)
bool needsBigMoveConfirm(int pagesAdded, int dailyGoal)
int khatmaPages(WirdMarkerRecord r)
MarkerResult<({WirdMarkerRecord record, int pagesAdded})> applyKhatma(WirdMarkerRecord? r, String today)
WirdMarkerRecord applyRestart(WirdMarkerRecord? r, String? ownerId)
MarkerResult<WirdMarkerRecord> applyUndo(WirdMarkerRecord? r, WirdUndoRecord? undo, String today)
bool shouldRemoveStreakCredit(WirdUndoRecord? undo, int todayPagesAfter, int dailyGoal)
MarkerSyncDecision decideSync(WirdMarkerRecord? local, CloudRead cloudRead, String uid)
({int count, List<String> dates}) mergeKhatmas(int legacyCount, List<String> legacyDates, WirdMarkerRecord? r)
double averagePerCompletedDay({required WirdUnit unit, required int progressTotal, required int juzKhatmCount,
                               required int checkedJuzCount, required int totalDaysCompleted})
WirdState composeWirdState(WirdState base, WirdMarkerRecord? record, WirdUndoRecord? undo, String today)
```

`composeWirdState` fills `marker`, `undo` (only if it is valid today and for the live record, see "Connect to undo"), `juzKhatmCount` (= `base.khatmCount`, the legacy value), `totalPagesRead` (= `progressTotal(record)`), and the combined `khatmCount` and `khatmDates` (`mergeKhatmas`). `averagePerCompletedDay` returns 0.0 when `totalDaysCompleted` is 0. `today` is a `YYYY-MM-DD` string in the device's local time zone, taken from the injected clock when the call is made.

### Flows (service level)

Flows run one after another from UI taps, with no queue. `syncMarker` is started without waiting (`unawaited`, wrapped in try/catch, never throws into the caller).

```text
moveMarker(target) -> MoveOutcome:         # called by the reader and tested without UI
  r = load()
  (r2, pages) = applyMove(r, target, today)     # may fail (NO_MARKER, ...) -> return failure
  save(r2); credit = WirdService.creditPages(pages, fromPage: r.markerPage, toPage: target)
  saveUndo(prev: r.markerPage, pages, today, credit.grantedStreakCredit,
           r2.cycle, r2.version)
  unawaited(syncMarker())                        # fire and forget; result is logged

placeMarker(page, color) -> PlaceOutcome:  # setup from a bookmark; creates the record when none exists
  r2 = applySetup(load(), page, color, ownerId: cloud uid or null)   # fails MARKER_EXISTS if a marker exists
  save(r2); clearUndo(); unawaited(syncMarker())

completeKhatma() -> KhatmaOutcome:
  r = load()
  (r2, pages) = applyKhatma(r, today)            # fails NO_MARKER when there is no marker; nothing is credited
  juz = await _wird.getKhatmCount()              # wird_service.dart:303, the legacy juz count; returned count = juz + r2.khatmaCount
  save(r2); WirdService.creditPages(pages, fromPage: r.markerPage, toPage: 1)
  clearUndo(); unawaited(syncMarker())

undoMove() -> UndoOutcome:
  r = load(); undo = loadUndo()
  r2 = applyUndo(r, undo, today)                 # may fail -> Failed(...)
  if uid and r.ownerId != null and r.ownerId != uid: return Failed(STALE_RECORD)
  if signed in (uid) and r.ownerId == uid:       # a guest-made marker (ownerId null) is undone locally and
                                                 # claimed later; another account's marker fails STALE_RECORD
                                                 # this call takes at most 5 s per cloud step
      outcome = cloud.pushIfNewer(uid, r2)
      if outcome is notNewer(cloudRecord):      # the cloud is ahead
          save(cloudRecord); clearUndo(); return CloudNewer
      if outcome is failed:                      # offline, timeout or any error
          return NeedsConnection                 # UI text: "Connect to undo"; nothing changed
  today = await _wird.getTodayProgress()              # wird_service.dart:51, through the injected WirdService
  dailyGoal = (await _wird.getSettings()).dailyPageGoal   # wird_service.dart:29
  todayAfter = (today?.pagesRead ?? 0) - undo.pagesAdded
  save(r2); WirdService.removePages(undo.pagesAdded, dateKey: today,
          removeCredit: shouldRemoveStreakCredit(undo, todayAfter, dailyGoal),
          restoreCurrentPage: undo.previousPage); clearUndo()
  return Done

restartWird():  r2 = applyRestart(load(), ownerId: cloud uid or null)   # the UI shows Restart only with a marker
                save(r2); clearUndo(); unawaited(syncMarker())

resetAll():     WirdService.resetAllProgress()        # wipes streak/totals/history/juz/legacy khatma, any mode
                r2 = applyRestart(load(), ownerId: cloud uid or null)   # always saves a record with a bumped cycle
                save(r2); clearUndo(); unawaited(syncMarker())

syncMarker():   uid = cloud uid; if null return LOCAL_ONLY
                cloudRead = cloud.readServer(uid)     # up to 5 s; validateCloud is applied inside
                local = load()                        # loaded after the read, so a move saved meanwhile is seen
                decision = decideSync(local, cloudRead, uid)
                switch decision: PUSH / CLAIM_AND_PUSH -> cloud.write(uid, record)
                                   (CLAIM_AND_PUSH saves record.copy(ownerId: uid) first);
                                 APPLY_CLOUD -> save(cloudRecord);
                                 DISCARD_LOCAL -> clear local record and undo;
                                 SKIP_READ_FAILED / SKIP_INVALID_CLOUD / NOTHING -> no change
                return MarkerSyncResult(decision, pushed / failed)

pushIfNewer(uid, record):                             # used by undoMove
                cloudRead = cloud.readServer(uid)
                failed or invalid                          -> return failed
                present(c) and compare(record, c) <= 0     -> return notNewer(c)
                return cloud.write(uid, record)            # pushed or failed
```

After `APPLY_CLOUD` or `DISCARD_LOCAL` the undo record is cleared when it no longer matches the live record's `cycle` and `version`.

### Target Files to Create/Modify

#### 1. `lib/core/models/wird_marker.dart` (Create)

*   **Type / Scope**: Dart model, no I/O. Phase P2.
*   **Proposed Changes**: `WirdMarkerRecord` (nine fields in the Technical Plan table, `copyWith`, `toJson`, `fromJson` tolerant of missing and extra keys, `==`), `WirdUndoRecord` (six fields), and every type in the "Result and outcome types" table (`MarkerFailure`, `MarkerResult`, `MarkerSyncDecision`, `CloudRead`, `MarkerPushResult`, `MarkerSyncResult`, `MoveOutcome`, `KhatmaOutcome`, `PlaceOutcome`, `UndoOutcome`). `fromJson` follows "Cloud document encoding": it fills defaults, returns null for unusable input, and does not repair values; an out-of-range marker page is rejected by `validate`, not by `fromJson`. The validation rule is in "Sync: guarded push and checked pull".

#### 2. `lib/core/services/wird_marker_logic.dart` (Create)

*   **Type / Scope**: Pure Dart functions, no `SharedPreferences`, no Firebase, no `DateTime.now()`. Phase P2.
*   **Proposed Changes**: every function in the pseudocode section above with the signatures in "Result and outcome types" (including `empty()`, `validate(record)` and `composeWirdState`, with the no-marker results in the Technical Plan table), plus the constant `kLastQuranPage = 604` (used by the reader, so the number has one definition).

#### 3. `lib/core/services/wird_marker_service.dart` (Create)

*   **Type / Scope**: Service with local persistence and cloud sync. Phase P3 (`khatmaCountLocal` and `progressTotalLocal` get their consumer in P4b).
*   **Proposed Changes**: `WirdMarkerService.instance`; no operation queue and no single-flight rule (decided 2026-11-13); `validate` and `validateCloud` applied on every load and pull; `khatmaCountLocal()` and `progressTotalLocal()` (local record only, no cloud call); local load and save for `wird_marker` and `wird_marker_undo` (save skips the `revision` bump when the value is unchanged); the interface `WirdMarkerCloud` (`readServer`, `write`) and its Firestore implementation (`users/{uid}/wird/marker`, `Source.server` read, plain `set()` with no merge, 5 s timeout on each, errors turned into results, `debugPrint` with the existing `[WIRD]` prefix); `pushIfNewer`; `syncMarker`, `moveMarker`, `completeKhatma`, `undoMove`, `restartWird`, `resetAll`, `placeMarker`. Construction and injection follow "Clock and test injection": `WirdMarkerService.instance` for production, `WirdMarkerService.forTesting(cloud:, wird:, now:, uid:)` for tests. It exposes `ValueNotifier<int> revision` (see "UI refresh after sync"), and returns the outcome types in the "Result and outcome types" table. Every call to `syncMarker` made by the service itself is `unawaited` and wrapped in try/catch.

#### 4. `lib/core/models/wird.dart` (Modify)

*   **Type / Scope**: Model. Add part in P2, remove part in P5.
*   **Proposed Changes**: P5: remove `linkedBookmarkColor`, `countedBookmarkPages` and `clearLinkedColor` from `WirdSettings` (`toJson` stops writing them, `fromJson` ignores them). P2: add `manualCredit` (bool, default false, optional in JSON) to `WirdProgress`. Add to `WirdState` (P2, with defaults): `marker`, `undo`, `juzKhatmCount`. `totalPagesRead` holds the derived progress total from P4a on (until then it holds the legacy value). `khatmCount` and `khatmDates` hold the combined values. Update `copyWith`. `QuranStatsData` keeps its fields.

#### 5. `lib/core/services/wird_service.dart` (Modify)

*   **Type / Scope**: Service (carefully: it carries streak and sync for all Wird data). By phase: P3 adds the clock seam first, in its own commit (a private `final DateTime Function() _now`, set by the private constructor `WirdService._({DateTime Function()? now})` and by the public `@visibleForTesting WirdService.forTesting({DateTime Function()? now})`; all 10 `DateTime.now()` calls in the file become `_now()`, and nothing else in the file changes), then `creditPages`, `removePages` and the private `_rollbackStreakCredit` beside the old methods; P4a switches `markDayComplete`, `undoComplete` and `toggleJuzCompleted`; P4b stops all use of `wird_total_pages_read` (`creditPages`, `removePages`, `resetAllProgress`, `getFullState`, `syncToFirestore`, `syncFromFirestore`); P5 deletes `recordPagesRead`, `syncBookmarkPages`, `setLinkedBookmarkColor` and `_totalPagesKey`.
*   **Proposed Changes**:
    *   `creditPages` and `removePages`: signatures, return type (`CreditResult`), day-completion and streak rollback rules are in "`creditPages` and `removePages`" (design decisions). Until P4b both also adjust `wird_total_pages_read` by `pages`.
    *   `markDayComplete`, `undoComplete`, `toggleJuzCompleted`: the rules in "Mark Complete and Undo complete" (design decisions), for both modes. `undoComplete`'s streak rollback code moves into the shared private `_rollbackStreakCredit`.
    *   `resetAllProgress`: unchanged wipe (streak, days, history, completed juz, legacy khatma fields). From P4b it no longer writes `wird_total_pages_read`.
    *   `getFullState`: does not read the marker (the service has no dependency on `WirdMarkerService`, which would be circular). From P4b it no longer reads `wird_total_pages_read`; it returns the legacy khatma values, and `WirdNotifier` combines them with the marker through `composeWirdState`. This is the only place that decides who reads what: P4a changes the provider, P4b changes `getFullState`.
    *   `syncToFirestore` (P4b): stop writing `totalPagesRead`; everything else is unchanged, and the known stale-push risk stays in the deferred sync item. `syncFromFirestore` (P4b): stop reading `totalPagesRead`.
    *   Remove (P5) `syncBookmarkPages`, `setLinkedBookmarkColor`, `recordPagesRead` and the prefs constant `_totalPagesKey`. The prefs key `wird_total_pages_read` itself is left in place in existing installs and is unused.
    *   Add the clock seam and `WirdService.forTesting` (see "Clock and test injection").

#### 6. `lib/core/providers/wird_provider.dart` (Modify)

*   **Type / Scope**: Riverpod provider. P3 adds the new actions and an `unawaited(syncMarker())` in `_init`; P4a switches state composition and `resetAllProgress`; P4b switches `quranStatsProvider`; P5 removes the old methods.
*   **Proposed Changes**:
    *   P3: add the optional constructor arguments and `wirdServiceProvider` from "Provider injection", and add `placeMarker`, `moveMarker`, `undoMove`, `completeKhatma`, `restartWird`. Each calls the service and then `refresh()` (the existing method) until P4a. They return `PlaceOutcome`, `MoveOutcome`, `UndoOutcome`, `KhatmaOutcome` and `void`.
    *   P4a: the notifier gets `_reload()` (`base = getFullState()`, then `composeWirdState(base, marker.load(), marker.loadUndo(), today)`). It attaches one listener to `WirdMarkerService.revision` in the constructor, not in `_init`. `WirdMarkerService.compose(base)` does the local reads (`load`, `loadUndo`, today's date from its clock) and calls `composeWirdState`; `_reload()` and `_init` use it. Every action, `markComplete`, `undoComplete` and `resetJuzForKhatma` calls `_reload()` after the service returns. `resetAllProgress` calls `WirdMarkerService.resetAll()` then `_reload()`. `_init` loads local state, starts `syncMarker()` with `unawaited`, and never waits for it.
    *   P4b: `quranStatsProvider` uses `averagePerCompletedDay` with the "Stats input mapping" arguments (it already reads `wirdServiceProvider` from P3).
    *   P5: remove `recordPagesRead`, `markJuzFromBookmarks`, `setLinkedBookmarkColor`, `syncBookmarkPages`, `recordPageKhatma`. `resetJuzForKhatma` is unchanged and still returns the legacy juz count.

#### 7. `lib/core/providers/auth_provider.dart` (Modify)

*   **Type / Scope**: Sign-in flow. Phase P3.
*   **Proposed Changes**: after `syncFromFirestore(uid)` (line 89) and after `syncToFirestore(uid)` (line 121) call `unawaited(WirdMarkerService.instance.syncMarker())`, so a slow read never delays sign-in. The guest claim happens inside `decideSync`, so an existing account with no cloud Wird now claims the guest marker, and an account with a cloud Wird replaces it.

#### 8. `lib/core/services/sync_service.dart` (Modify)

*   **Type / Scope**: Reconnect hook. Phase P3.
*   **Proposed Changes**: after the existing `syncToFirestore(uid)` call (line 30) call `unawaited(syncMarker())`, so a skipped push retries on reconnect without delaying the offline-queue replay that `SyncService.syncPendingOperations` runs one step after another.

#### 9. `lib/features/quran/wird_marker_widgets.dart` (Create)

*   **Type / Scope**: Flutter widgets for the marker. Phase P4a (the palette test in item 19 is in the same phase).
*   **Proposed Changes**: `kWirdMarkerPalette`; `WirdMarkerRibbon` (small narrow ribbon, outline from `AppConstants` colors, fill from the stored color, with a semantics label); `WirdColorGridSheet` (12 swatches, a selected state, returns the chosen color, RTL-safe, no hex field); `WirdBookmarkPickSheet` (data from `ref.watch(quranBookmarksProvider).valueOrNull ?? []`, `lib/core/providers/quran_provider.dart:18`, all three colors; one row per page, taking the bookmark with the earliest `createdAt` when several share a page; rows sorted by `page` ascending; each row shows the page (through `NumberFormatter`) and the sura name by language (`suraNameAr` or `suraNameEn`); the title is `wird_marker_choose_start`; the sheet returns `Future<int?>` with the chosen page, `null` on cancel; with no bookmarks it shows `wird_marker_no_bookmarks` and an "Open reader" button (`wird_marker_open_reader`) that closes the sheet and runs `Navigator.push(MaterialPageRoute(builder: (_) => QuranReaderScreen(suraNo: 1, initialPage: 1)))`, the same pattern as `wird_tab.dart:475-478`); `WirdColorGridSheet` (title `wird_marker_choose_color`, returns `Future<Color?>`, `null` on cancel). `wird_marker_confirm_yes` and `wird_marker_confirm_no` are the two buttons of the big-move confirmation dialog (`showBigMoveConfirm`). So that the controls can be tested without building the reader and the Wird tab, the file also holds small public pieces: `shouldShowWirdRibbon` and `WirdMarkerRibbonLayer` (the ribbon, drawn only on the marker page in page mode), `WirdUndoMoveButton` (shown only in page mode with a valid undo record; label `wird_undo_connect` while offline), `WirdRestartTile` (shown only in page mode with a marker), `bookmarkPickRows` (one row per page, earliest `createdAt`, sorted by page), `undoOutcomeMessageKey` and `showUndoOutcome` (the one undo mapping).

#### 10. `lib/features/quran/quran_reader_screen.dart` (Modify)

*   **Type / Scope**: Reader (careful: it holds zoom and navigation state, and F38b changes this file later). Phase P4a. Every marker control here is shown only when `settings.wirdUnit == WirdUnit.page`.
*   **Proposed Changes**:
    *   **Marker access:** the reader reads `ref.watch(wirdStateProvider).valueOrNull` and uses `.marker` and `.settings.wirdUnit`; it keeps no copy of its own.
    *   **Literal 604:** the constant `kLastQuranPage` replaces the literal 604 at `quran_reader_screen.dart:316, 428, 509, 517` and at `wird_provider.dart:62`.
    *   **Ribbon:** the reader's top-level `Stack` (line 421) gets the ribbon after the `PageView` (shown when `_currentPage == markerPage` in page mode; `top` = measured top bar height via `_topBarKey` while `_showUI` is true, else 0; `right: 8`; 14 dp wide and 30 dp tall (fixed values; the acceptance check in the Overview can change them, and nothing else may); the top bar height is read as `_topBarKey.currentContext?.size?.height` in a post-frame callback after each change of `_showUI` and on the first build, stored with `setState`, and falls back to `kToolbarHeight` plus the top `MediaQuery` padding while it is null; drawn before the desktop controls so they stay on top). `_MushafPageState` is not changed for the ribbon. `_handleAyahTap` passes `canMoveMarker` (`bool`: page mode, marker exists, `ayah.page > markerPage`) and `onMoveMarker` (`VoidCallback`; the handler closes over the tapped `ayah`) to `_AyahSheet`. `_AyahSheet` gets a "Move Wird marker here" button below the color row. The handler asks "Count N pages as read?" when `needsBigMoveConfirm`, calls `moveMarker`, closes the sheet and shows a snackbar with an "Undo" action that calls `undoMove`. The `showWirdPrompt` condition (line 316) becomes "page mode, marker exists, current page is 604". The khatma dialog shows the page count. The Yes branch (lines 348-358) is rewritten: it deletes the `recordPageKhatma()` call (line 349) and the `markComplete()` call (line 350, which would set `manualCredit` and duplicate the credit that `completeKhatma` already gives through `creditPages`), calls `completeKhatma()` once, and opens `KhatmaCelebrationScreen` with `KhatmaOutcome.Completed.khatmCount` (item 13); the desktop-sidebar line between them stays. If `completeKhatma()` returns `Failed(...)` (not reachable from the prompt, which requires a marker), the reader logs with the `[WIRD]` prefix, stays open and shows no celebration screen. The replace dialog (lines 252-292) switches its four strings in P4a: `wird_bookmark_pages_title` to `bookmark_dialog_title` (line 255), `wird_bookmark_mode_desc` to `bookmark_dialog_question` (256), `wird_bookmark_mode_new` to `bookmark_dialog_add` (264) and `wird_bookmark_mode_update` to `bookmark_dialog_replace` (288); P5 deletes the old keys. Removing `!wirdAlreadyDone` from the `showWirdPrompt` condition is a deliberate behavior change, stated in "Reader and Wird tab changes".

#### 11. `lib/features/quran/wird_tab.dart` (Modify)

*   **Type / Scope**: Wird page (1785 lines; line numbers are as on `main` on 2026-11-13 and are VERIFIED by grep for each name below; edit by name, not by number, if `main` moves). Phase P4a for the switch; private widgets and helpers are deleted in the same commit as their last caller (see the phase rule). The public helper `countedPagesAfterChooseOne` (line 26) is deleted in P5 with its test. Marker controls are hidden when `settings.wirdUnit == WirdUnit.juz`; the segmented button at line 1220 is unchanged.
*   **Proposed Changes** (exact list):
    *   **Delete (P4a, with the callers that are switched):**
        *   the bookmark auto-sync block at the top of `build()` (lines 171-213, from `if (linkedColor != null && !_syncInProgress)`), and the field `_syncInProgress` (line 73);
        *   in `_buildJuzActions` (449): the juz "Add from Bookmarks" button (the `Expanded` at lines 514-523, with `onPressed: _showBookmarkPagesSheetJuz`, and the `SizedBox(width: 8)` at line 513 that sits before it and becomes orphaned, so it is deleted too), and `_showBookmarkPagesSheetJuz` (588);
        *   `_showBookmarkListSheet` (633; called at 625 and 1111, and it calls the removed `markJuzFromBookmarks` and `syncBookmarkPages` around 695-696);
        *   in `_buildActionButtons` (987): the page-mode record button (`_showRecordPagesDialog`, line 1043), `_showBookmarkPagesSheet` (1086) and its call at 1065, `_showRecordPagesDialog` (1119);
        *   the widgets `_BookmarkPagesSheet` (1363), `_BookmarkListSheet` (1530), `_RecordPagesContent` and its state (1649, 1664);
        *   the two copies of the Reset All button: the `SizedBox(height: 4)` plus full-width `TextButton.icon(onPressed: _confirmReset)` block in `_buildJuzActions` (lines 526-535) and in `_buildActionButtons` (lines 1070-1079).
    *   **Keep:** `_confirmReset` (562) with its call, now from the settings section; its dialog uses the changed `wird_reset_confirm_body` text. The "undo complete" control in `_buildCompletedBanner` (299, lines 317-321) shows if and only if today's history entry has `manualCredit == true`; the field `_showUndo` (72) and its four assignments (321, 492, 583, 1053) are deleted, so there is one controller. The "Mark Complete" buttons (491 and 1052) in both modes.
    *   **Add in `_buildActionButtons` (page mode):**
        *   when there is no marker: the "Add from Bookmarks" button (key `wird_add_from_bookmarks`) opens `WirdBookmarkPickSheet`, then `WirdColorGridSheet`, then calls `placeMarker`; cancelling either sheet changes nothing. With no bookmarks the pick sheet shows `wird_marker_no_bookmarks` and an "Open reader" button (`wird_marker_open_reader`);
        *   when a marker exists: the button is replaced by the text `wird_marker_restart_hint`;
        *   "Undo last move" (`wird_undo_last_move`) as a text button below "Mark Complete", visible while a valid undo record for today exists, shown with `wird_undo_connect` as its label while a signed-in user is offline (offline = `connectivityProvider`, `lib/core/providers/connectivity_provider.dart`, VERIFIED to exist). A tap, in either label, calls `undoMove()`; the button is disabled only while that call runs, and its result text follows the `UndoOutcome` mapping (see "Connect to undo and the undo button").
    *   **Undo last move on a completed day (decided 2026-11-13):** the page-mode action block (`_buildActionButtons`) is built only while the day is not complete (`wird_tab.dart:271-286`), so a move that completes the goal would hide the button. `_buildCompletedBanner` therefore gets the `WirdState` as a parameter and, in page mode, shows a second row below the "Wird completed today" row with the same "Undo last move" button (same label rule, same `undoMove()` call and `showUndoOutcome`) whenever `state.undo != null`. The existing "undo complete" control stays in the first row and is shown only when `manualCredit` is true. When the day is not complete the button is in `_buildActionButtons` as described above. The two controls can both be visible and do different things: "undo complete" reverses "Mark Complete", "Undo last move" reverses the marker move.
    *   **Add in `_buildProgressCard` (895):** one line under the progress bar with `wird_marker_page_label` and the marker page, shown only when a marker exists, with a small dot in the stored color.
    *   **Add in `_buildSettingsSection` (1200):** at the end, in this order: a divider, "Restart Wird" (`wird_restart`, shown only in page mode while a marker exists (`marker.markerPage != null`), as the Flows section already says; with a dialog using `wird_restart_confirm_title` and `wird_restart_confirm_body`, calls `restartWird`), then "Reset All Progress" (last, red, `wird_reset_today`, calls `_confirmReset`). Restart Wird is hidden in juz mode, so in juz mode the section ends with Reset All Progress alone, still last and red.
    *   **Change `_handleJuzKhatma` (148-157):** pass the combined count to `KhatmaCelebrationScreen` (item 13).
    *   `resetJuzForKhatma`, the juz grid and the juz toggles are unchanged.

#### 12. `lib/features/quran/quran_stats_screen.dart` (No code change)

*   **Type / Scope**: Stats screen. Phase P4b.
*   **Proposed Changes**: no code change in the screen file. `stats.averageDaily`, `stats.khatmCount` and `stats.totalPages` come from the provider (mapping in "Stats input mapping"), and the label changes through the translation key `quran_stats_avg_daily`. The mapping is tested in item 24. The layout check in the Verification Plan includes this screen, because "Average per completed day" is longer than "Avg. Daily".

#### 13. `lib/features/quran/khatma_celebration_screen.dart` (No change), `khatma_dua_screen.dart` (No change), and the two call sites of `KhatmaCelebrationScreen`

*   **Type / Scope**: The celebration screen takes `required int khatmCount` and `required DateTime date` (`khatma_celebration_screen.dart:14, 17-21`); the screen file does not change. Its callers pass `khatmCount` and do change (VERIFIED by grep, 2026-11-13: exactly two call sites). Phase P4a. `khatma_dua_screen.dart` reads `wirdState.khatmCount` and `khatmDates` from the provider (`khatma_dua_screen.dart:35-36, 123-138`) and needs no edit.
*   **Proposed Changes**:
    *   **Page-mode call site**: `quran_reader_screen.dart:358`, today `KhatmaCelebrationScreen(khatmCount: count, ...)` with `count` from `recordPageKhatma()` (line 349). After the change, `count` is the combined total returned by `completeKhatma` (`Completed.khatmCount`, which is `juzKhatmCount + record.khatmaCount` after the save).
    *   **Juz-mode call site**: `wird_tab.dart:154` inside `_handleJuzKhatma` (lines 147-157). `resetJuzForKhatma()` stays unchanged and still returns the legacy juz count (`wird_provider.dart:197-204`). The call site no longer passes that return value. After the call it reads `ref.read(wirdStateProvider).value?.khatmCount` (the combined value from the reloaded state) and falls back to the returned count if the state is null.
    *   `quran_stats_screen.dart:79` and the dua screen already read the combined `WirdState` values.
    *   Tests: the combined value is covered by `composeWirdState` in item 15 and by `completeKhatma` in item 16. `wird_models_test.dart` does not test screens and is not cited as proof.

#### 14. `assets/translations/en.json` and `assets/translations/ar.json` (Modify)

*   **Type / Scope**: Strings. New and changed keys in P4a (`quran_stats_avg_daily` in P4b), removed keys in P5. Every key is in both files. The Arabic text below is a draft for the product owner to review. A `%d` is filled after `.tr()`: the code replaces `%d` with the number passed through `NumberFormatter.withArabicNumeralsByLanguage`, so Arabic shows Arabic digits; no string contains a literal digit.
*   **Proposed Changes**: New keys:

| Key | English | Arabic (draft) |
| --- | --- | --- |
| `wird_marker_move_here` | Move Wird marker here | انقل علامة الورد إلى هنا |
| `wird_marker_confirm_title` | Count %d pages as read? | هل تحتسب %d صفحة كمقروءة؟ |
| `wird_marker_confirm_yes` | Count them | احتسبها |
| `wird_marker_confirm_no` | Cancel | إلغاء |
| `wird_marker_moved` | Wird marker moved to page %d | تم نقل علامة الورد إلى الصفحة %d |
| `wird_undo_last_move` | Undo last move | تراجع عن آخر نقل |
| `wird_undo_connect` | Connect to undo | اتصل بالإنترنت للتراجع |
| `wird_undo_done` | Last move undone | تم التراجع عن آخر نقل |
| `wird_undo_cloud_newer` | Another device has newer progress. Your Wird was updated. | يوجد تقدم أحدث على جهاز آخر. تم تحديث وردك. |
| `wird_undo_stale` | This move can no longer be undone | لا يمكن التراجع عن هذا النقل بعد الآن |
| `wird_marker_choose_start` | Choose the starting page | اختر صفحة البداية |
| `wird_marker_choose_color` | Choose Wird color | اختر لون الورد |
| `wird_marker_no_bookmarks` | Add a bookmark in the reader first | أضف علامة في المصحف أولاً |
| `wird_marker_open_reader` | Open reader | افتح المصحف |
| `wird_marker_ribbon_label` | Wird marker, page %d | علامة الورد، الصفحة %d |
| `wird_marker_page_label` | Wird marker: page %d | علامة الورد: الصفحة %d |
| `wird_marker_restart_hint` | To choose a new starting page, restart your Wird first. | لاختيار صفحة بداية جديدة، أعد بدء الورد أولاً. |
| `wird_restart` | Restart Wird | إعادة بدء الورد |
| `wird_restart_confirm_title` | Restart your Wird? | إعادة بدء الورد؟ |
| `wird_restart_confirm_body` | This removes your Wird marker, its color, and the page and khatma counts kept with it. Your streak and history are kept. | سيتم حذف علامة الورد ولونها وعدد الصفحات والختمات المسجلة معها. يبقى تتابع الأيام والسجل كما هما. |
| `bookmark_dialog_title` | Bookmark | علامة |
| `bookmark_dialog_question` | Add another bookmark or replace one? | هل تريد إضافة علامة أخرى أم استبدال إحداها؟ |
| `bookmark_dialog_add` | Add another | إضافة أخرى |
| `bookmark_dialog_replace` | Replace one | استبدال إحداها |
| `khatma_finished_body_on_last` | Your marker is already on page %d, so only this page is counted. This completes your khatma. It cannot be undone. | علامتك على الصفحة %d بالفعل، فتُحتسب هذه الصفحة فقط. بهذا تكون قد أتممت ختمة. لا يمكن التراجع عن هذا. |

*   The snackbar "Undo" action reuses the existing key `wird_undo` ("Undo", `en.json:304`). The earlier draft key `wird_undo_action` is dropped as a duplicate.
*   Changed text, same key (the Arabic is replaced too; the old Arabic values were not read for this spec):

| Key | English | Arabic (draft) |
| --- | --- | --- |
| `khatma_finished_title` | Count %d pages as read? | هل تحتسب %d صفحة كمقروءة؟ |
| `khatma_finished_body` | This completes your khatma. It cannot be undone. | بهذا تكون قد أتممت ختمة. لا يمكن التراجع عن هذا. |
| `khatma_finished_yes` | Yes, count them | نعم، احتسبها |
| `wird_reset_confirm_body` | This permanently deletes your streak, all history, completed juz, totals, khatmas and your Wird marker. Your settings are kept. This cannot be undone. | سيتم حذف تتابع الأيام وكل السجل والأجزاء المكتملة والإجماليات والختمات وعلامة الورد نهائياً. تبقى إعداداتك كما هي. لا يمكن التراجع عن هذا. |
| `quran_stats_avg_daily` | Average per completed day | المتوسط لكل يوم مكتمل |

*   Tutorial strings that describe the removed controls (P4a; the existing English and Arabic values of the four keys below were read from `en.json` and `ar.json`; the new Arabic is a draft for the owner):

| Key | English | Arabic (draft) |
| --- | --- | --- |
| `tutorial_wird_body` | Set your daily reading goal in pages or Juz. Track your streak and today's progress, and place a Wird marker in the reader to count the pages you pass. | حدد هدف قراءتك اليومي بالصفحات أو الأجزاء. تتبع سلسلتك وتقدم اليوم، وضع علامة الورد في المصحف لتُحتسب الصفحات التي تتجاوزها. |
| `tutorial_wird_progress_body` | The ring shows how many pages you have read today out of your daily goal. Move your Wird marker in the reader to count pages, or mark the day complete. | تُبيّن الدائرة عدد الصفحات التي قرأتها اليوم من هدفك اليومي. حرّك علامة الورد في المصحف لاحتساب الصفحات، أو اعتبر اليوم مكتملاً. |
| `tutorial_wird_actions_body` | • Start / Continue Reading — opens the Quran at your current Wird page.\n• Mark Complete — marks today's goal done without counting pages.\n• Add from Bookmarks — sets your Wird marker from a bookmark you already made.\n• Undo last move — reverses today's last marker move. | • ابدأ/تابع القراءة — يفتح القارئ عند صفحتك الحالية في الورد.\n• اعتبره مكتملاً — يُعلّم هدف اليوم منجزاً دون احتساب صفحات.\n• أضف من الإشارات — يضع علامة الورد من إشارة سبق أن أضفتها.\n• تراجع عن آخر نقل — يعكس آخر نقل لعلامة الورد اليوم. |
| `tutorial_wird_juz_actions_body` | • Mark Complete — marks your daily juz goal as done. | • اعتبره مكتملاً — يُعلّم هدف الأجزاء اليومي منجزاً. |

*   `khatma_finished_no` ("Not Yet") and `khatma_finished_keep` ("Keep Reading") keep their text. `wird_mark_complete` ("Mark Complete", `en.json:281`) stays the one label for the manual action in both modes.
*   Removal list (P5), each removed only after a repo search shows no other use: `wird_record_pages`, `wird_how_many_pages`, `wird_record_mode_count`, `wird_record_mode_range`, `wird_page_from`, `wird_page_to`, `wird_page_range_invalid`, `wird_page_range_hint`, `wird_bookmark_pages_title`, `wird_bookmark_added`, `wird_bookmark_already_counted`, `wird_bookmark_juz_marked`, `wird_bookmark_no_new_juz`, `wird_bookmark_mode_desc`, `wird_bookmark_mode_new`, `wird_bookmark_mode_update`, `wird_bookmark_no_bookmarks`. The keys `wird_bookmark_color_red`, `wird_bookmark_color_orange`, `wird_bookmark_color_green` and `wird_bookmark_unique_pages` are kept only if the search shows the reader or the new bookmark pick sheet uses them. The search result decides, and the list above is the candidate set.

#### 15. `test/core/services/wird_marker_logic_test.dart` (Create)

*   **Type / Scope**: Unit test. Phase P2.
*   **Proposed Changes**: cover every row of the "Behavior when there is no marker" table (null record and null marker page, for every function), `validate` (each rule, accept and reject), and every branch of the pseudocode: move forward, equal, backward, 604 limit, no marker; big-move threshold at goal and goal plus one; khatma from start 1 and start 31 (574 pages), marker at 590 (15 pages) and at 604 (1 page); restart and reset; setup keeps khatma data and cycle; undo success, wrong day (midnight, injected date), stale record after cycle or version change; streak decision (grant then undo, credit from earlier move, manual credit); `compare` ordering (cycle before version); every `decideSync` row, including equal pairs, a different owner and `SKIP_INVALID_CLOUD`; `mergeKhatmas`; both averages and the zero-day case; `applySetup` fails `MARKER_EXISTS` with a marker and works on `null` and after Restart; `applyRestart` always bumps `cycle` and `version`, on `null` (tombstone with `cycle 1`), on an empty record and on a full one; `validateCloud` rejects another owner; `composeWirdState` (combined khatma values with different list lengths, derived total, no record).

#### 16. `test/core/services/wird_marker_service_test.dart` (Create)

*   **Type / Scope**: Service test with `SharedPreferences.setMockInitialValues`, a fake `WirdMarkerCloud` (stores one record; can be set to fail on read or on write) and an injected clock and uid source. Phase P3. The compare rule is tested through the real `pushIfNewer`.
*   **Proposed Changes**: one test per numbered case; each case names its pass condition.
    1.  Read failure: `syncMarker` returns `SKIP_READ_FAILED` and the local record is unchanged.
    2.  Retry: after case 1, a later `syncMarker` with a working cloud writes the local record.
    3.  Failed write: a write that fails leaves the local record unchanged, and the next `syncMarker` writes it.
    4.  `pushIfNewer` with an equal or newer cloud record returns `notNewer(cloud)` and writes nothing.
    5.  `pushIfNewer` with a failed read, or an invalid cloud record, returns `failed` and writes nothing.
    6.  Undo path: a `notNewer` result saves the cloud record locally, clears the undo record and returns `CloudNewer`.
    7.  Equal pair: two devices at equal (cycle, version) end with the cloud record locally on both, and one device's move is dropped (the documented race).
    8.  Stale device: an older cycle with many moves pulls the newer cycle and keeps none of its own moves.
    9.  Restart on device A, then a move on device B: the higher cycle wins on both.
    10. Guest claim with an empty cloud: the local record is saved with `ownerId = uid` and then written.
    11. Guest with a cloud record: the cloud record replaces the guest record.
    12. Owner change: a local record with another `ownerId` is discarded and the cloud record applies.
    13. `CLAIM_AND_PUSH` followed by a failed write keeps `ownerId = uid`, so the next sync uses `PUSH`.
    14. Invalid cloud record (out-of-range page, bad date, negative count): `SKIP_INVALID_CLOUD`, the local record is kept and the cloud record is not overwritten.
    15. Cloud record with another `ownerId`: returned as `invalid`.
    16. Invalid local string: loads as no record.
    17. `syncMarker` loads the local record after the cloud read, so a move saved during the read is seen by `decideSync`.
    18. `syncMarker` never throws into its caller when the cloud throws.
    19. Signed-in undo offline: returns `NeedsConnection` and changes nothing.
    20. Signed-in undo with the cloud ahead: returns `CloudNewer` and applies the cloud record.
    21. Guest undo works with no cloud call.
    22. Undo of another account's marker fails `STALE_RECORD`.
    23. Midnight: an undo record from another day fails `STALE_DAY`.
    24. A khatma writes no undo record and clears an existing one.
    25. `completeKhatma` returns the combined count (`getKhatmCount()` plus the record's `khatmaCount`).
    26. Reset All with no record (juz-mode or never-set-up user) wipes streak, totals, history and juz, and saves a tombstone record with `cycle 1`.
    27. Reset All and Restart both raise the cycle, on a full record and on an empty one.
    28. `ownerId` per flow: `placeMarker` sets it, and move, khatma, restart and reset keep it.
    29. The `revision` notifier fires when a sync applies or discards a record, and does not fire when the saved value is unchanged.
    30. Cloud map round trip: every field survives, and a missing key takes the default in "Cloud document encoding".
    31. `khatmaCountLocal` returns 0 with no record and the record's count otherwise.
    32. `progressTotalLocal` returns 0 with no record, `runningTotal` with a null marker page, and `runningTotal + (markerPage - startPage)` otherwise.

#### 17. `test/core/services/wird_service_marker_test.dart` (Create)

*   **Type / Scope**: Service test for history, streak and totals. `creditPages` and `removePages` cases in P3; the `markDayComplete`, `undoComplete` and `toggleJuzCompleted` cases in P4a and the `wird_total_pages_read` cases in P4b.
*   **Proposed Changes**: `creditPages` completes the day at the goal and raises the streak once; a second move on the same day does not raise it again; `removePages` rolls back the day completion, the streak, `streakDate` and the day count only when the day goes from complete to not complete, restores `currentPage`, does nothing for a missing entry, and never goes below zero; `creditPages` sets history `startPage` from `fromPage` on the first entry only; `markDayComplete` adds no pages, sets `manualCredit`, and does nothing when the day is already complete (page mode by pages, juz mode by juz); `undoComplete` works only with `manualCredit`, keeps the day complete when pages or juz still reach the goal, and otherwise rolls back (both modes); `toggleJuzCompleted` on a manually credited day keeps the streak when a juz is unchecked; move then undo after a manual completion keeps the credit; `resetAllProgress` clears juz khatma fields; until P4b `wird_total_pages_read` is mirrored by `creditPages` and `removePages`, and from P4b it is never written or read.

#### 18. `test/core/models/wird_models_test.dart` (Create)

*   **Type / Scope**: Model test. Phase P2, except the first two cases (P5).
*   **Proposed Changes**: P5: `WirdSettings.fromJson` ignores legacy `linkedBookmarkColor` and `countedBookmarkPages`; `toJson` omits them. P2: `WirdProgress` reads a history entry without `manualCredit` as false; `WirdMarkerRecord` JSON round trip, missing keys, marker page outside 1 to 604; combined khatma values for a state that has both legacy and record data (and a count and date list of different lengths).

#### 19. `test/features/quran/wird_marker_palette_test.dart` (Create)

*   **Type / Scope**: Unit test for the palette rules. Phase P4a, the phase that creates `wird_marker_widgets.dart` (item 9) and `kWirdMarkerPalette`, which the test imports.
*   **Proposed Changes**: 12 colors; each has a WCAG contrast ratio of at least 3.0 against `0xFFFFF8EB` and `0xFF1E1E1E`; each is at least 25 CIE76 units from each reference color (formulas in "Color palette"); no duplicates; the list equals the 12 values fixed in the design decisions.

#### 20. `test/features/quran/wird_choose_one_test.dart` (Delete)

*   **Type / Scope**: Test of the removed `countedPagesAfterChooseOne` helper. Phase P5, deleted with the helper.
*   **Proposed Changes**: delete with the helper. Its cases (stale-set defect and color switch from the F38 review) have no meaning once the counted set is gone.

#### 21. Documentation and contracts (Modify or Create, Level A)

*   **Contracts change in the same commit as the code (P3 and P4b, not P6):** `.project-docs/contracts/firestore-paths.md` (Modify, in the P3 commit that creates `wird_marker_service.dart`): add `users/{uid}/wird/marker`, written by `wird_marker_service.dart`, owner uid.
*   `.project-docs/contracts/prefs-keys.md` (Modify): add `wird_marker` and `wird_marker_undo` in the same P3 commit; add the note that `wird_total_pages_read` is no longer written or read, and that `achievement_service.dart` no longer reads it, in the P4b commit that makes the change.
*   `.project-docs/decisions/0002-wird-marker-ahead-of-fix-track.md` (Create in P0, once, Level A) with the text below, status "accepted (user, 2026-11-13)" (approved by the owner on 2026-11-13); `.project-docs/decisions/README.md` (Modify) adds the line "0002 — Wird marker ahead of the remaining fix track (feature ordering exception)". ADR 0001 is not edited.

    ```markdown
    # 0002 — Wird marker ahead of the remaining fix track
    Status: accepted (user, 2026-11-13)

    ## Context
    ADR 0001 orders CRITICAL/HIGH fixes before the refactor and has each group state its behavior change in its own
    spec. The Wird marker is a feature: it adds UI, a Firestore document (`users/{uid}/wird/marker`) and local prefs
    keys, and removes the bookmark-color link. CLAUDE.md forbids that without an approved spec and "approve phase PN".
    ADR 0001 has no exception clause. The F38 fixes (PR #18) patched the link model that the marker replaces.

    ## Decision
    - Build the Wird marker (spec `docs/designs/wird-marker.md`) before the remaining fix-track groups and before
      refactor Steps 3–4. It is the first feature work on the fix track. The parked pin-tasks branch (F55) stays parked.
    - The spec states every behavior change. Phases P2, P3, P4a, P4b and P5 each need "approve phase PN" (Level C), and P6 is docs (Level A), on branch
      `feat/wird-marker`, one PR. ADR 0001's workflow applies unchanged: `/egm:egm-draft` → `/egm:egm-review` →
      `/egm:egm-resolve` → approval → tests first.
    - Open fixes in this code keep their order: F38d before the marker, F38b after it.

    ## Consequences
    - Remaining HIGH fixes and the master refactor spec move behind this feature. ADR 0001 is not edited.
    - Contracts change in the same commits as the code: `firestore-paths.md` and `prefs-keys.md` in P3 (the marker path and keys) and `prefs-keys.md` again in P4b (the `wird_total_pages_read` note).
    - Until the marker ships, no other change touches the Wird link code (Wird-tab auto-sync, bookmark sync).
    ```
*   `.project-docs/modules/wird.md`, `.project-docs/modules/quran-wird.md` (Modify): replace the link and counted-set description with the marker model, the record, the sync rule and the undo rule.
*   `lib/features/quran/README.md`, `lib/core/services/README.md` (line 72 and the file table), `lib/core/providers/README.md`, `lib/core/models/README.md` (Modify): new files, removed functions, the new sync behavior.
*   `docs/designs/wird-marker.md` (Create, from this draft at finalization) and `docs/designs/README.md` (Modify): index entry.
*   `.project-docs/STATE.md` (Modify): remove the reserved-color, up-to-5-colors and several-colors notes (lines 31-33) as superseded; record phase status. `.project-docs/log/2026-11-13.md` and later days through the `project-log` skill.
*   `.project-docs/reference/device-checklist.md` (Modify): add the checks below as new `S` entries and rewrite S46.

#### 22. `lib/core/services/achievement_service.dart` (Modify)

*   **Type / Scope**: Achievement checks, phase P4b (the same phase that stops all writes to `wird_total_pages_read`). Not in the original file list; added after the review (decided 2026-11-13).
*   **Callers of `checkAndAward` (grep re-run 2026-11-13 over `lib/` and `test/`, VERIFIED):** the command `grep -rn "checkAndAward" lib test --include=*.dart` printed exactly four lines:
    ```text
    lib/core/services/achievement_service.dart:50:  Future<List<Achievement>> checkAndAward({required String userId}) async {
    lib/core/services/prayer_tracking_service.dart:134:      AchievementService.instance.checkAndAward(userId: userId);
    lib/core/services/task_service.dart:531:        AchievementService.instance.checkAndAward(userId: userId);
    lib/features/profile/profile_screen.dart:1193:        .checkAndAward(userId: userId)
    ```
    So there are three callers: `prayer_tracking_service.dart:134`, `task_service.dart:531` and `profile_screen.dart:1193`. The Profile caller is the achievements section's `initState` (`profile_screen.dart:1189-1196`, `initState`), so Wird achievements are also evaluated each time the Profile screen opens its achievements section. No Wird code calls `checkAndAward`, so a Wird achievement is awarded at the next prayer, task or Profile event, not at the move or khatma itself.
*   **How the marker-based reads behave at those callers:** `checkAndAward` returns an empty list at once for `userId == 'guest_user'` (`achievement_service.dart:50-51`), so guests never reach the Wird block. For a signed-in user the block runs inside the method's existing `try/catch` (the "Error checking achievements" log, `achievement_service.dart:297-299`), and the Profile caller adds its own `.catchError`. The two new reads, `khatmaCountLocal()` and `progressTotalLocal()`, read only the local `wird_marker` key (no Firestore call, no `await` on the network), return 0 when there is no record or the string is invalid, and cannot throw into the caller. Opening Profile therefore costs two local prefs reads, and a user with no marker simply earns none of the three Wird achievements.
*   **Proposed Changes**: in the Wird block (`achievement_service.dart:265-292`), replace the three reads `prefs.getInt('wird_total_pages_read')` (lines 267, 281, 288). Read once before the three checks: `khatmas = await WirdMarkerService.instance.khatmaCountLocal()` and `pages = await WirdMarkerService.instance.progressTotalLocal()`. Then `wird_khatma` is awarded when `khatmas >= 1`, `wird_pages_100` when `pages >= 100` and `wird_pages_300` when `pages >= 300`. The decision is a small pure function `wirdAchievementIds({required int khatmaCount, required int pages})` in the same file that returns the ids the values qualify for, so item 23 can test it without Firebase. Already earned achievements stay earned when Restart lowers the values.
*   **Other "VERIFIED" marks rechecked on 2026-11-13:** `app_constants.dart:35, 43` (the two surface colors) still match; `connectivity_provider.dart` exists and defines `connectivityProvider` at line 82; exactly two `KhatmaCelebrationScreen(` call sites exist (`quran_reader_screen.dart:358`, `wird_tab.dart:154`); the `wird_tab.dart` anchors were rechecked and four line refs were corrected in this pass (segmented button 1220, Reset All blocks 526-535 and 1070-1079, `_handleJuzKhatma` 147-157, juz bookmark `Expanded` 514-523).

#### 23. `test/core/services/achievement_wird_pages_test.dart` (Create)

*   **Type / Scope**: Unit test, phase P4b.
*   **Proposed Changes**: `wirdAchievementIds` returns nothing for `khatmaCount 0` and `pages 99`; `wird_pages_100` at 100; adds `wird_pages_300` at 300; `wird_khatma` at `khatmaCount 1` whatever the pages are (a khatma that started at page 31 adds only 574 pages and still awards it). `khatmaCountLocal` and `progressTotalLocal` cases (no record, null marker page, a record with khatmas) are in `wird_marker_service_test.dart` (P3), because the methods live in the service.

#### 24. `test/core/providers/wird_provider_test.dart` (Create)

*   **Type / Scope**: Provider test with `ProviderContainer`, `SharedPreferences.setMockInitialValues`, `WirdService.forTesting`, `WirdMarkerService.forTesting` and the overrides in "Provider injection" (`WirdNotifier(wird:, marker:, uid:, cloud:)` and `wirdServiceProvider`). Phase P4a for the compose and action cases, P4b for the stats case. Added after the review (decided 2026-11-13).
*   **Proposed Changes**: the notifier attaches one `revision` listener and `refresh()` does not add another; a `revision` bump from a sync reloads the state; each action reloads the state after the service returns; `resetAllProgress` with no record leaves a tombstone record and clears history; `composeWirdState` drops a stale undo (other day, other version); `quranStatsProvider` passes the mapping in "Stats input mapping" (page mode uses the derived total, juz mode uses `juzKhatmCount * 30 + checkedJuzCount`, zero days gives 0.0).

#### 25. `test/features/quran/wird_marker_widgets_test.dart` (Create)

*   **Type / Scope**: Short widget and logic tests for item 9. Phase P4a. Added after approval of P4a (2026-11-14).
*   **Proposed Changes**: the ribbon is drawn only on the marker page, in page mode, 14 x 30 dp at the given top and 8 dp from the right edge; the undo button appears only in page mode with an undo record, shows `wird_undo_connect` while offline, and calls `onPressed` in both labels; the restart tile appears only in page mode with a marker page; `bookmarkPickRows` keeps one row per page (earliest `createdAt`) sorted by page; `undoOutcomeMessageKey` maps every `UndoOutcome`. The reader and Wird-tab screens themselves are checked on a device (Verification Plan), not by widget tests.

### Verification Plan

*   **Per phase (decided 2026-11-13)**: at the end of P2, P3, P4a, P4b and P5, `flutter analyze` shows no new issue and `flutter test` passes, so the app compiles after every phase.
*   **Compilation/Build**: `flutter analyze` (baseline 419 infos and 0 errors as recorded in `STATE.md`, not re-run for this spec; measure again on `main` before P2 and report no new analyzer info). Release APK build only when the owner asks, with the command in `CLAUDE.md`. A Windows build to confirm the reader and Wird tab compile on desktop.
*   **Unit Tests**: `flutter test`; the baseline is 272 passing tests as recorded in `STATE.md` (not re-run for this spec; measure again before P2), and the deleted file removes the cases in item 20. All new tests pass. `test/contracts/native_keys_scan_test.dart` still passes.
*   **Static Analysis & Linting**: `dart format --output=none --set-exit-if-changed` on the files this change creates, and on changed hunks of existing files only (already-unformatted files such as `quran_reader_screen.dart` are not reformatted, so no unrelated lines change).
*   **Test Coverage Requirement**: every branch of `wird_marker_logic.dart` and `decideSync` is covered, which the cases in items 15 to 18 and 24 enumerate. There is no coverage tool run; "covered" means every branch has a named case. No percentage target is set on UI files.
*   **E2E/Integration (device, not run until a build exists)**:
    *   Phone (nova 5T): set up from a bookmark and pick a color (cancelling either sheet saves nothing; with a marker present "Add from Bookmarks" is replaced by the restart hint, and after Restart Wird setup works again); move forward 1 page and by more than the goal (confirmation appears); undo from the snackbar and from the Wird tab; undo after airplane mode when signed in ("Connect to undo") and as a guest; close on page 604 with the marker at 590 (the title reads "Count 15 pages as read?" and the body says it cannot be undone), then at 604 (the title says 1 page and the body says the marker is already on page 604); after Yes there is no undo; Restart (streak and history kept) and Reset All Progress (everything cleared, dialog text correct); juz mode shows no marker UI and keeps its khatma count; **mode switch keeps the marker:** with a marker set and an undo available, switch to juz mode (ribbon, move action, undo, restart and the 604 prompt disappear), then back to page mode (marker, page and undo are exactly as before), and check that the khatma celebration after a juz khatma shows the combined count; **Reset All for a never-set-up user:** in juz mode with no marker ever placed, Reset All Progress clears streak, totals, history, juz and juz khatmas, saves a tombstone record with `cycle 1` (no marker shown), and shows the new dialog text; Restart and Reset All both raise the cycle (check on a second device that an older marker is replaced at the next sync); repeat with a hidden marker (set in page mode, then juz mode) and confirm the marker is cleared; stats show the combined khatma count and the new label in English and Arabic; Arabic numerals in every new string.
    *   Two devices (phone plus Windows): move on one while the other is offline, then reconnect (higher version wins); Restart on one, moves on the other (the newer cycle wins); sign in on a second device with a guest marker and an empty cloud (claim) and with a cloud record (cloud wins).
    *   Offline push: confirm in airplane mode that a marker move returns within about 5 s, the marker is kept locally and undo shows "Connect to undo" with nothing changed. Then reconnect and confirm that nothing from the failed attempt lands in the cloud before the next sync (resolves the Open Question on offline push behavior). Repeat on the Windows build, where the persistence default is unknown. Also check the accepted race: a write started just before airplane mode, and whether it lands after reconnect.
    *   Verse page rule (named risk 6): open a verse that crosses a page break, use "Move Wird marker here", and compare the page the marker lands on and the pages credited with the printed pages. Record the result in the spec.
    *   Palette: on real mushaf pages in light and dark mode, the 12 colors are visible against the page background (named risk 13).
    *   Layout: the ribbon, the undo snackbar and the stats screen (the label "Average per completed day" is longer than "Avg. Daily") on a small phone and in a narrow Windows window, in light and dark mode, with the desktop zoom controls visible.
*   Every device check is reported as run or not run. None is reported as passed unless it ran.

--------------------------------------------------------------------------------

<!-- Provenance: Indicates initial structural drafting via EGM. -->

*Drafted with EGM*

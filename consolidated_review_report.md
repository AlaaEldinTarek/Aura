# EGM Review — fix-prayer-next-stale.md

**Reviewer**: egm-codebase-details (single lightweight review)  
**Target**: `docs/designs/fix-prayer-next-stale.md`  
**Date**: 2026-11-11  
**Result**: 1 Major (fixed), 3 Nits (fixed)

---

## Findings

### 🟡 Major — "debugPrint lines covered by _loadPrayerTimes" was false
`_loadPrayerTimes()` has only one `debugPrint` call, inside its error catch (line 166). It has no "starting refresh" or "refresh complete" trace prints matching the two removed countdown prints. The spec's rationale was factually wrong.  
**Resolution**: replaced with "The two `debugPrint` lines are removed; they were debug-only noise with no replacement needed."

### 🟢 Nit — `onComplete` line range off by one
Spec cited `:744–756`; closing `},` of the callback is at line 757.  
**Resolution**: corrected to `:744–757`.

### 🟢 Nit — "Current code" inner range off by one
Spec cited `:746–755`; `});` closing the microtask is at line 756.  
**Resolution**: corrected to `:746–756`.

### 🟢 Nit — Inline comment missing from "Current code" block
Line 750 (`// Do a full refresh to ensure next day's prayers are loaded if needed`) was absent from the snippet.  
**Resolution**: added to the code block.

---

## Verified Claims

- Local state variables at `:55–57` ✓
- `_loadPrayerTimes()` at `:128` ✓
- `_loadPrayerTimes()` calls the provider and `setState` ✓
- `_loadPrayerTimes()` calls `_loadCompletedPrayers()` ✓
- Both `debugPrint` lines exist in the current code ✓
- `ref.listen` watches `dailyPrayerStatusProvider` only ✓
- No contracts (prefs keys, MethodChannels, notification IDs, Firestore paths) touched ✓

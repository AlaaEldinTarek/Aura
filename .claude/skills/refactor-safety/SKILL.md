---
name: refactor-safety
description: Safety checklist for ANY move/rename/split of code, or edits touching prefs keys, MethodChannels, notification IDs, intent extras, Firestore paths, log tags, or Kotlin files. Use before making such a change.
---

# refactor-safety

1. Check `git status`; stop if target files have uncommitted user changes.
2. Check `.project-docs/contracts/*`. A contract change updates Dart, Kotlin and the contract doc in one commit.
3. Contract with confidence `Partial`/`Unknown` → verify it first, or stop and ask.
4. No file outside the phase's `Target Scope & File Boundary`; if one is needed, stop and request a spec amendment.
5. Keep public APIs via temporary shims until all callers migrate; remove shims in the phase's last commit.
6. Report: files changed, `flutter analyze` / `flutter test` summary, device-checklist items affected — each labeled
   `VERIFIED` / `UNVERIFIED` / `BLOCKED` / `UNKNOWN`.

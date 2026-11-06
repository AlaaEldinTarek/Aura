# Device characterization checklist
Written in Step 2, BEFORE any refactor. Each scenario: steps, observed behavior, `adb logcat` filter.
Baseline captures go in `.project-docs/reference/logcat/` (git-ignored; ignore rule is part of Level B).

Status: NOT STARTED. Device (Huawei nova 5T) BLOCKED — not connected. Secondary: Android 14/15 emulator.
adb: in the Android SDK `platform-tools` folder (not on PATH on the dev machine).
Before Step 2: check `getprop ro.build.version.sdk` and GMS presence.

Scenarios to write (from bootstrap Step 2.3): adhan at prayer time (locked/unlocked/doze), pre-prayer reminder,
post-prayer Done/Late/Missed, daily summary, Jumu'ah reminder, silent mode on/off, all widget variants (light/dark,
LTR/RTL) + tap targets, focus mode start/end, boot reschedule, stale prayer-time recalculation, offline task create →
sync, guest → account migration, Arabic/RTL screens.

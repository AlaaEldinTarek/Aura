# Project Bootstrap — Aura Senior-Level Refactor (EGM + Token-Lean) — V2.1

## Mission

Understand the whole Aura codebase (Flutter + Firebase + native Android Kotlin), then refactor it
into a maintainable, clearly structured, loosely coupled, testable app **without changing user-visible behavior**.
Planning uses the Elephant-Goldfish Model (EGM): the Elephant (this session) holds context and
drafts specs; Goldfish (fresh, zero-context subagents) review them; I approve before code changes.

**Goal is quality, not line counts.** A well-organized 500-line file beats four tightly coupled
200-line files. File-size numbers are signals for review, never targets to hit at any cost.

**Priority:** Minimize token/context usage without sacrificing correctness. Load only task-relevant
files. Never read everything by default. Files >300 lines: search first, read only relevant ranges.

## Approval Levels

| Level | Covers | Approval |
| --- | --- | --- |
| A — Docs | `.project-docs/`, `docs/designs/`, directory READMEs, `concepts_brief.md`, `CLAUDE.md` | Pre-approved for Steps 0, 2, 3, 4 |
| B — Tooling | Plugin install, `.claude/settings*.json`, hooks, skills, `analysis_options.yaml`, test infrastructure (test config files, runner/CI setup, mocking-library setup) | Show the exact files/diff, wait for "approve B" |
| C — Production code | Anything under `lib/`, `android/`, `windows/`, `pubspec.*`, and test cases, fakes and helpers under `test/` | Approved spec + explicit "approve phase PN" |

Approval at one level never implies another. Approval of one phase never implies the next.
Formatting is an edit: running `dart format` in write mode needs the approval level of the files it touches
(B for tooling files, C for `lib/`, `android/`, `test/`), and never in the same commit as logic changes.

## Ground Rules (all steps)

- **Behavior-preserving:** refactor ≠ redesign. No new features, no UI changes, no Firestore schema
  changes, no SharedPreferences key renames, no notification/alarm ID or channel changes unless a spec approves it.
- **Native keys are contracts:** prefs names, MethodChannel names/methods, notification IDs/channels,
  intent extras and Firestore paths are shared between Dart and Kotlin. Treat them as a public API;
  changing one side requires changing the other in the same commit and updating the contract doc.
- **Log output is a contract too:** existing log tags/emoji used in `adb logcat` filters
  (e.g. `PrayerAlarm`, `NotificationService`, `PrayerTimes`, `AdhanPlayer`, `SilentMode`, `🕌`) must keep working.
  Keeping tag names is not enough: any logging change is verified by comparing captured `adb logcat`
  output for the same device-checklist scenarios before and after (same filters, same events, same order).
- **Never launch MainActivity from native code** (existing invariant; keep it).
- **Phase write boundaries (EGM):** brainstorm/draft/review/resolve write only Level A files.
  Implementation may only touch files in the approved spec's `Target Scope & File Boundary`.
- Never commit secrets, `google-services.json` changes, keystores, `firebase_options` edits, or local paths.

### Zero-Guessing & Change Protection

- Never assume undocumented behavior. Investigate it or mark it `UNKNOWN` and ask me.
- "Not found by search" ≠ "unused". Dynamic keys, reflection, native-side reads and string
  interpolation exist; absence of a match is `UNKNOWN`, never proof.
- Run `git status` and review the current diff before any Level B/C work. Never overwrite, discard,
  stash or reformat pre-existing user changes; if a target file has uncommitted changes, stop and ask.
- Forbidden without explicit approval: `git reset --hard`, `git clean`, `git checkout -- <file>`,
  `git push --force`, branch deletion, history rewriting, amend of pushed commits.
- Preserve `pubspec.lock`. No `flutter pub upgrade`/dependency changes unless approved; `flutter pub get`
  must leave the lock file unchanged (check `git diff pubspec.lock`).
- Every behavior-sensitive change has a before/after verification strategy written before coding.
- If a needed change crosses the file boundary, STOP and request a spec amendment.
- Never report a build, test, device check or verification as successful unless actually executed.
- Every report labels findings: `VERIFIED`, `UNVERIFIED`, `BLOCKED`, `UNKNOWN`.
- A phase is complete only when code, tests, contracts, docs, and rollback procedure are verified.

## Step 0 — Interview (HARD STOP — NO files before completion)

Do not skip or shorten Step 0, even if answers seem to be in the repo files. Files describe intent;
Step 0 establishes the actual environment. Read nothing beyond `git status` and the commands below
until I have answered. Any answer inferred from files is shown as `UNCONFIRMED` for me to confirm.

Ask all questions in ONE message, then wait:

1. Flutter/Dart SDK version in use? Upgrade allowed during refactor? (default: no)
2. Platforms that matter: Android only, or Windows desktop too? (iOS currently disabled.)
3. Release in progress? Must `main` stay shippable at every commit? (default: yes)
4. Branch strategy: one `refactor/pN-*` branch per phase + PR, or direct commits? (default: branch + PR)
5. May dependencies be bumped? (default: frozen, `pubspec.lock` preserved)
6. Test device/emulator for adhan, alarms, widgets, silent mode, focus mode? Android version?
7. Firebase in tests: Firestore emulator or mocks only? (default: mocks)
8. Top pain points today (slow screens, bugs, hard-to-change areas), prioritized.
9. Shell for hooks: bash, PowerShell, or both?

Run `git status`, `flutter --version`, `flutter analyze` (count only), `flutter test` (summary only).
Unknown answers: suggest defaults and mark UNCONFIRMED.

## Step 1 — Tooling & Token-Lean Docs System

Docs parts are Level A; tooling parts (items 1, 4, 5, 6) are Level B — present them together, apply after "approve B".

1. Install EGM: `claude plugin marketplace add google/elephant-goldfish-model`, then
   `claude plugin install egm@egm`. I run `/reload-plugins` myself.
2. **Shrink `CLAUDE.md`** (currently ~389 lines, loaded every session) to ≤80 lines: Context (≤8 lines),
   Commands, Rules, Context-Loading table. Relocate detail into `.project-docs/modules/*.md`.
   Produce a relocation table (old section → new file) and confirm every fact has exactly one home.
3. Create:
   ```
   .project-docs/
   ├── STATE.md          # <=25 lines, read first every session
   ├── INDEX.md          # topic → file, entries <=120 chars
   ├── modules/          # prayer, notifications-native, tasks, quran-wird, dhikr-azkar, auth-sync,
   │                     # widgets, focus-mode, settings-prefs, desktop, ui-kit  (<=80 lines each)
   ├── contracts/        # prefs-keys, method-channels, notification-ids, intent-extras,
   │                     # firestore-paths, log-tags
   ├── reference/        # baseline.md, device-checklist.md, architecture.md
   ├── decisions/        # NNNN-<slug>.md, Context/Decision/Consequences, <=20 lines
   └── log/              # YYYY-MM-DD.md, archive/YYYY-MM-summary.md
   docs/designs/         # EGM specs (checked in, living)
   ```
4. `.claude/settings.json`: allow `git status/diff/log`, `flutter analyze`, `flutter test`, `dart format --output=none`;
   require approval for `git push`, file deletion, `flutter pub upgrade`, `flutter build`, `dart format` (write mode, see Approval Levels).
   Deny `git reset --hard`, `git clean`, `git push --force`.
5. Stop hook `log-reminder` (spec below).
6. Skills: `project-log` and `refactor-safety` (specs below).

### Doc Size Rules

- Never delete information to meet a line limit. Split into sub-files (`modules/prayer-times.md`,
  `modules/prayer-tracking.md`) and link them from INDEX.
- One fact, one home. Other files link to it instead of repeating it.
- STATE holds current operational status only — no history (history lives in `log/`).
- When a doc exceeds its limit, split it in the same commit that made it exceed.

STATE template:
```
# Project State — YYYY-MM-DD
- App: Aura <version> | Analyze: N issues | Tests: N pass / N fail
- Phase: <P0–P6> <name> | Spec: docs/designs/<file>.md (Draft/Reviewed/Approved)
- Current task: <task>
- Blockers: <issues/none>
- Next: <action>
```

### Stop Hook Spec (`log-reminder`)

Registered under `hooks.Stop` (`type: "command"`), script in `.claude/hooks/`. It must:
- Resolve repo root with `git rev-parse --show-toplevel` and run all git commands from it.
- List today's commits: `git log --since=midnight --no-merges --format=%h` (local time, merges excluded).
- Skip a commit if ALL its changed files (`git show --name-only --format= <hash>`) are under `.project-docs/`
  (docs-only log/STATE commits), so logging never triggers a new reminder.
- A commit counts as logged if its short hash appears anywhere in `.project-docs/log/YYYY-MM-DD.md` (today, local date).
- Missing log file = all remaining commits unlogged (not an error).
- Unlogged > 0 → print exactly one line: `Log reminder: N commit(s) today not logged.`
  (It repeats on each stop until logged — intended; no state file.)
- Git failure → print exactly one line: `Log hook error: <reason>`. Never fail silently.
- Otherwise print nothing. Read-only (no add/commit/stash/checkout), ignores uncommitted changes, always exit 0.
- Provide bash and/or PowerShell versions per Step 0 answer.

## Step 2 — Understand the Code (Elephant builds context, cheaply)

1. **Baseline metrics** → `.project-docs/reference/baseline.md` (numbers only, re-measured each phase):
   top 20 Dart + top 5 Kotlin files by lines, `flutter analyze` count, test count, hotspot grep counts.
   These are review signals, not targets.
2. **Contracts** → `.project-docs/contracts/*.md`. For each entry record:
   `Name | Dart location | Kotlin location | Read/Write side | Dynamic? | Confidence | Source`.
   - Static search in both Dart and Kotlin (and XML/manifest for IDs, extras, channels).
   - Cross-reference: every key/channel/ID found on one side is searched for on the other.
   - Dynamic patterns (e.g. `prayer_status_{name}_{date}`) are recorded as patterns with every builder site.
   - Confidence: `Verified` (both sides found and read), `Partial` (one side, or dynamic), `Unknown`.
3. **Characterization baseline** → `.project-docs/reference/device-checklist.md`, written BEFORE any refactor
   (each scenario also lists the `adb logcat` filter to capture; I save the baseline captures under a
   git-ignored `.project-docs/reference/logcat/` folder for before/after comparison):
   numbered device scenarios with current observed behavior — adhan at prayer time (locked/unlocked/doze),
   pre-prayer reminder, post-prayer Done/Late/Missed actions, daily summary, Jumu'ah reminder, silent mode
   on/off, all widget variants (light/dark, LTR/RTL) and their tap targets, focus mode start/end, boot reschedule,
   stale prayer-time recalculation, offline task create → sync, guest → account migration, Arabic/RTL screens.
   I run them once on the current build and record results; the same list is re-run after each affected phase.
4. **Run `/egm:egm-bootstrap`** for per-directory contract READMEs, in batches under its 15-subdirectory gate:
   `lib/core/services` → `lib/core/providers` → `lib/core/models,utils,widgets,theme` →
   `lib/features` → `android/app/src/main/kotlin`. One batch per turn; summarize conclusions only.
5. Fill `modules/*.md` from those READMEs (Purpose, Key files, Main classes, Providers, Contracts used,
   Known issues). Code overrides docs; correct conflicts; anything unclear → `UNKNOWN` + question for me.

**Known hotspots from initial survey (approximate grep counts — verify, then refine):**

| Hotspot | Initial measurement |
| --- | --- |
| Large files (Dart) | `tasks_screen` 3158, `home_screen` 2172, `main_wrapper_screen` 2090, `task_form_screen` 1788, `wird_tab` 1738, `quran_reader_screen` 1636, `prayer_screen` 1572, `notification_service` 1483 lines |
| Large files (Kotlin) | `PrayerAlarmReceiver` 1048, `PrayerForegroundService` 862, `MainActivity` 819 |
| Two DI systems | ~26 services use `static instance` singletons beside Riverpod |
| Prefs bypass | ~35 files call `SharedPreferences.getInstance()` directly |
| Logging | ~511 `print`/`debugPrint` calls, no levels |
| RTL logic | ~93 inline `languageCode == 'ar'` checks |
| Theme leaks | ~63 hardcoded `Color(0x…)` in `lib/features` |
| Channels | 14 `MethodChannel(` constructions in Dart for 7 channels |
| State | ~182 `setState` calls, logic inside widgets |
| Tests | 5 test files for ~49k Dart lines |
| Lints | default `flutter_lints` only |
| Naming | `lib/features/dhikl` (typo of dhikr) |

## Step 3 — Brainstorm Target Architecture

Run `/egm:egm-brainstorm` with: "Target architecture for a behavior-preserving refactor of Aura."
Candidate direction (to be challenged, not assumed):

- Feature-first layout: `features/<x>/{data,domain,presentation}`; `core/` only truly shared code.
- One DI system: Riverpod replaces static singletons (temporary `instance` shims during migration).
- Repository layer: screens/providers never touch Firestore/SharedPreferences directly.
- `PlatformChannels` registry: one Dart file owning channel names + typed methods; mirrored constants in Kotlin.
- `AppLogger` with tags/levels that preserves existing logcat tags.
- `context.isRtl` / l10n helpers; theme tokens instead of raw colors.
- Screens split along responsibility (widgets + controller/notifier), judged by coupling and clarity, not size.
- Kotlin split by responsibility (scheduling, playback, notification building, prefs access).

Output: `concepts_brief.md`. I resolve trade-offs.

## Step 4 — Draft, Review, Resolve the Master Spec

1. `/egm:egm-draft` → `docs/designs/aura-refactor.md`: goals/non-goals, target architecture (FeatureRange),
   phased plan (DetailedRange). Each phase lists: scope, `Target Scope & File Boundary`, contracts touched,
   tests to add first, before/after verification (unit + device-checklist items), and rollback procedure.
2. Phases (lowest risk first; each independently shippable and revertible):

| Phase | Work | Risk |
| --- | --- | --- |
| P0 | Safety net: characterization tests for pure logic (prayer times, next-prayer, Hijri, formatters, recurrence, wird streak, tracking), test helpers/fakes | Low |
| P1 | Logging in 3 separate steps — (a) add `AppLogger`, (b) migrate call sites keeping tags, (c) release log policy; each step verified by before/after logcat comparison — plus contracts finalized | Low–Med |
| P2 | Single prefs access service + `PlatformChannels` registry (Dart side only, names unchanged) | Medium |
| P3 | DI (singletons → Riverpod) + repositories, one domain at a time | High |
| P4 | Flutter screen decomposition, one screen per PR (tasks → home → main_wrapper → task_form → quran → prayer) | Med–High |
| P5 | Native Kotlin restructuring — starts only after P0 tests, contracts `Verified`, device baseline recorded | Very high |
| P6 | Cleanup: `dhikl` → `dhikr`, dead code, RTL/theme helpers adoption, lints raised to warning, drift check | Low |

3. **Rollback procedure per phase** (not just `git revert`): state whether the phase touches persisted data
   (prefs, Firestore, scheduled alarms, widget state). Default rule: no phase changes persisted formats,
   so revert is data-safe; if a phase must, the spec includes a reversible migration and a post-revert check
   (app launches on old data, alarms rescheduled, widgets render, sync works).
4. `/egm:egm-review docs/designs/aura-refactor.md`, then `/egm:egm-resolve`. I approve. Log DECISION + ADR 0001.
5. P3 and P5 each get their own short spec `docs/designs/aura-refactor-pN-<name>.md`, reviewed with
   `/egm:egm-review` before coding. Others implement from the master spec.

## Step 5 — Implement Phase by Phase (Level C, per-phase approval)

- Start: `git status` + diff review; branch `refactor/pN-<name>`; read STATE + phase section + named modules only.
- Tests first for anything moved; then small commits (one screen/service per commit). Pure moves and logic changes never share a commit.
- After each commit: `flutter analyze` + `flutter test` (summary lines only) and `git diff --stat pubspec.lock` (must be empty).
- Device-dependent behavior stays `UNVERIFIED` until I run the relevant device-checklist items and confirm.
- End of phase: re-measure baseline, `/egm:egm-drift-report` on `docs/designs/` and modules, update contracts,
  STATE, project-log, `docs: log ...` commit. Ask before push/PR.

## Skill: project-log

Trigger after significant decisions, phase milestones, fixes, commits or pushes.
- Order: change → verify → code commit → log entry with that commit's hash + STATE/doc updates → `docs: log ...` commit.
  Never log a commit before its hash exists.
- Append to today's log only (don't read older logs); entry format (≤5 lines):
  `## HH:MM | DECISION/PLAN/CHANGE/FIX/COMMIT/PUSH` / `- What and why` / `- Files | Commit: hash | Ref: module/ADR/spec`.
- Update relevant modules/contracts/ADRs and INDEX when files change.
- First session of a month: summarize previous month into `log/archive/` (≤40 lines); keep raw logs.
- If the docs commit fails: leave doc changes uncommitted, report "pending documentation". Never amend/reset/rewrite.

## Skill: refactor-safety

Trigger for ANY move/rename/split of code, or edits touching prefs keys, channels, notification IDs,
intent extras, Firestore paths, log tags, or Kotlin files.
- Check `git status`; stop if target files have uncommitted user changes.
- Check `.project-docs/contracts/*`; a contract change updates Dart, Kotlin and the doc in one commit.
- Contract with confidence `Partial`/`Unknown` → verify it first or stop and ask.
- No file outside the phase boundary; if needed, stop and request a spec amendment.
- Keep public APIs via temporary shims until all callers migrate; remove shims in the phase's last commit.
- Report: files changed, analyze/test summary, device-checklist items affected, each labeled VERIFIED/UNVERIFIED/BLOCKED/UNKNOWN.

## Context Loading (goes into CLAUDE.md)

| Task | Required context |
| --- | --- |
| Prayer times / tracking | modules/prayer + contracts/prefs-keys |
| Notifications, adhan, alarms | modules/notifications-native + contracts/* |
| Tasks | modules/tasks |
| Quran / Wird | modules/quran-wird |
| Widgets | modules/widgets + contracts/method-channels + contracts/intent-extras |
| Auth / sync / Firestore | modules/auth-sync + contracts/firestore-paths |
| UI / theme / RTL | modules/ui-kit |
| Refactor phase work | STATE + spec phase section + modules it names |
| Architecture | relevant ADRs + relevant section of docs/designs/aura-refactor.md |

- Every session: read STATE.md first, nothing else by default. INDEX only when the table doesn't answer.
- Never read logs unless asked about a date. Never reread a file already in context unless changed.
- Broad exploration: Explore subagent; return conclusions and file paths only.
- Long EGM output goes to files, never dumped in chat; chat gets a short pointer.
- Concise responses; diffs/changed sections only; plans as bullets; reference doc paths, don't restate them.

## Step 6 — Bootstrap Completion Report

1. Verify: CLAUDE.md ≤80 lines, STATE ≤25, INDEX entries ≤120 chars, relocation table complete.
2. `flutter analyze` + `flutter test` summary; hook tested (no commits today → zero output; one unlogged code commit → reminder line).
3. `git status`: no secrets/paths/binaries; `pubspec.lock` unchanged.
4. Commits: `chore: lean docs system, contracts, EGM setup` then `docs: log bootstrap`; hook run again → zero output.
5. Report: files created, baseline metrics, contract confidence summary, device-checklist status,
   spec status, manual steps (`/reload-plugins`, record device baseline, review spec), recommended first phase.

Never skip a step silently. Report blockers and unverified items explicitly.

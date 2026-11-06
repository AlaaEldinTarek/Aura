---
name: project-log
description: Append an entry to today's project log (.project-docs/log/YYYY-MM-DD.md) and update STATE/docs. Use after significant decisions, phase milestones, fixes, commits or pushes.
---

# project-log

## Order
change → verify → code commit → log entry with that commit's hash + STATE/doc updates → `docs: log ...` commit.
Never log a commit before its hash exists.

## Entry
- Append to today's log only (`.project-docs/log/YYYY-MM-DD.md`, local date); don't read older logs.
- Format (≤5 lines):
  ```
  ## HH:MM | DECISION/PLAN/CHANGE/FIX/COMMIT/PUSH
  - What and why
  - Files | Commit: hash | Ref: module/ADR/spec
  ```

## Keep docs current
- Update relevant `.project-docs/modules/`, `contracts/`, `decisions/` (ADRs) and `INDEX.md` when files change.
- `STATE.md` holds current status only (≤25 lines), no history.
- First session of a month: summarize the previous month into `.project-docs/log/archive/YYYY-MM-summary.md`
  (≤40 lines); keep the raw logs.

## Failure
- If the docs commit fails: leave doc changes uncommitted and report "pending documentation".
  Never amend, reset or rewrite history.

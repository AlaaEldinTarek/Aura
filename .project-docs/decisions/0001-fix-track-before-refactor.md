# 0001 — Fix track before the refactor
Status: accepted (user, 2026-11-07)

## Context
The bootstrap (Steps 0–2.5, drift check) found CRITICAL and HIGH user-visible bugs (reference/findings.md, STATE fix
track). Refactor Steps 3–4 (architecture brainstorm, master spec) are behavior-preserving and would freeze these bugs.

## Decision
- Fix CRITICAL/HIGH first; refactor Steps 3–4 start after. Group order: FX-0 → "locale-dependent keys" →
  "sign-in & onboarding flow" → "Dart->native settings bridge" → FX-1 + remaining HIGH.
- Per group: short spec `docs/designs/fix-<name>.md` via `/egm:egm-draft` (user runs it) → `/egm:egm-review` →
  `/egm:egm-resolve` → user "approve phase <group>" (Level C) → tests first, then the fix on branch `fix/<group>` + PR.
- Each spec states the intended behavior change explicitly (the behavior-preserving rule applies to everything else).

## Consequences
- Master refactor spec moves to a later ADR number. MEDIUM/LOW items stay in the fix track until scheduled.
- Device scenarios that set a group's priority (S23–S28) should run before or during that group's spec.

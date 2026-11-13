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
- The spec states every behavior change. Phases P2, P3, P4a, P4b and P5 each need "approve phase PN" (Level C), and
  P6 is docs (Level A), on branch `feat/wird-marker`, one PR. ADR 0001's workflow applies unchanged:
  `/egm:egm-draft` → `/egm:egm-review` → `/egm:egm-resolve` → approval → tests first.
- Open fixes in this code keep their order: F38d before the marker, F38b after it.

## Consequences
- Remaining HIGH fixes and the master refactor spec move behind this feature. ADR 0001 is not edited.
- Contracts change in the same commits as the code: `firestore-paths.md` and `prefs-keys.md` in P3 (the marker path
  and keys) and `prefs-keys.md` again in P4b (the `wird_total_pages_read` note).
- Until the marker ships, no other change touches the Wird link code (Wird-tab auto-sync, bookmark sync).

# Stage 8: Intermediate Zoom Out — fix-quran-khatma-wird.md (full file)

Reviewer: egm-zoom-out, given the Stage 5–7 reports. Verdict: passes on root problem, scope and reuse; Majors on altitude and one on simplicity. Callers table and F38c description re-confirmed against code.

## Do the Stage 6–7 mitigations push the design out of scope or altitude?
Partly. Most are documentation of existing facts. Four need a decision before finalizing.

## Decisions needed (design surface)
1. **Same-color-linked branch (D1).** `existing ∪ S` marks other unsynced bookmarks of that color as counted without reading them; "intentional" is argued only for first link. Alternative: `existing ∪ {P}`. Decide first; it determines the helper's inputs. Add a CUJ for another unsynced bookmark of that color.
2. **Race / unawaited writes (Z4, C2, D2).** Await `recordPagesRead` then `setLinkedBookmarkColor` in order (two lines, same branch). A service-level merge would fix it more fully but contradicts "call site only"; state that trade-off in Alternatives. The Non-Goal deferring this conflicts with the exact-value CUJs 3–5.
3. **Helper (Z1).** Four-parameter wrapper around one conditional; new `@visibleForTesting` pattern. Inline it, or drop the annotation and test via the service. Do not fix a signature until item 1 is decided.
4. **Juz mode-switch case (D4, T3).** Page-mode linked color stays set after switching to juz mode; juz "Choose One" merges only the chosen page, so other pages of that color look new. Do not expand scope: reword the "not affected" claim to "never-linked state" and add a Non-Goal marked UNVERIFIED.

## Document changes (cheap, no scope growth)
- Add a short Risks & Mitigations section, one line each: race; confirm dialog on X; X-tap re-entrancy while dialog open; `'no'` path `nav.pop()` after await with no `mounted` check (pre-existing); inflated data left in place.
- Rewrite Alternatives rationales as concrete trade-offs (A's real cost: "Use all" semantics on stale pages would change if the service merged). Add two missing alternatives: merge-only service method; skip `recordPagesRead` and let sync count the page. Cite `CLAUDE.md`, not "refactor rules".
- Trim the Detailed Plan to intent and interfaces; keep one copy of the data-flow diagram; drop line numbers in doc-update targets.
- Add one background paragraph and a one-line definition of `countedBookmarkPages` ("pages the sync should ignore" vs "pages that added progress"; the plan makes it "ignore"). Do not write out auto-sync internals; link `.project-docs/modules/wird.md`.
- Record Flutter 3.38.7 as the basis for the `maybePop`→`PopScope` claim; keep S45 as proof. No widget test needed.
- Mark "same as back" as Decided (Goals and CUJ 2 already assume it); mark the double-add guard as deferred.
- Polish: rename sections to the standard, promote "Additional Resources" to H2, H3 for pseudo-headings, fix terminology drift, label the negative-control test, exact set in CUJ 4, gloss Level A/C and S45/S46, drop "small".

## Do not add
A baseline field or per-color map (keep as a one-line known limit: switching color and back re-counts); repair of inflated progress (already a Non-Goal); PopScope handler refactor (Alt C); reproduction-step expansion (D11).

## Reuse check
`maybePop` reuses the Esc path; no new service. Only new component is the single-use helper (item 3).

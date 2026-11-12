# Stage 5: Zoom Out + Inventive Catalyst — fix-quran-khatma-wird.md

Reviewers: egm-zoom-out, egm-inventive-catalyst. Both checked the cited code against the design; the F38a/F38c descriptions hold. No Blockers.
Reviewer limits: zoom-out did not read `wird.md`, full `wird_tab.dart`/`wird_service.dart`, or check cites `:147-189`, `:1049`, `:1368`, `wird_provider.dart:161`. Catalyst did not open `quran_reader_screen.dart` or `wird.md` (F38a rests on the design's cites).

## Zoom-out findings
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| Z1 | Major | Technical Plan F38c; file #2 | Helper `countedPagesAfterChooseOne` (4 params) wraps one conditional. `@visibleForTesting` appears once in `lib/` (new pattern). Service-level tests already cover the regression. Suggest inlining, or shrink the helper's inputs. |
| Z2 | Major | Impl. Plan files #2, #3, second diagram | Code-level detail (signature, exact `ref.read` expression, null handling, line-based edits). Trim to intent. |
| Z3 | Major | Alternative A, callers table | Call-site fix keeps a replace-contract footgun in the service. Rationale "smaller change" is thin; state the tradeoff (e.g. "Use all" semantics on stale pages would change if the service merged). |
| Z4 | Major | Non-Goals (unawaited writes) | The fix keeps two fire-and-forget read-modify-write calls (`wird_tab.dart:649-650`); CUJ 3–5 assert exact values, so a lost update breaks them. Await both (same two lines) or justify why the race cannot affect CUJ 3–5. |
| Z5 | Nit | Open Questions | Choose One on an already-counted page double-adds. A one-line guard is cheap. |
| Z6 | Nit | Open Questions | "Confirm dialog on every close" is an unapproved UX change left open while Goals assume it. Resolve before implementation. |
| Z7 | Nit | Files #4–#7 | Line numbers in doc-update targets will drift; drop them. |
| Z8 | Nit | Verification Plan | Close-button fix has no automated test and is the higher-risk fix; device check S45 not yet run (honestly flagged). |

## Inventive-catalyst findings
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| C1 | Major | Technical Plan F38c | `countedBookmarkPages` now also means "bookmarked but deliberately not counted". Consequences: switching color and back re-counts everything (set discarded on color change); the set cannot say which pages were really counted; delete-then-re-add of a bookmark is silently ignored (existing behavior). Resolution: keep as is, name a separate baseline field / per-color map as a follow-up, record the switch-back re-count as a known limit. |
| C2 | Nit (borderline Major) | Technical Plan F38c; Non-Goal on unawaited writes | Merge uses the provider snapshot, not persisted settings. An auto-sync firing between the read and the write can make the replace overwrite a newer set (matters in CUJ 4). Unloaded state silently falls back to replace. Resolution: a service method doing read+union+write in one call (contradicts "call site only"), or await the two notifier calls in order. |
| C3 | Nit | Open Questions | Duplicate-page guard (same as Z5). |
| C4 | Nit | Verification Plan | Label the negative-control test as pinning old behavior. |
| C5 | Nit | CUJ 3 | State that the sheet's `bookmarks` list and "Use all" `allPages` (`:1368`) come from the same filtered source. |

## Positives (both reviewers)
`maybePop` reuses the existing Esc path; removing the sidebar line from the button is well reasoned; Non-Goals are tight; UNVERIFIED/UNKNOWN markers are honest; no data-format or native changes.

## Overlap
Z4 and C2 are the same risk (unawaited concurrent writes). Z5 and C3 are the same nit.

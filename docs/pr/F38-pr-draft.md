# F38: Quran close button and Wird "Choose One"

F38a (reader close button) and F38c (Wird "Choose One") are fixed and device-verified; see the evidence in section 3. Branch `fix/quran-khatma-wird`. Design: `docs/designs/fix-quran-khatma-wird.md` (Approved).

## 1. What changed in code

Four code commits (`5dd30d0`, `98c637a`, `95f79d2`, `8911357`) touch code, tests or translations; the rest of the branch is docs (design, reviews, module docs, STATE, findings, log, device checklist). The five non-docs files changed against `main` are `lib/features/quran/wird_tab.dart`, `lib/features/quran/quran_reader_screen.dart`, `test/features/quran/wird_choose_one_test.dart`, `assets/translations/en.json` and `assets/translations/ar.json`. The other 17 changed files are documentation, including `lib/features/quran/README.md`, `.project-docs/` and `docs/`. Check with `git diff --name-only main..HEAD -- lib test assets pubspec.yaml pubspec.lock`.

*   **Phase 1, helper and unit tests (`5dd30d0`).** `countedPagesAfterChooseOne` in `lib/features/quran/wird_tab.dart` (+24, `@visibleForTesting`) and `test/features/quran/wird_choose_one_test.dart` (new, 12 tests: helper cases 1-7, 2 invariants, 1 negative control, 2 service-level).
*   **Phase 2, Choose One call site and string (`98c637a`, `95f79d2`).**
    *   `98c637a`: page-mode "Choose One" now links the color with the full set of its pages (so only later bookmarks auto-count) and records exactly one page; the link is awaited before the page is recorded. Choosing a page that is already counted for the same linked color shows the new snackbar and changes nothing. New key `wird_bookmark_already_counted` in `en.json` and `ar.json`. The juz branch is unchanged.
    *   `95f79d2`: clears two analyzer infos introduced by `98c637a` (uses `this.context` after the `mounted` check).
*   **Phase 3, close button (`8911357`).** The reader's top-bar close button calls `Navigator.of(context).maybePop()` instead of `Navigator.pop`, so it runs the `PopScope` handler like system back and Esc. Behavior change: the close button now shows "Close Reader?" on non-604 pages, and on page 604 in page mode with today's wird not done it shows the khatma prompt.
*   **Phase 4, docs (`c7bc1da`).** `.project-docs/modules/quran-wird.md`, `.project-docs/modules/wird.md` and `lib/features/quran/README.md` describe the `maybePop` close button and the new Choose One rule.
*   **Phase 5, records.** F38a and F38c are marked fixed in `STATE.md` and `.project-docs/reference/findings.md`; the device results are in `.project-docs/reference/device-checklist.md` and the 2026-11-12 and 2026-11-13 logs.

## 2. Tests

*   `flutter test`: 272 pass (baseline 260, +12 new tests), as of phase 3.
*   `flutter analyze`: 419 issues, unchanged from the baseline, as of phase 3.
*   `wird_tab.dart` already failed `dart format` before this branch; it was not reformatted.

## 3. Device verified

*   **S46 old-model pass, 2026-11-12, build `7e9ad44`, nova 5T.** Swapped-color run covering the phase 2 Choose One path. Green p137 gave 1/5; added green p181, 2/5; linked red via p102, 3/5; re-linked green via p188, 4/5; the already-counted green p137 showed "This page was already added" and stayed at 4/5. The run started 0/5 after a reset, which the design's S46 precondition says not to use; it is recorded as logged. `5dd30d0`, `98c637a` and `95f79d2` are ancestors of `7e9ad44`; it predates phase 3.
*   **S45 steps a-d, 2026-11-12, build `96e3eee`: pass.** a-c on the nova 5T, d on Windows: "Close Reader?" appeared; "Keep Reading" kept the reader open; "Close" closed it with nothing recorded; the desktop sidebar was hidden after "Keep Reading" and visible after "Close". S45 steps a-c show `maybePop` reaches the `PopScope` handler (the "Close Reader?" dialog appears), per the design.
*   **S45 step e, 2026-11-13, nova 5T: pass.** On page 604 with today's wird not done (0/5), the close button showed the khatma prompt, and "Not Yet" recorded nothing. Build `96e3eee` (inferred: the khatma prompt appeared on close, which only phase 3 code does; the build was not stated).
*   **Arabic wording** of "This page was already added" (`تمت إضافة هذه الصفحة بالفعل`): reviewed by the product owner (native Arabic speaker) on 2026-11-13.

## Known limits (from the design)

Not fixed here: overlapping or stale syncs can still re-count or lose a page, a sync can revert the color link, "Use all" re-counts an already-counted color, and a repeated close tap has no device check (accepted risk). Progress already inflated by F38c is not repaired. The S46 pass covers the current color model only, not the future reserved-color design (not part of this PR).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

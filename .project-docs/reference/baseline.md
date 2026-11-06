# Baseline — 2026-11-06 (commit 75d38b9, Flutter 3.38.7 / Dart 3.10.7)
Review signals, not targets. Re-measured each phase. File-size/hotspot metrics are added in Step 2.

## Analyzer (`dart analyze --format=machine`, re-run 2026-11-06: total 425 confirmed)
- Total 425 = INFO 330 + WARNING 95 + ERROR 0
- By type: HINT 220, LINT 110, STATIC_WARNING 95
- Lints: default `flutter_lints` only (`analysis_options.yaml`, no excludes)

| Count | Sev | Code |
| --- | --- | --- |
| 220 | INFO | deprecated_member_use (withOpacity 189, groupValue 7, onChanged 7, scale 6, activeColor 5, translate 4, onPopInvoked 1, textScaleFactor 1) |
| 52 | INFO | prefer_const_constructors |
| 24 | WARN | unused_import |
| 19 | INFO | use_build_context_synchronously |
| 19 | WARN | unused_local_variable |
| 16 | WARN | unused_element |
| 10 | INFO | curly_braces_in_flow_control_structures |
| 7 | INFO | prefer_const_declarations |
| 7 | WARN | unused_catch_stack |
| 6 | WARN | invalid_null_aware_operator |
| 6 | WARN | unnecessary_non_null_assertion |
| 4 each | INFO/WARN | unnecessary_to_list_in_spreads, await_only_futures, unused_field, unnecessary_null_comparison |
| 3 each | | unused_element_parameter, no_leading_underscores_for_local_identifiers, dead_null_aware_expression, prefer_interpolation_to_compose_strings |
| 2 each | | unused_shown_name, unnecessary_string_interpolations |
| 1 each | | unnecessary_overrides, unnecessary_brace_in_string_interps, prefer_if_null_operators, prefer_final_fields, depend_on_referenced_packages, equal_keys_in_map, unnecessary_this |

## By area (top 15)
lib/core/widgets 79, features/settings 42, features/onboarding 39, features/tasks 39, features/home 33,
features/prayer 33, features/quran 32, features/profile 20, features/main 19, core/services 16,
core/providers 15, lib/main.dart 13, features/azkar 13, features/dhikl 10, features/achievements 7

## Tests
- 64 pass / 0 fail (Step 0 run). Test files: 5 (initial survey).

## Counts
- Routes 25 · Kotlin files 30 · MethodChannels 8 (Kotlin) · translation top-level keys en 450 / ar 450

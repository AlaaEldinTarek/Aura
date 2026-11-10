# PR — Fix Dart→native settings bridge

## Summary
- **F15**: All Dart senders use `nativePrayerKey()` (maps zuhr→dhuhr); scan test prevents regression
- **F49a + F49h**: Silent-mode toggle and toggle-receiver language read from `FlutterSharedPreferences` via `FlutterPrefs`
- **F49b**: Reciter resolved at play time from `flutter.selected_adhan_id` + `AdhanFiles.resolve()`; preview no longer changes the live adhan; old `setCustomAdhan`/`getCustomAdhan`/`setAdhanEnabled`/`isAdhanEnabled` channel methods removed
- **F51i + F49i**: Boot, daily-recalc, and swipe-away restart gated by `flutter.background_notification_enabled` via `startServiceIfAllowed`; START_STICKY null-intent also checks; dead `aura_prefs.notifications_enabled` boot check removed
- `adhan_enabled` duplication removed (one copy in `FlutterSharedPreferences`, no `aura_prefs` duplicate)

## Commits
1. `92b9f71` Use one native key rule for Zuhr in all Dart senders (F15)
2. `fec8f32` Read the silent-mode setting from Flutter prefs (F49a, F49h)
3. `b0821b2` Read adhan settings from Flutter prefs and add reciter preview
4. `990c71d` Gate service restarts on background-notification setting (F51i, F49i)
5. (this commit) Docs: device checklist S42/S43, findings, modules, STATE, PR description

## Test plan
- [ ] `flutter test` — all pass (new: `native_keys_scan_test`, `prayer_time_rules_native_key_test`, `prayer_widget_service_native_keys_test`, `adhan_player_service_test`, `adhan_catalog_test`)
- [ ] `flutter analyze` — 0 new issues
- [ ] `./gradlew :app:testDebugUnitTest` — all pass (new: `AdhanFilesTest`, `ForegroundAutoStartTest`, `NativePrefsContractTest`)
- [ ] Static search: no `setAdhanEnabled`, `isAdhanEnabled`, `setCustomAdhan`, `getCustomAdhan` in `lib/` or `android/app/src/main/kotlin/`
- [ ] Release APK build
- [ ] Device S25 (silent mode off honored at adhan)
- [ ] Device S26 (reciter survives app kill; preview doesn't change live adhan)
- [ ] Device S42 (service restarts honor background-notification setting)
- [ ] Device S43 (update-in-place from main: all settings bridge correctly, dhuhr_time in logs)

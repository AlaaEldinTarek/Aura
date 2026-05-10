# Aura App — Desktop Version Plan

**Created**: 2026-05-08
**Target**: Windows Desktop (primary), macOS/Linux later
**Strategy**: Same Flutter codebase, platform-aware guards around all Android-only code

---

## Overview

Flutter's UI framework runs natively on Windows. The main work is:
1. Guard / stub all 7 Kotlin MethodChannels so the app launches on desktop
2. Replace Android-only features with cross-platform equivalents
3. Adapt the UI layout for wider screens (sidebar nav, two-column layouts)
4. Add desktop-specific integration (system tray, window management, autostart)

---

## Phase 1 — Enable Windows & Get App Launching ✅ DONE

- [x] 1. Run `flutter create --platforms=windows .` to add Windows support to the project
- [x] 2. Add `Platform.isAndroid` guards to all MethodChannel service files:
  - `adhan_player_service.dart` ✅
  - `prayer_alarm_service.dart` ✅
  - `background_service_manager.dart` ✅
  - `silent_mode_service.dart` ✅
  - `platform_channel_service.dart` ✅
  - `main_wrapper_screen.dart` navigation channel ✅
- [x] 3. Firebase Windows config added to `firebase_options.dart`
- [x] 4. Google Sign-In hidden on desktop (login + signup screens)
- [x] 5. Fixed LateInitializationError on MethodChannel fields
- [x] 6. App launches on Windows ✅
- [x] 7. All screens navigable without crash ✅

---

## Phase 2 — Prayer Times Core (Desktop)

- [x] 1. Manual location input: `DesktopLocationDialog` — city search (OpenStreetMap Nominatim), auto-detect (IP), manual lat/lon entry; tappable location header on Prayer screen
- [x] 2. IP-based geolocation fallback using `dio` — `_getIpLocation()` in `LocationService`, called automatically on desktop when no manual location is saved
- [x] 3. Prayer times calculation — pure Dart `adhan` library, works on Windows unchanged ✅
- [x] 4. Adhan audio on desktop — `DesktopAdhanService` uses `audioplayers`, already implemented ✅
- [x] 5. Prayer notifications on Windows: `local_notifier` package — `DesktopNotificationService` for pre-prayer reminders, prayer-time toasts, post-prayer checks, achievements, tasks, Wird
- [x] 6. Prayer alarm scheduling on desktop: `DesktopPrayerScheduler` timer-based — pre-prayer reminder (configurable minutes), adhan + notification at prayer time, post-prayer check 30 min/1 h after
- [x] 7. Prayer tracking (Done/Late/Missed) — SharedPreferences works on Windows, tracking flow unchanged ✅

---

## Phase 3 — UI / UX Adaptation for Desktop 🔄 IN PROGRESS

- [x] 1. `_DesktopShell` wrapper with sidebar navigation replacing BottomNavigationBar
- [x] 2. Sidebar: 220px, logo, filled/outline icon toggle, active indicator bar
- [x] 3. Content area fills full window width (removed mobile maxWidth cap on desktop)
- [x] 4. Text scale 1.8× on desktop content so cards are taller and readable
- [x] 7. Quran reader: keyboard Left/Right arrow navigation, Escape to close
- [x] 8. Tasks screen: wider card layout (2-column grid on desktop)
- [x] 9. Dhikr counter: Space key = tap (desktop only, `Focus` widget with `onKeyEvent`)

---

## Phase 4 — Quran & Azkar on Desktop ✅ DONE

- [x] 1. Quran SVG pages: path_provider + dio both support Windows; cache at getApplicationDocumentsDirectory()/quran_pages/ ✅
- [x] 2. Quran reader keyboard shortcuts: Left/Right page nav, Escape close (done in Phase 3) ✅
- [x] 3. Morning/Evening Azkar: 2-column grid on desktop; haptic silently fails on desktop ✅
- [x] 4. Wird (daily reading commitment): SharedPreferences-based, works unchanged ✅
- [x] 5. Islamic Events: 2-column grid on desktop; pure Dart Hijri calculation unchanged ✅

---

## Phase 5 — System Tray & Window Management ✅ DONE

- [x] 1. `tray_manager` package added; tray icon = `app_icon.ico` (bundled as Flutter asset) ✅
- [x] 2. System tray menu: Next Prayer + time (updates every minute), Open Aura, Quit ✅
- [x] 3. `window_manager` setPreventClose + WindowListener: close button hides to tray; left-click restores ✅
- [x] 4. Prayer-time toast notifications: handled by `DesktopNotificationService` (local_notifier) ✅
- [ ] 5. Windows startup option (Settings toggle): write registry key `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- [ ] 6. Add desktop entry point screen for first-run: location setup + method selection

---

## Phase 6 — Sync & Auth on Desktop ✅ DONE

- [x] 1. Firebase Auth works on Windows — login/signup flow functional ✅
- [x] 2. Cloud Firestore works on Windows — task sync, prayer records, bookmarks ✅
- [x] 3. Google Sign-In hidden on desktop (login + signup screens) — done in Phase 1 ✅
- [x] 4. Guest mode: SharedPreferences-based, works unchanged ✅
- [x] 5. Offline queue: works unchanged ✅

---

## Phase 7 — Build & Release (Windows) ✅ DONE

- [x] 1. `flutter build windows --release` — working ✅
- [x] 2. `msix: ^3.16.0` added to dev_dependencies; build via `dart run msix:create` ✅
- [x] 3. `msix_config` configured: display_name, publisher, identity_name=com.aura.hala, version 1.0.0.4, logo, capabilities, install_certificate: false ✅
- [x] 4. `Aura_v1.0.0.msix` (33.5 MB) created and ready ✅
- [ ] 5. Optionally: submit to Microsoft Store

---

## Features Available on Desktop vs Android

| Feature | Android | Desktop |
|---------|---------|---------|
| Prayer times calculation | ✅ | ✅ |
| Adhan audio | ✅ Native | ✅ audioplayers |
| Prayer notifications | ✅ AlarmManager | ✅ flutter_local_notifications |
| Full-screen adhan activity | ✅ | ❌ (not applicable) |
| Post-prayer azkar screen | ✅ | ✅ (in-app, no alarm) |
| Silent mode automation | ✅ | ❌ (Windows only silences app) |
| Foreground service | ✅ | ❌ (system tray instead) |
| Qibla compass | ✅ | ❌ (no magnetometer) |
| Widgets (home screen) | ✅ | ❌ (system tray instead) |
| Focus mode lockdown | ✅ | ❌ (timer only, no lockdown) |
| Quran reader | ✅ | ✅ |
| Azkar checklist | ✅ | ✅ |
| Wird tracker | ✅ | ✅ |
| Islamic events countdown | ✅ | ✅ |
| Task management | ✅ | ✅ |
| Achievements | ✅ | ✅ |
| Dhikr counter | ✅ | ✅ |
| Firebase auth (email) | ✅ | ✅ |
| Google Sign-In | ✅ | ❌ |
| Firestore sync | ✅ | ✅ |
| System tray | ❌ | ✅ |
| Windows startup | ❌ | ✅ |

---

## Overall Progress

| # | Phase | Status |
|---|-------|--------|
| 1 | Enable Windows & app launches | ✅ Done |
| 2 | Prayer times core on desktop | ✅ Done |
| 3 | UI/UX adaptation for desktop | 🔄 In progress (6/10 done) |
| 4 | Quran & Azkar on desktop | ✅ Done |
| 5 | System tray & window management | ✅ Done |
| 6 | Sync & Auth on desktop | ✅ Done |
| 7 | Build & release (Windows) | ✅ Done |

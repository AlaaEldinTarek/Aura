# Aura App — Interactive Tutorial Walkthrough Plan

**Created**: 2026-05-07
**Total steps**: 8
**Scope**: Step-by-step guided tutorial with highlighted overlays, Next/Skip buttons, replay from Profile

---

## Feature Description
An interactive walkthrough that runs on first launch after install. Highlights UI elements with a dark overlay and cutout, shows explanation text with "Next" / "Skip" buttons. User can replay from Profile settings.

---

## Step-by-step Plan

### Step 1: Remove FirstTimeBanner (replaced by tutorial)
- [ ] Remove FirstTimeBanner from Home, Prayer, Quran, Tasks screens
- [ ] Delete `lib/core/widgets/first_time_banner.dart`
- [ ] Keep InfoTipIcon widgets (still useful for quick reference)
- **Files**: `home_screen.dart`, `prayer_screen.dart`, `quran_screen.dart`, `tasks_screen.dart`, `first_time_banner.dart`

### Step 2: Add tutorial SharedPreferences keys
- [ ] Add `keyTutorialCompleted` to AppConstants
- [ ] Add `isTutorialCompleted()` / `setTutorialCompleted()` to SharedPreferencesService
- **Files**: `app_constants.dart`, `shared_preferences_service.dart`

### Step 3: Add translation keys for tutorial
- [ ] Add ~20 keys (`tutorial_*`) to `en.json` and `ar.json`
- Each step has: title, body text
- Plus: Next, Skip, Done, step counter text
- **Files**: `assets/translations/en.json`, `assets/translations/ar.json`

### Step 4: Create TutorialOverlay widget
- [ ] Full-screen dark overlay with transparent cutout around target widget
- [ ] Tooltip bubble with title, description, step counter, Next/Skip/Done buttons
- [ ] Animated transition between steps (slide/fade)
- [ ] Theme-aware, RTL-aware
- **File**: `lib/core/widgets/tutorial_overlay.dart` (new)

### Step 5: Create TutorialStep model and TutorialController
- [ ] `TutorialStep` class: targetKey (GlobalKey), titleKey, bodyKey, alignment (top/bottom)
- [ ] `TutorialController` manages step list, current index, show/hide state
- [ ] Uses OverlayEntry to insert/remove the tutorial overlay
- **File**: `lib/core/widgets/tutorial_controller.dart` (new)

### Step 6: Add GlobalKeys to Home screen sections
- [ ] Add GlobalKeys to: Greeting, Daily Content card, Prayer Progress, Task Progress, Today's Tasks
- [ ] Define tutorial steps for Home screen
- [ ] Trigger tutorial on first build if not completed
- **File**: `lib/features/home/home_screen.dart`

### Step 7: Add "Restart Tutorial" to Profile screen
- [ ] Add a "Show Tutorial" or "App Tour" button in Profile settings section
- [ ] On tap: clears `keyTutorialCompleted` flag and restarts tutorial
- **File**: `lib/features/profile/profile_screen.dart`

### Step 8: Build, test, install APK
- [ ] Build release APK
- [ ] Install on device
- [ ] Update plan with ✅

---

## Tutorial Steps (Home Screen — 6 steps)

| # | Target | Title EN | Body EN |
|---|--------|----------|---------|
| 1 | Greeting | Welcome! | Your personalized daily dashboard starts here. |
| 2 | Daily Content card | Daily Inspiration | A new Quran verse, Hadith, or Dua every day. Tap to read more. |
| 3 | Next Prayer card | Next Prayer | Shows your upcoming prayer with a countdown timer. Tap to go to Prayer Times. |
| 4 | Prayer Progress | Prayer Tracker | Tap any circle to mark your prayer as On Time, Late, or Missed. |
| 5 | Task Progress | Task Progress | See how many of today's tasks you've completed at a glance. |
| 6 | Today's Tasks | Today's Tasks | Preview of your pending tasks. Tap "See All" to go to the full Tasks screen. |

---

## Progress Log

| Step | Description | Status | Session |
|------|-------------|--------|---------|
| 1 | Remove FirstTimeBanner | ✅ done | session-1 |
| 2 | Tutorial SharedPreferences keys | ✅ done | session-1 |
| 3 | Translation keys (en + ar) | ✅ done | session-1 |
| 4 | TutorialOverlay widget | ✅ done | session-1 |
| 5 | TutorialStep model + TutorialController | ✅ done | session-1 (inline in tutorial_overlay.dart) |
| 6 | Home screen GlobalKeys + steps | ✅ done | session-2 |
| 7 | Profile restart tutorial button | ✅ done | session-2 |
| 8 | Build, test, install | ✅ done | session-2 |

## Token Budget Rule
Before each step, estimate remaining context. If < 8,000 tokens estimated, STOP and record resume point.

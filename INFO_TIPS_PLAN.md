# Aura App — Info Tips Feature Plan

**Created**: 2026-05-07
**Total steps**: 7
**Scope**: Info icon tooltips + first-time banners on Home, Prayer, Quran, Tasks screens

---

## Step-by-step Plan

### Step 1: Add SharedPreferences keys to AppConstants
- [x] Add 4 banner keys: `keyBannerHomeSeen`, `keyBannerPrayerSeen`, `keyBannerQuranSeen`, `keyBannerTasksSeen`
- **File**: `lib/core/constants/app_constants.dart`

### Step 2: Add helper methods to SharedPreferencesService
- [x] Add `hasSeenBanner(String screenKey)` and `markBannerSeen(String screenKey)` methods
- **File**: `lib/core/services/shared_preferences_service.dart`

### Step 3: Add translation keys to both JSON files
- [x] Add ~22 keys (`info_tip_*` and `banner_*`) to `en.json`
- [x] Add matching Arabic translations to `ar.json`
- **Files**: `assets/translations/en.json`, `assets/translations/ar.json`

### Step 4: Create `InfoTipIcon` widget
- [x] Stateless widget: ℹ️ icon → tap shows AlertDialog with title + body from translation keys
- [x] Theme-aware (light/dark), uses AppConstants colors
- **File**: `lib/core/widgets/info_tip_icon.dart` (new)

### Step 5: Create `FirstTimeBanner` widget
- [x] ConsumerStatefulWidget: colored top banner with dismiss X + "Got it" button
- [x] Checks SharedPreferences on init, returns SizedBox.shrink() if already seen
- [x] AnimatedSize dismiss animation
- **File**: `lib/core/widgets/first_time_banner.dart` (new)

### Step 6: Integrate FirstTimeBanner into all 4 screens
- [x] Home screen — first child in scroll Column
- [x] Prayer screen — inside SingleChildScrollView Column
- [x] Quran screen — above TabBarView in Scaffold body
- [x] Tasks screen — first SliverToBoxAdapter in CustomScrollView
- **Files**: `home_screen.dart`, `prayer_screen.dart`, `quran_screen.dart`, `tasks_screen.dart`

### Step 7: Add InfoTipIcon to section headers
- [x] Home — Prayer Progress bar title (line ~623)
- [x] Home — Task Progress ring title (line ~793)
- [x] Home — Today's Tasks title (line ~895)
- [x] Home — Daily Content card header
- [x] Prayer — Prayers List header
- [x] Prayer — Muslim Toolkit header
- **Files**: `home_screen.dart`, `prayer_screen.dart`

---

## Which Sections Get What

| Screen / Section | Banner | Info Icon |
|---|---|---|
| Home screen | Yes | Yes (4 icons: daily content, prayer progress, task progress, today's tasks) |
| Prayer screen | Yes | Yes (2 icons: prayers list, muslim toolkit) |
| Quran screen | Yes | No (tabs are self-explanatory) |
| Tasks screen | Yes | No (section labels are self-explanatory) |

---

## Translation Keys (~22 total)

### Info Tip Keys
- `info_tip_daily_content_title/body` — Verse / Hadith of the Day
- `info_tip_prayer_progress_title/body` — Prayer Progress tracker circles
- `info_tip_task_progress_title/body` — Task Progress ring
- `info_tip_today_tasks_title/body` — Today's Tasks preview
- `info_tip_prayer_cards_title/body` — Prayer Tracking (mark each prayer)
- `info_tip_muslim_toolkit_title/body` — Quick actions (Qibla, Azkar, Report)

### Banner Keys
- `banner_home_title/body` — Welcome to Aura!
- `banner_prayer_title/body` — Prayer Times overview
- `banner_quran_title/body` — Quran reading & Wird
- `banner_tasks_title/body` — Task management overview
- `banner_got_it` — Got it button text

---

## Progress Log

| Step | Description | Status | Session |
|------|-------------|--------|---------|
| 1 | AppConstants keys | ✅ done | session-1 |
| 2 | SharedPreferencesService methods | ✅ done | session-1 |
| 3 | Translation keys (en + ar) | ✅ done | session-1 |
| 4 | InfoTipIcon widget | ✅ done | session-1 |
| 5 | FirstTimeBanner widget | ✅ done | session-1 |
| 6 | Integrate banners (4 screens) | ✅ done | session-1 |
| 7 | Add info icons to section headers | ✅ done | session-1 |

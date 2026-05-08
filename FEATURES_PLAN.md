# Aura App — New Features Plan

**Created**: 2026-05-08
**Features**: 5 new features planned for upcoming sessions

---

## Feature 1: Morning & Evening Azkar Checklist

**Description**: Daily checklist of prophetic morning/evening remembrances (أذكار الصباح والمساء). Progress ring per session. Resets at Fajr (morning) and Maghrib (evening). Tied into achievements.

### Steps
- [x] 1. Add `Zikr` model: id, textAr, textEn, count (repetitions required), category (morning/evening)
- [x] 2. Add azkar data list (12 morning, 12 evening) as a Dart constant in `lib/core/models/azkar.dart`
- [x] 3. Add SharedPreferences persistence for daily azkar progress (date-keyed JSON in `azkar_provider.dart`)
- [x] 4. Add `azkarProvider` (StateNotifier) — tracks completed items, streak, resets on new day
- [x] 5. Create `AzkarScreen` with two tabs (Morning / Evening), progress ring at top, list of items
- [x] 6. Each item: Arabic text (Cairo font), translation, repeat count badge, animated checkbox, haptic feedback
- [x] 7. Add 3 azkar achievements (`azkar_first`, `azkar_full_day`, `azkar_streak_7`) to `achievement.dart`
- [x] 8. Add route `/azkar` in `main.dart`; Azkar button added to Muslim Toolkit in prayer_screen
- [x] 9. Add translation keys to en.json + ar.json
- [x] 10. Build, test, install APK ✅

---

## Feature 2: Qada Prayer Tracker

**Description**: Track missed prayers that need to be made up. User sets how many they owe per prayer, logs completions, sees running debt counter decrease over time.

### Steps
- [ ] 1. Add `QadaRecord` model: prayerName, owedCount, completedCount, lastUpdated
- [ ] 2. Add SharedPreferences persistence + Firestore sync for logged-in users
- [ ] 3. Create `qadaProvider` (StateNotifier) — CRUD for each of the 5 prayers
- [ ] 4. Create `QadaScreen`: list of 5 prayers, each showing owed/completed counts
- [ ] 5. "Add debt" button per prayer (+ dialog to enter number)
- [ ] 6. "Mark as done" button per prayer (decrements owed, increments completed)
- [ ] 7. Progress bar per prayer showing how much has been made up
- [ ] 8. Total remaining badge on screen header
- [ ] 9. Add route `/qada` and entry point (Prayer screen quick actions or profile)
- [ ] 10. Add translation keys to en.json + ar.json
- [ ] 11. Build, test, install APK

---

## Feature 3: Islamic Events Countdown

**Description**: Key Islamic dates auto-calculated from Hijri calendar. Countdown card on home screen for the next upcoming event. Full events list screen.

### Steps
- [x] 1. Create `IslamicEvent` model: nameEn, nameAr, hijriMonth, hijriDay, description
- [x] 2. Define events list: Ramadan, Eid al-Fitr, Eid al-Adha, Laylat al-Qadr, Ashura, Mawlid, first 10 days Dhul Hijjah, Islamic New Year
- [x] 3. Add `IslamicEventsService`: forward-scan HijriDate utility to find next Gregorian occurrence
- [x] 4. Add `islamicEventsProvider` (Provider) — list sorted by days until
- [x] 5. Create `IslamicEventsScreen`: full list with countdown badges, Hijri date, description
- [x] 6. Add countdown card to Home screen (between Daily Content and Next Prayer, only shows when event is within 30 days)
- [x] 7. Add route `/islamic_events`
- [x] 8. Add translation keys to en.json + ar.json
- [x] 9. Build, test, install APK ✅

---

## Feature 4: Sadaqa / Charity Goal Tracker

**Description**: Set a monthly charity goal, log individual donations, see progress ring. Simple spiritual productivity tracker.

### Steps
- [ ] 1. Add `SadaqaEntry` model: amount, currency, note, date
- [ ] 2. Add `SadaqaSettings` model: monthlyGoal, currency (SAR/USD/EGP/etc.)
- [ ] 3. Add SharedPreferences persistence + Firestore sync
- [ ] 4. Create `sadaqaProvider` (StateNotifier) — monthly entries, goal, total
- [ ] 5. Create `SadaqaScreen`: progress ring (donated/goal), monthly total, list of entries
- [ ] 6. "Add donation" FAB — bottom sheet with amount, note, date fields
- [ ] 7. Currency selector (common Islamic currencies: SAR, USD, EGP, AED, GBP)
- [ ] 8. Month/year navigation to view past months
- [ ] 9. Add sadaqa achievements (first donation, goal reached, consistent giver)
- [ ] 10. Add route `/sadaqa` and entry point
- [ ] 11. Add translation keys to en.json + ar.json
- [ ] 12. Build, test, install APK

---

## Feature 5: Quran Reading Stats Screen

**Description**: Full analytics screen extending the Wird system. Charts for pages per week, daily average, streak history, khatm count, total pages since install.

### Steps
- [x] 1. Extend `WirdService` to compute weekly page data from `wird_progress_history` (already stored, 90 days)
- [x] 2. Create `QuranStatsData` model: weeklyPages (List<int> 7 days), weeklyJuz, totalPages, totalDays, currentStreak, bestStreak, khatmCount, averageDaily
- [x] 3. Create `quranStatsProvider` — derives stats from `wirdStateProvider` data
- [x] 4. Create `QuranStatsScreen`:
  - Header: total pages + khatm count badges
  - Bar chart: last 7 days pages (simple custom painter, no library needed)
  - Stats grid: current streak, best streak, average daily, total days active
  - Khatm progress circle (already exists in Wird tab — reuse)
- [x] 5. Add entry point: bar chart icon button in Wird tab streak card header
- [x] 6. Add route `/quran_stats`
- [x] 7. Add translation keys to en.json + ar.json
- [x] 8. Build, test, install APK ✅

---

---

## Feature 6: Post-Prayer Azkar Full-Screen

**Description**: Full-screen activity that fires 10 minutes after iqama finishes (or 15 min after adhan if no iqama is set). Shows the complete post-prayer remembrances from Hisn al-Muslim (chapter 25) as a scrollable counter list. Adapts per prayer — Fajr/Maghrib get extra azkar.

### Steps
- [x] 1. Create `activity_azkar_fullscreen.xml` — dark gradient background, header, NestedScrollView for dynamic content
- [x] 2. Create `AzkarAlarmReceiver.kt` — schedules alarm (IDs 9001–9006, request codes 3001–3006), posts heads-up notification + launches activity
- [x] 3. Create `AzkarFullScreenActivity.kt` — builds azkar list dynamically, gold counter badge flips to ✓ on done, "بارك الله فيك" banner on full completion
- [x] 4. Modify `PrayerAlarmReceiver.kt` — calls `AzkarAlarmReceiver.schedule()` after writing `adhan_iqama_time` (skipped for Sunrise)
- [x] 5. Register `AzkarFullScreenActivity` + `AzkarAlarmReceiver` in `AndroidManifest.xml`
- [x] 6. Expand azkar to full Hisn al-Muslim list: Istighfar ×3, Salam dua, 2 Tawhid formulas, Tasbeeh ×33 each, completing La ilaha illallah, Ayat al-Kursi, 3 Quls (×3 after Fajr/Maghrib), La ilaha illallah yuhyi ×10 (Fajr/Maghrib), beneficial knowledge dua (Fajr only)
- [x] 7. Build, test, install APK ✅

---

## Overall Progress

| # | Feature | Status | Session |
|---|---------|--------|---------|
| 1 | Morning & Evening Azkar Checklist | ✅ Done | session-3 |
| 2 | Qada Prayer Tracker | ⬜ Not started | — |
| 3 | Islamic Events Countdown | ✅ Done | session-4 |
| 4 | Sadaqa / Charity Goal Tracker | ⬜ Not started | — |
| 5 | Quran Reading Stats Screen | ✅ Done | session-4 |
| 6 | Post-Prayer Azkar Full-Screen | ✅ Done | session-5 |

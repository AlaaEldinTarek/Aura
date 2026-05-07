# Aura App — New Features Plan

**Created**: 2026-05-08
**Features**: 5 new features planned for upcoming sessions

---

## Feature 1: Morning & Evening Azkar Checklist

**Description**: Daily checklist of prophetic morning/evening remembrances (أذكار الصباح والمساء). Progress ring per session. Resets at Fajr (morning) and Maghrib (evening). Tied into achievements.

### Steps
- [ ] 1. Add `Zikr` model: id, textAr, textEn, count (repetitions required), category (morning/evening)
- [ ] 2. Add azkar data list (~20 morning, ~20 evening) as a Dart constant
- [ ] 3. Add SharedPreferences keys for daily azkar progress (`azkar_morning_YYYY-MM-DD`, `azkar_evening_YYYY-MM-DD`)
- [ ] 4. Add `azkarProvider` (StateNotifier) — tracks completed items, resets on new day
- [ ] 5. Create `AzkarScreen` with two tabs (Morning / Evening), progress ring at top, list of items
- [ ] 6. Each item: Arabic text, translation, repeat count badge, tap to mark done (haptic feedback)
- [ ] 7. Add azkar completion achievements (e.g., first time, 7-day streak)
- [ ] 8. Add route `/azkar` and bottom nav or quick action entry point
- [ ] 9. Add translation keys to en.json + ar.json
- [ ] 10. Build, test, install APK

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
- [ ] 1. Create `IslamicEvent` model: nameEn, nameAr, hijriMonth, hijriDay, description
- [ ] 2. Define events list: Ramadan (1 Muharram start? no — 1 Ramadan), Eid al-Fitr (1 Shawwal), Eid al-Adha (10 Dhul Hijjah), Laylat al-Qadr (27 Ramadan), Ashura (10 Muharram), Mawlid (12 Rabi al-Awwal), first 10 days Dhul Hijjah, Islamic New Year (1 Muharram)
- [ ] 3. Add `IslamicEventsService`: converts Hijri event dates to Gregorian using existing `HijriDate` util, finds next upcoming event
- [ ] 4. Add `islamicEventsProvider` — list of upcoming events sorted by date
- [ ] 5. Create `IslamicEventsScreen`: full list with countdown days, event description, Hijri date
- [ ] 6. Add countdown card to Home screen (between Daily Content and Next Prayer, only shows when event is within 30 days)
- [ ] 7. Add route `/islamic_events`
- [ ] 8. Add translation keys to en.json + ar.json
- [ ] 9. Build, test, install APK

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
- [ ] 1. Extend `WirdService` to compute weekly page data from `wird_progress_history` (already stored, 90 days)
- [ ] 2. Create `QuranStatsData` model: weeklyPages (List<int> 7 days), monthlyPages, totalPages, totalDays, currentStreak, bestStreak, khatmCount, averageDaily
- [ ] 3. Create `quranStatsProvider` — derives stats from `wirdStateProvider` data
- [ ] 4. Create `QuranStatsScreen`:
  - Header: total pages + khatm count badges
  - Bar chart: last 7 days pages (simple custom painter, no library needed)
  - Stats grid: current streak, best streak, average daily, total days active
  - Khatm progress circle (already exists in Wird tab — reuse)
- [ ] 5. Add entry point: button in Wird tab header or from Profile screen
- [ ] 6. Add route `/quran_stats`
- [ ] 7. Add translation keys to en.json + ar.json
- [ ] 8. Build, test, install APK

---

## Overall Progress

| # | Feature | Status | Session |
|---|---------|--------|---------|
| 1 | Morning & Evening Azkar Checklist | ⬜ Not started | — |
| 2 | Qada Prayer Tracker | ⬜ Not started | — |
| 3 | Islamic Events Countdown | ⬜ Not started | — |
| 4 | Sadaqa / Charity Goal Tracker | ⬜ Not started | — |
| 5 | Quran Reading Stats Screen | ⬜ Not started | — |

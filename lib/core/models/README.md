# Core Models Blueprint

## System Overview
Plain data classes, enums and const data tables (12 files, flat). Models do no I/O; persistence goes through
[`../services/README.md`](../services/README.md). The serialized field names below are a **schema contract**: Firestore
documents (paths: [firestore-paths](/.project-docs/contracts/firestore-paths.md)) and local JSON in SharedPreferences.
Renaming a field, an enum string, or a date format breaks existing user data. Behavior-preserving rule: no schema
changes without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public types | Serialization |
| --- | --- | --- |
| `task.dart` | `Task`, `SubTask`, `TaskPriority`, `TaskCategory`, `RecurrenceType` | `Task.fromFirestore` / `toFirestore`, `fromJson` / `toJson`; `SubTask.toMap` / `fromMap` |
| `prayer_record.dart` | `PrayerRecord`, `PrayerStatus`, `PrayerMethod`, `DailyPrayerSummary`, `PrayerStatistics`, `kPrayerNames`, `getCurrentUserId()` | `PrayerRecord.fromFirestore` / `toFirestore`, `fromJson` / `toJson` |
| `prayer_time.dart` | `PrayerTime` (Equatable; `emoji`, `time12h`, `copyWith`) | none (in-memory) |
| `prayer_settings.dart` | `CalculationMethod`, `AsrMadhab` (+ display-name extensions) | none (stored as enum `.name` by providers) |
| `user_data.dart` | `UserData` (`create`, `copyWith`) | `fromFirestore` / `toFirestore` |
| `achievement.dart` | `Achievement`, `AchievementCategory`, `AchievementDefinitions.all` (38 definitions) | `toFirestore`, `earnedFromFirestore(id, earnedAt)` |
| `dhikr.dart` | `DhikrSession`, `DhikrPreset`, `DhikrPresets.builtIn` (5), `DhikrStatistics` | `DhikrSession.fromFirestore` / `toFirestore`; `DhikrPreset.fromJson` / `toJson` |
| `wird.dart` | `WirdUnit`, `WirdSettings`, `WirdProgress`, `WirdState`, `QuranStatsData` | `WirdSettings` / `WirdProgress` `fromJson` / `toJson` |
| `azkar.dart` | `AzkarCategory`, `ZikrItem`, `AzkarData` (12 morning + 12 evening), `AzkarState` | `AzkarState.fromJson(json, todayKey)` / `toJson` |
| `quran_models.dart` | `Ayah`, `SurahMetaData`, `Surah`, `Juz`, `RevelationType`, `BookmarkColor`, `QuranBookmark`, `QuranReadingProgress`, `kSurahMetaData` (114 surahs) | `Ayah.fromJson` (asset); `QuranBookmark` / `QuranReadingProgress` `fromJson` / `toJson` |
| `islamic_event.dart` | `IslamicEvent`, `IslamicEventWithDate` | none |
| `daily_content.dart` | `DailyContent`, `DailyContentType` | none |

### Invariants
- **Firestore field names** (`toFirestore`; the doc id is not stored as a field, except `Achievement.id`):
  - `Task`: `title`, `description`, `isCompleted`, `priority`, `category`, `dueDate`, `createdAt`, `completedAt`,
    `tags`, `hasDueTime`, `recurrenceType`, `recurrenceInterval`, `recurrenceEndDate`, `parentTaskId`, `subtasks`
    (`id`, `title`, `isCompleted`), `isPinned`, `focusMode`, `focusDurationMinutes`, `estimatedMinutes`, `manualOrder`.
  - `PrayerRecord`: `userId`, `prayerName`, `date`, `prayedAt`, `status`, `method`, `notes`.
  - `UserData`: `email`, `displayName`, `photoUrl`, `themeMode`, `language`, `createdAt`, `updatedAt`.
  - `DhikrSession`: `userId`, `dhikrText`, `count`, `target`, `createdAt`, `completedAt`.
  - `Achievement`: `id`, `earnedAt`.
- **Date formats**: ISO-8601 strings everywhere (`Task`, `PrayerRecord`, `DhikrSession`, `Achievement`, bookmarks)
  **except `UserData`, which uses Firestore `Timestamp`**. Local day keys are zero-padded `YYYY-MM-DD`
  (`AzkarState`, `WirdProgress`).
- **Enum strings**: `PrayerStatus` `on_time` / `late` / `missed` / `excused`; `PrayerMethod` `congregation` / `alone` /
  `at_home`; `TaskPriority` `low` / `medium` / `high`; `TaskCategory` `work` / `personal` / `shopping` / `health` /
  `study` / `prayer` / `other`; `RecurrenceType` `none` / `daily` / `weekly` / `monthly`; `WirdUnit`, `BookmarkColor`
  stored as the enum name. Unknown strings fall back silently (status → `onTime`, method → `congregation`, priority → `medium`,
  category → `other`, recurrence → `none`, unit → `page`, color → `green`).
- **Prayer names**: `kPrayerNames` = `Fajr`, `Zuhr`, `Asr`, `Maghrib`, `Isha` (no Sunrise; `'Zuhr'`, never `'Dhuhr'`).
  `PrayerTime.emoji` also matches only `'Zuhr'`.
- **User id**: `getCurrentUserId()` returns the Firebase uid, or `'guest_user'` when signed out (the only model that reads auth).
- **Task rules**: equality by `id` only. `copyWith` can clear `dueDate`, `completedAt`, `recurrenceEndDate`, `parentTaskId`
  via `clear*` flags (not `description` / `tags`). `nextRecurrenceDate`: daily = +N days, weekly = +7N days, monthly = +N
  months with the day clamped to the month length. `isOverdue` respects `hasDueTime`; a completed task is never overdue. Defaults:
  priority `medium`, category `other`, interval 1, focus 25 min.
- **Summaries**: `DailyPrayerSummary.completedCount` counts every status except missed (late and excused count);
  `isComplete` needs at least 5 entries and none missed.
- **Achievements**: 38 ids in categories streaks / consistency / dhikr / tasks / quran / special; an unknown id
  becomes "Unknown" (category special). No app-mode filtering in this file.
- **Azkar**: `AzkarState.fromJson` clears both completed sets when the stored `dateKey` is not today. A session is complete
  when every `AzkarData` id for that category is done.
- **Wird defaults**: page goal 5, juz goal 1, unit `page`, reminders enabled, no linked bookmark color. The model doesn't
  clamp them; `WirdNotifier` does (providers README).
- **Quran data**: `kSurahMetaData` covers surahs 1–114, pages 1–604; `Ayah` keys are snake_case from the bundled asset.
  ⚠ Revelation type wrong for 4 surahs — findings F21.

### Side Effects
- None (no file, network or prefs I/O). Clock reads: `Task` getters, `UserData.create`, `AzkarState.empty`, missing
  `createdAt` → `DateTime.now()` in `Task.fromFirestore`. Auth read: `getCurrentUserId()`.

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- Field names, enum strings and date formats here must stay in sync with stored user data (Firestore + prefs JSON)
  and with any Kotlin reader of the same values (e.g. `prayer_status_*` values `on_time` / `late` / `missed`:
  [prefs-keys](/.project-docs/contracts/prefs-keys.md)).

## Global Side Effects
- None directly; models define the shape of everything services persist.

## System Verification
- Run: `flutter test` (`test/core/utils/prayer_models_test.dart` covers prayer models).

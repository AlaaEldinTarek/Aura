# Fix F47a + F47b + F47c + F47d — Profile screen

**Status:** Approved P1  
**Branch:** `fix/f47abcd`  
**Spec commit:** (this file)

---

## Findings

- **F47a** Display name never refreshes after edit — `authStateProvider` uses `authStateChanges()`, which only emits on sign-in/sign-out; `updateDisplayName` does not trigger it.
- **F47b** Raw integers in Arabic UI — completion-rate `%` (`:692`) and guest-sync task count (`:408`) skip `NumberFormatter`.
- **F47c** Raw `Error: $e` / `خطأ: $e` snackbars — both dialogs show the full exception string including the `Exception:` prefix (`profile_screen.dart:948, :1003`).
- **F47d** Inline `isArabic ? 'AR' : 'EN'` strings — ~39 string pairs across section tiles, stats, dialogs, and app-mode tiles; dead-code methods (`_showThemeDialog`, `_showLanguageDialog`, `_JumuahReminderTile`) are excluded (F47e backlog).

---

## P1 — Implementation

### F47a — Switch stream to `userChanges()`

**File:** `lib/core/services/auth_service.dart:24`

```dart
// Before
Stream<User?> get authStateChanges => _auth.authStateChanges();

// After
Stream<User?> get authStateChanges => _auth.userChanges();
```

`userChanges()` is a superset of `authStateChanges()` — it additionally emits when `updateDisplayName`, `updateEmail`, `updatePhotoURL`, or `reload()` is called. The `authStateProvider` stream rebuild picks up the new display name immediately. Known side-effect: also emits on each hourly ID-token refresh, causing the profile `FutureBuilder` to re-run `_loadProfileStats()` once per hour (pre-existing Firestore concern, F47e backlog).

### F47b — NumberFormatter for numeric UI

**File:** `lib/features/profile/profile_screen.dart`

1. Completion-rate display (`:692`):
   ```dart
   // Before
   ? '${(completionRate * 100).round()}%'
   // After
   ? '${NumberFormatter.withArabicNumeralsByLanguage('${(completionRate * 100).round()}', isArabic ? 'ar' : 'en')}%'
   ```

2. Guest-sync task count (`:408`):
   ```dart
   // Before
   .replaceAll('%d', '${migration.taskCount}')
   // After
   .replaceAll('%d', NumberFormatter.withArabicNumeralsByLanguage('${migration.taskCount}', isArabic ? 'ar' : 'en'))
   ```

### F47c — Strip exception prefix from error snackbars

**File:** `lib/features/profile/profile_screen.dart`

Both `_showEditNameDialog` (`:948`) and `_showChangePasswordDialog` (`:1003`) show `'Error: $e'` / `'خطأ: $e'`. Replace with the same pattern used in `login_screen.dart:311–313`:

```dart
final errMsg = e.toString().startsWith('Exception: ')
    ? e.toString().substring('Exception: '.length)
    : e.toString();
// then: Text(errMsg)  — red background conveys error; no "Error:" prefix needed
```

Apply to both catch blocks. Remove the `isArabic ?` language branch (the cleaned message is already in the user's language from Firebase).

### F47d — Translation keys for inline strings

**File:** `lib/features/profile/profile_screen.dart` + `assets/translations/en.json` + `assets/translations/ar.json`

Replace inline `isArabic ? 'AR' : 'EN'` pairs with `.tr()` keys. Reuse existing keys where possible:
- `profile_header_title` (AppBar titles, lines 116, 172)
- `cancel` (cancel buttons)
- `save` (save buttons)
- `display_name` (subtitle at :212, AR = "الاسم المعروض" ✓)

**39 new keys** (en / ar):

| Key | English | Arabic |
|-----|---------|--------|
| `profile_section_account` | Account | الحساب |
| `profile_email_subtitle` | Email | البريد الإلكتروني |
| `profile_display_name_fallback` | Display Name | اسم المستخدم |
| `profile_edit_name_title` | Edit Display Name | تعديل الاسم |
| `profile_edit_name_subtitle` | Change your display name | تغيير اسمك المعروض |
| `profile_change_password_title` | Change Password | تغيير كلمة المرور |
| `profile_change_password_subtitle` | Update your password | تحديث كلمة المرور |
| `profile_section_app_mode` | App Mode | وضع التطبيق |
| `profile_section_achievements` | Achievements | الإنجازات |
| `profile_section_settings` | Settings | الإعدادات |
| `profile_all_settings_title` | All Settings | جميع الإعدادات |
| `profile_all_settings_subtitle` | Prayer, tasks, notifications, appearance | الصلاة، المهام، الإشعارات، المظهر |
| `profile_app_tour_title` | App Tour | جولة التطبيق |
| `profile_app_tour_subtitle` | Replay the interactive walkthrough | أعد مشاهدة دليل التطبيق |
| `profile_section_about` | About | حول التطبيق |
| `profile_version_title` | Version | الإصدار |
| `profile_developer_title` | Developer | المطور |
| `profile_user_fallback` | User | مستخدم |
| `profile_prayer_stats_section` | Prayer | الصلاة |
| `profile_share` | Share | مشاركة |
| `profile_stat_streak` | Streak | التتابع |
| `profile_stat_prayers` | Prayers | الصلوات |
| `profile_stat_completion` | Completion | الإتمام |
| `profile_stat_badges` | Badges | الأوسمة |
| `profile_task_stats_section` | Tasks | المهام |
| `profile_stat_today` | Today | اليوم |
| `profile_stat_done` | Done | مكتملة |
| `profile_stat_pending` | Pending | معلقة |
| `profile_edit_name_hint` | Enter your name | أدخل اسمك |
| `profile_new_password_hint` | New password | كلمة المرور الجديدة |
| `profile_password_updated` | Password updated | تم تغيير كلمة المرور |
| `profile_app_mode_both` | Full App | الكل |
| `profile_app_mode_both_subtitle` | Prayer, Quran & Tasks | الصلاة والقرآن والمهام |
| `profile_app_mode_prayer` | Prayer & Quran | الصلاة والقرآن |
| `profile_app_mode_prayer_subtitle` | Prayer times, Quran & Adhan | أوقات الصلاة والقرآن والأذان |
| `profile_app_mode_tasks` | Tasks Only | المهام فقط |
| `profile_app_mode_tasks_subtitle` | Task management | إدارة المهام |
| `profile_login_prompt_title` | Profile | الملف الشخصي |
| `profile_login_prompt_subtitle` | Sign in to view your profile | سجّل الدخول لعرض ملفك الشخصي |

> **Note:** `profile_login_prompt_subtitle` replaces the inline string in `_buildLoginPrompt`. Confirm the Arabic wording is correct before merging.

---

## Tests

**File:** `test/features/profile/f47_source_test.dart`

- **T1** `NumberFormatter` applied to completion rate — `'${(0.75 * 100).round()}%'` in Arabic locale formats the digit as Arabic-Indic.
- **T2** `NumberFormatter` applied to guest-sync count — count `3` in Arabic locale renders as `٣`.
- **T3** Exception prefix stripped — `'Exception: some firebase error'` stripped to `'some firebase error'`.
- **T4** No-prefix passthrough — `'some firebase error'` unchanged.

---

## Contracts

No prefs keys, Firestore paths, notification IDs, or MethodChannels changed.

---

## Device checks

- **S-F47a-1** Edit display name → save → header immediately shows new name (no restart needed).
- **S-F47b-1** Arabic UI → profile → completion % shows Arabic-Indic digits.
- **S-F47c-1** Edit name with invalid input → snackbar shows clean error without `Exception:` prefix.
- **S-F47d-1** Arabic UI → all profile tiles and section headers show Arabic text (no missing translations).

# Fix F49d + F49e — Settings screen: raw digit values and inline strings

**Branch:** `fix/f49de` | **Status:** Approved P1 — implemented

---

## Findings

### F49d — Raw digit values in Arabic UI (LOW)
Five locations produce raw Western digits when Arabic locale is active:

| Line | Current | Fix |
|---|---|---|
| 160 | `'$_silentDuration دقيقة'` / `'$_silentDuration minutes'` | `NumberFormatter` + `settings_minutes_unit.tr()` |
| 195 | `'$reminderMins دقيقة'` / `'$reminderMins minutes'` | same |
| 275 | `_dailySummaryTime` (raw `HH:MM`) | `NumberFormatter.withArabicNumerals()` when Arabic |
| 378 | `'$mins دقيقة'` / `'$mins minutes'` (silent duration dialog) | same |
| 435 | `'$mins دقيقة'` / `'$mins minutes'` (task reminder dialog) | same |

Pattern for all minute values:
```dart
'${NumberFormatter.withArabicNumeralsByLanguage('$n', isArabic ? 'ar' : 'en')} ${'settings_minutes_unit'.tr()}'
```
Pattern for summary time:
```dart
isArabic ? NumberFormatter.withArabicNumerals(_dailySummaryTime) : _dailySummaryTime
```

### F49e — Inline EN/AR strings (LOW)
All live `isArabic ? '…' : '…'` ternaries in `settings_screen.dart` replaced with `.tr()` keys.
The `_themeName()` helper is also converted. Already-localized calls (`prayer_calc_method_title`,
`prayer_asr_madhab_title`, `pre_prayer_reminder`, `settings_permissions_title`,
`settings_permissions_subtitle`, `auto_launch_title`, `auto_launch_subtitle`) are untouched.
Language subtitle (`language == 'ar' ? 'العربية' : 'English'`) is intentionally left as-is —
it shows the language name in that language, not the current UI language.

---

## Translation keys (28 new)

| Key | en | ar |
|---|---|---|
| `settings_title` | Settings | الإعدادات |
| `settings_section_prayer` | Prayer | الصلاة |
| `settings_silent_mode_title` | Silent Mode at Adhan | الوضع الصامت عند الأذان |
| `settings_silent_mode_subtitle` | Auto-vibrate at prayer time | يُفعّل الاهتزاز تلقائياً عند الأذان |
| `settings_silent_duration_title` | Silent Mode Duration | مدة الوضع الصامت |
| `settings_minutes_unit` | minutes | دقيقة |
| `settings_iqama_title` | Iqama Times | أوقات الإقامة |
| `settings_adhan_sounds_title` | Adhan Sounds | تنزيل الأذان |
| `settings_section_tasks` | Tasks | المهام |
| `settings_task_reminders_title` | Task Reminders | تذكير المهام |
| `settings_task_reminders_subtitle` | Notify before task due time | إشعار قبل موعد المهمة |
| `settings_remind_before_title` | Remind Me Before | وقت التذكير |
| `settings_section_appearance` | Appearance | المظهر |
| `settings_language_title` | Language | اللغة |
| `settings_theme_title` | Theme | المظهر |
| `settings_theme_system` | System | تلقائي |
| `settings_theme_light` | Light | فاتح |
| `settings_theme_dark` | Dark | داكن |
| `settings_section_notifications` | Notifications | الإشعارات |
| `settings_jumuah_title` | Jumu'ah Reminder | تذكير صلاة الجمعة |
| `settings_jumuah_subtitle` | Notify before Friday prayer | إشعار قبل حلول وقت الجمعة |
| `settings_tracking_title` | Prayer Tracking | تتبع الصلوات |
| `settings_tracking_subtitle` | Auto-ask after each prayer | سؤال تلقائي بعد كل صلاة |
| `settings_summary_title` | Daily Summary | ملخص يومي |
| `settings_section_battery` | Background & Battery | الخلفية والبطارية |
| `settings_exact_alarms_title` | Exact Alarms | التنبيهات الدقيقة |
| `settings_exact_alarms_subtitle` | Required for on-time adhan | مطلوب للأذان في الوقت المحدد |
| `settings_battery_title` | Battery Optimization | تحسين البطارية |
| `settings_battery_subtitle` | Disable for reliable background alerts | تعطيل لضمان الإشعارات في الخلفية |
| `settings_section_desktop` | Desktop | سطح المكتب |
| `settings_startup_title` | Start with Windows | التشغيل مع بدء ويندوز |
| `settings_startup_subtitle` | Launch in the background when Windows starts | تشغيل التطبيق تلقائياً في الخلفية عند بدء النظام |

(28 keys; `settings_silent_duration_title` and `settings_remind_before_title` are reused as dialog
titles, and `settings_theme_*` are reused in the theme dialog options.)

---

## Files changed

| File | Change |
|---|---|
| `lib/features/settings/settings_screen.dart` | F49d + F49e fixes; add `number_formatter.dart` import |
| `assets/translations/en.json` | 28 new keys (+ `settings_minutes_unit` = 29 total... wait, `settings_minutes_unit` is in the 28) |
| `assets/translations/ar.json` | same 28 keys |
| `test/features/settings/f49de_source_test.dart` | New — 3 tests |

---

## Tests

**T1** — `NumberFormatter.withArabicNumeralsByLanguage('20', 'ar')` → `'٢٠'`  
**T2** — `NumberFormatter.withArabicNumerals('21:00')` → `'٢١:٠٠'` (time digit conversion)  
**T3** — `NumberFormatter.withArabicNumeralsByLanguage('20', 'en')` → `'20'`

---

## Device checks

**S-F49d-1** — Arabic locale → silent-duration subtitle, reminder-before subtitle, daily-summary time, and all dialog option labels show Arabic-Indic digits.  
**S-F49e-1** — Arabic locale → all section headers, tile titles and subtitles on the Settings screen display correct Arabic text.

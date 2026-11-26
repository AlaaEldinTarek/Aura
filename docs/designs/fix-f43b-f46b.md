# Fix F43b + F46b — Onboarding carousel inline strings

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f43b-f46b` (created from main)  
**Findings:** F43b (LOW), F46b (LOW)  
**Files touched:**
- `lib/features/onboarding/preference_screen.dart`
- `assets/translations/en.json`
- `assets/translations/ar.json`

---

## F43b — Daily content screen: inline EN/AR title strings

### Status: Pre-fixed

`daily_content_screen.dart:24–25` already uses `.tr()`:

```dart
final String typeLabel =
    isAyah ? 'daily_content_ayah_title'.tr() : 'daily_content_hadith_title'.tr();
```

Both keys exist in `en.json` and `ar.json` (lines 656–657). No code change needed.  
**F43b is DONE.**

---

## F46b — Onboarding wizard: carousel inline strings

### Problem

`preference_screen.dart` has a 3-slide feature carousel (Step 3) driven by a `_slides` getter
that builds `_Slide` and `_Feature` objects with separate `En`/`Ar` string fields:

- `_Slide.titleEn`, `_Slide.titleAr`, `_Slide.subtitleEn`, `_Slide.subtitleAr`
- `_Feature.textEn`, `_Feature.textAr`

`_SlideView.build` selects them with the inline ternary pattern that CLAUDE.md requires to go
through `.tr()`:

```dart
isAr ? slide.titleAr : slide.titleEn      // line 1011
isAr ? slide.subtitleAr : slide.subtitleEn // line 1022
isAr ? f.textAr : f.textEn                // line 1056
```

**Excluded:** The language-selection step (Step 0) title/subtitle
(`'Choose Your Language\nاختر لغتك'` etc.) are intentionally bilingual — both languages are
shown simultaneously before the user has made a choice. Those strings are not changed.

### Fix

Replace all 9 slide titles/subtitles and 27 feature texts with `.tr()` keys; remove the
`isAr` field from `_Slide`, `_Feature`, `_SlideView`, and `_CarouselStep`.

#### Data model changes

**`_Slide`** (bottom of file):

```dart
// Before
class _Slide {
  final String emoji, titleEn, titleAr, subtitleEn, subtitleAr;
  final Color color;
  final List<_Feature> features;
  const _Slide({
    required this.emoji,
    required this.color,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.features,
  });
}

// After
class _Slide {
  final String emoji, titleKey, subtitleKey;
  final Color color;
  final List<_Feature> features;
  const _Slide({
    required this.emoji,
    required this.color,
    required this.titleKey,
    required this.subtitleKey,
    required this.features,
  });
}
```

**`_Feature`** (bottom of file):

```dart
// Before
class _Feature {
  final String emoji, textEn, textAr;
  const _Feature(this.emoji, this.textEn, this.textAr);
}

// After
class _Feature {
  final String emoji, textKey;
  const _Feature(this.emoji, this.textKey);
}
```

#### `_SlideView.build` changes

Remove `isAr` field from `_SlideView`; use `.tr()` directly:

```dart
// Before
Text(isAr ? slide.titleAr : slide.titleEn, ...)
Text(isAr ? slide.subtitleAr : slide.subtitleEn, ...)
Text(isAr ? f.textAr : f.textEn, ...)

// After
Text(slide.titleKey.tr(), ...)
Text(slide.subtitleKey.tr(), ...)
Text(f.textKey.tr(), ...)
```

After the fix `isAr` is unused in `_SlideView`, so its field and constructor param are removed.
`_CarouselStep.isAr` is similarly unused and removed, along with the `isAr: _isAr` argument
in the `_CarouselStep(...)` call in `_PreferenceScreenState.build` (~line 328).

#### `_slides` getter — updated slide definitions

Pattern: `onboarding_slide_{mode}_{n}_{part}`  
where mode = `prayer` / `tasks` / `full`, n = `1`/`2`/`3`, part = `title`/`sub`/`f1`/`f2`/`f3`.

Example (prayer mode, slide 1 — before / after):

```dart
// Before
_Slide(
  emoji: '🕌',
  color: const Color(0xFF1565C0),
  titleEn: 'Accurate Prayer Times',
  titleAr: 'أوقات صلاة دقيقة',
  subtitleEn: 'GPS-based calculation with 9 scholarly methods',
  subtitleAr: 'حساب بالموقع الجغرافي بـ 9 طرق علمية',
  features: [
    _Feature('⏰', 'All 5 daily prayers + Sunrise', 'جميع الصلوات الخمس + الشروق'),
    _Feature('📍', 'Auto-detects your city', 'يتعرف تلقائياً على مدينتك'),
    _Feature('🔔', 'Adhan alerts at prayer time', 'أذان عند دخول وقت الصلاة'),
  ],
),

// After
_Slide(
  emoji: '🕌',
  color: const Color(0xFF1565C0),
  titleKey: 'onboarding_slide_prayer_1_title',
  subtitleKey: 'onboarding_slide_prayer_1_sub',
  features: [
    _Feature('⏰', 'onboarding_slide_prayer_1_f1'),
    _Feature('📍', 'onboarding_slide_prayer_1_f2'),
    _Feature('🔔', 'onboarding_slide_prayer_1_f3'),
  ],
),
```

All 9 slides follow the same pattern.

---

## Translation keys (45 keys × 2 languages)

### `prayerOnly` mode

| Key | EN | AR |
|-----|----|----|
| `onboarding_slide_prayer_1_title` | Accurate Prayer Times | أوقات صلاة دقيقة |
| `onboarding_slide_prayer_1_sub` | GPS-based calculation with 9 scholarly methods | حساب بالموقع الجغرافي بـ 9 طرق علمية |
| `onboarding_slide_prayer_1_f1` | All 5 daily prayers + Sunrise | جميع الصلوات الخمس + الشروق |
| `onboarding_slide_prayer_1_f2` | Auto-detects your city | يتعرف تلقائياً على مدينتك |
| `onboarding_slide_prayer_1_f3` | Adhan alerts at prayer time | أذان عند دخول وقت الصلاة |
| `onboarding_slide_prayer_2_title` | Spiritual Tools | أدوات روحية |
| `onboarding_slide_prayer_2_sub` | Everything you need for your worship | كل ما تحتاجه في عبادتك |
| `onboarding_slide_prayer_2_f1` | Qibla compass to Kaaba | بوصلة القبلة نحو الكعبة |
| `onboarding_slide_prayer_2_f2` | Digital Dhikr counter | عداد أذكار رقمي |
| `onboarding_slide_prayer_2_f3` | Daily Hadith & Quran | حديث وآية يومية |
| `onboarding_slide_prayer_3_title` | Track Your Journey | تتبع رحلتك |
| `onboarding_slide_prayer_3_sub` | Build consistency with daily prayer tracking | ابنِ المداومة بتتبع الصلوات اليومية |
| `onboarding_slide_prayer_3_f1` | Prayer streaks & milestones | سلاسل الصلاة والإنجازات |
| `onboarding_slide_prayer_3_f2` | Monthly calendar view | عرض تقويمي شهري |
| `onboarding_slide_prayer_3_f3` | Achievements & badges | أوسمة وشارات |

### `tasksOnly` mode

| Key | EN | AR |
|-----|----|----|
| `onboarding_slide_tasks_1_title` | Smart Task Management | إدارة مهام ذكية |
| `onboarding_slide_tasks_1_sub` | Organize everything that matters to you | نظّم كل ما يهمك |
| `onboarding_slide_tasks_1_f1` | Priorities, categories & due dates | أولويات وتصنيفات ومواعيد |
| `onboarding_slide_tasks_1_f2` | Subtasks & recurring tasks | مهام فرعية ومتكررة |
| `onboarding_slide_tasks_1_f3` | Pin important tasks to top | تثبيت المهام المهمة |
| `onboarding_slide_tasks_2_title` | Stay Focused | ابقَ مركزاً |
| `onboarding_slide_tasks_2_sub` | Lock in and get things done without distractions | ركز وأنجز مهامك بلا تشتيت |
| `onboarding_slide_tasks_2_f1` | Focus mode locks your screen | وضع التركيز يقفل شاشتك |
| `onboarding_slide_tasks_2_f2` | Silences all notifications | يكتم جميع الإشعارات |
| `onboarding_slide_tasks_2_f3` | Countdown timer on screen | مؤقت عدّ تنازلي على الشاشة |
| `onboarding_slide_tasks_3_title` | Build Good Habits | ابنِ عادات جيدة |
| `onboarding_slide_tasks_3_sub` | Stay motivated with streaks and achievements | حافظ على حماسك بالسلاسل والإنجازات |
| `onboarding_slide_tasks_3_f1` | 7-day task streak tracking | تتبع سلسلة 7 أيام |
| `onboarding_slide_tasks_3_f2` | Unlock achievement badges | افتح شارات الإنجازات |
| `onboarding_slide_tasks_3_f3` | Daily & weekly statistics | إحصاءات يومية وأسبوعية |

### `both` mode

| Key | EN | AR |
|-----|----|----|
| `onboarding_slide_full_1_title` | Your Complete Companion | رفيقك الشامل |
| `onboarding_slide_full_1_sub` | Prayer times + Task management in one beautiful app | أوقات الصلاة وإدارة المهام في تطبيق واحد |
| `onboarding_slide_full_1_f1` | Full Islamic prayer system | نظام صلاة إسلامي متكامل |
| `onboarding_slide_full_1_f2` | Powerful task management | إدارة مهام قوية |
| `onboarding_slide_full_1_f3` | Unified achievements | إنجازات موحدة للاثنين |
| `onboarding_slide_full_2_title` | Structure Your Day | نظّم يومك |
| `onboarding_slide_full_2_sub` | Plan your tasks around your prayer schedule | خطط مهامك حول أوقات صلاتك |
| `onboarding_slide_full_2_f1` | Know when your prayers are | اعرف أوقات صلاتك |
| `onboarding_slide_full_2_f2` | Fill the gaps with tasks | املأ الفراغات بالمهام |
| `onboarding_slide_full_2_f3` | Focus mode between prayers | وضع التركيز بين الصلوات |
| `onboarding_slide_full_3_title` | Track Everything | تتبع كل شيء |
| `onboarding_slide_full_3_sub` | Spiritual and productive growth in one view | النمو الروحي والإنتاجي في مكان واحد |
| `onboarding_slide_full_3_f1` | Prayer & task streaks | سلاسل الصلاة والمهام |
| `onboarding_slide_full_3_f2` | Combined statistics | إحصاءات مجمّعة |
| `onboarding_slide_full_3_f3` | Earn badges for both | اكسب شارات لكلٍّ منهما |

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| Native method channels | Not involved |
| Translation keys | 45 new `onboarding_slide_*` keys added to en.json + ar.json |

---

## Tests

Source-text tests (2 tests, file `test/features/onboarding/f46b_source_test.dart`):

- **T1**: `preference_screen.dart` does not reference `titleEn`, `titleAr`, `subtitleEn`, `subtitleAr`, `textEn`, or `textAr` as field names.
- **T2**: `preference_screen.dart` does not contain the pattern `isAr ? slide.` or `isAr ? f.`.

---

## Device check

| Step | Description |
|------|-------------|
| S-F46b-1 | First-launch flow (or clear-data) in Arabic: carousel step shows Arabic titles, subtitles, and feature text for all three slides in all three app modes. |
| S-F46b-2 | First-launch flow in English: carousel shows English text throughout. |

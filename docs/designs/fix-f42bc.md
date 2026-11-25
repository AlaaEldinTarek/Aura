# Fix F42b + F42c — Azkar day rollover + inline strings

**Status:** Approved for code (phase P1)
**Branch:** `fix/f42bc` (from main)
**Findings:** F42b (LOW), F42c (LOW)
**Files touched:**
- `lib/core/providers/azkar_provider.dart`
- `lib/features/azkar/azkar_screen.dart`
- `assets/translations/en.json`
- `assets/translations/ar.json`

---

## F42b — Problem

`AzkarNotifier._load()` runs once in the constructor. `AzkarState.fromJson`
clears completed items when `storedDate != todayKey` — but that check only
happens at startup. If the app stays alive past midnight, the provider's
in-memory state still holds yesterday's checked items; azkar items remain
ticked until the next full app restart.

## F42b — Fix

Add a public `checkDate()` to `AzkarNotifier`:

```dart
void checkDate() {
  final today = _todayKey();
  if (state.dateKey == today) return;
  state = AzkarState(
    completedMorning: {},
    completedEvening: {},
    dateKey: today,
    streakCount: state.streakCount,
    totalSessions: state.totalSessions,
  );
  _save();
}
```

Wire it in `_AzkarScreenState` via `WidgetsBindingObserver`:

```dart
class _AzkarScreenState extends ConsumerState<AzkarScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(azkarProvider.notifier).checkDate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed && mounted) {
      ref.read(azkarProvider.notifier).checkDate();
    }
  }
```

Clears checked items on:
- Screen first open (postFrameCallback)
- App brought to foreground (resumed)

Streak and totalSessions are preserved across the day boundary.

---

## F42c — Problem

Eight inline EN/AR string sites in `azkar_screen.dart`:

| Line(s) | String |
|---------|--------|
| `:44` | AppBar title `isArabic ? 'الأذكار' : 'Azkar'` |
| `:50` | Morning tab `isArabic ? 'أذكار الصباح' : 'Morning'` |
| `:54` | Evening tab `isArabic ? 'أذكار المساء' : 'Evening'` |
| `:263–265` | Progress header title (complete/incomplete variants) |
| `:275–279` | Progress header subtitle (complete/incomplete + number args) |
| `:293–295` | Streak text with number arg |

## F42c — Fix

**New translation keys** (added to both `en.json` and `ar.json`):

```json
// en.json additions
"azkar_title": "Azkar",
"azkar_morning_tab": "Morning",
"azkar_evening_tab": "Evening",
"azkar_progress_complete_title": "Well done! 🎉",
"azkar_progress_title": "Today's Progress",
"azkar_progress_complete_subtitle": "All azkar completed",
"azkar_progress_subtitle": "{} of {} completed",
"azkar_streak": "{} day streak"
```

```json
// ar.json additions
"azkar_title": "الأذكار",
"azkar_morning_tab": "أذكار الصباح",
"azkar_evening_tab": "أذكار المساء",
"azkar_progress_complete_title": "ما شاء الله! 🎉",
"azkar_progress_title": "تقدمك اليوم",
"azkar_progress_complete_subtitle": "أكملت جميع الأذكار",
"azkar_progress_subtitle": "{} من {} مكتمل",
"azkar_streak": "{} يوم متتالي"
```

**Code changes:**

```dart
// AppBar title
title: Text('azkar_title'.tr()),

// Tab labels
text: 'azkar_morning_tab'.tr(),
text: 'azkar_evening_tab'.tr(),

// Progress header title
isComplete ? 'azkar_progress_complete_title'.tr() : 'azkar_progress_title'.tr()

// Progress header subtitle
isComplete
    ? 'azkar_progress_complete_subtitle'.tr()
    : 'azkar_progress_subtitle'.tr(args: [
        NumberFormatter.withArabicNumeralsByLanguage('$done', isArabic ? 'ar' : 'en'),
        NumberFormatter.withArabicNumeralsByLanguage('$total', isArabic ? 'ar' : 'en'),
      ])

// Streak
'azkar_streak'.tr(args: [
  NumberFormatter.withArabicNumeralsByLanguage('$streakCount', isArabic ? 'ar' : 'en'),
])
```

Add `easy_localization` import to `azkar_screen.dart`.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged (`azkar_state`, `azkar_streak_date`) |
| Firestore paths | Not involved |
| Notification IDs / channels | Not involved |
| New translation keys | 8 added to both locales |

---

## Tests

Source-text test (`test/features/azkar/f42bc_source_test.dart`):

- **T1**: `azkar_provider.dart` contains `checkDate()` and `state.dateKey == today`
- **T2**: `azkar_screen.dart` contains `addObserver(this)` and `WidgetsBindingObserver`
- **T3**: `azkar_screen.dart` does NOT contain `'الأذكار'` as inline string; contains `'azkar_title'.tr()`

---

## Device checks

| ID | Description |
|----|-------------|
| S-F42b-1 | Open azkar screen, check some items. Advance device time past midnight. Bring app to foreground; azkar items should be reset. |
| S-F42c-1 | Switch language to Arabic; azkar screen title, tab labels, header, and streak show in Arabic. |

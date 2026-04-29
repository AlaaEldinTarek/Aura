import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/quran_provider.dart';
import '../../core/providers/task_provider.dart';
import '../../core/models/quran_models.dart';
import '../../core/services/quran_data_service.dart';
import '../../core/services/quran_reading_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/number_formatter.dart';
import 'quran_reader_screen.dart';

class QuranHomeScreen extends ConsumerStatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  ConsumerState<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends ConsumerState<QuranHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingActions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingActions();
    }
  }

  Future<void> _checkPendingActions() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();

    // "Read Now" tapped on notification — open reader at current page
    if (prefs.getBool('quran_open_reader') == true) {
      await prefs.remove('quran_open_reader');
      final currentPage = prefs.getInt('quran_current_page') ?? 1;
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuranReaderScreen(initialPage: currentPage),
          ),
        );
      }
    }
  }

  void _showReminderSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReminderSettingsSheet(
        onChanged: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text('quran'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _showReminderSettings,
            tooltip: 'quran_reminder_settings'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/quran_stats'),
            tooltip: 'stats'.tr(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'surahs'.tr()),
            Tab(text: 'juz'.tr()),
            Tab(text: 'bookmarks'.tr()),
          ],
          labelColor: AppConstants.getPrimary(isDark),
          unselectedLabelColor: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
          indicatorColor: AppConstants.getPrimary(isDark),
        ),
      ),
      body: Column(
        children: [
          _buildProgressCard(isDark, isArabic),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSurahsTab(isDark, isArabic),
                _buildJuzTab(isDark, isArabic),
                _buildBookmarksTab(isDark, isArabic),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark, bool isArabic) {
    final progressAsync = ref.watch(quranReadingProgressProvider);

    return progressAsync.when(
      data: (progress) {
        final pagesInKhatmah = progress.pagesInCurrentKhatmah;
        final khatmahPercent = pagesInKhatmah / 604;

        return Container(
          margin: const EdgeInsets.all(AppConstants.paddingMedium),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF2A2B2E), const Color(0xFF1A1B1E)]
                  : [const Color(0xFFFFEACC), const Color(0xFFFFF3D6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: AppConstants.getPrimary(isDark).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              // Circular progress
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      value: khatmahPercent,
                      strokeWidth: 4,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(AppConstants.getPrimary(isDark)),
                    ),
                  ),
                  Text(
                    isArabic
                        ? NumberFormatter.withArabicNumerals('$pagesInKhatmah')
                        : '$pagesInKhatmah',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppConstants.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'ختمة ${NumberFormatter.withArabicNumerals('${progress.khatmahCount + 1}')}'
                          : 'Khatmah ${progress.khatmahCount + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppConstants.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? '${NumberFormatter.withArabicNumerals('$pagesInKhatmah')} / ${NumberFormatter.withArabicNumerals('604')} ${'pages'.tr()}'
                          : '$pagesInKhatmah / 604 ${'pages'.tr()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                      ),
                    ),
                    if (progress.currentStreak > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '${progress.currentStreak} ${'day_streak'.tr()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Continue reading button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuranReaderScreen(initialPage: progress.currentPage),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.getPrimary(isDark),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  'continue_reading'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSurahsTab(bool isDark, bool isArabic) {
    final surahsAsync = ref.watch(quranSurahsMetaProvider);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'search_surah'.tr(),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        // Surah list
        Expanded(
          child: surahsAsync.when(
            data: (surahs) {
              final filtered = _searchQuery.isEmpty
                  ? surahs
                  : surahs.where((s) =>
                      s.nameEn.toLowerCase().contains(_searchQuery) ||
                      s.nameAr.contains(_searchQuery) ||
                      s.nameEnTranslation.toLowerCase().contains(_searchQuery) ||
                      s.number.toString() == _searchQuery).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text('no_results'.tr(), style: TextStyle(color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary)),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) => _buildSurahTile(filtered[index], isDark, isArabic),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('error_loading'.tr())),
          ),
        ),
      ],
    );
  }

  Widget _buildSurahTile(QuranSurahMeta surah, bool isDark, bool isArabic) {
    final isMeccan = surah.revelationType == 'Meccan';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppConstants.getPrimary(isDark).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            isArabic
                ? NumberFormatter.withArabicNumerals('${surah.number}')
                : '${surah.number}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppConstants.getPrimary(isDark),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              isArabic ? surah.nameAr : surah.nameEn,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppConstants.lightTextPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMeccan
                  ? Colors.green.withOpacity(0.15)
                  : Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isMeccan ? 'meccan'.tr() : 'medinan'.tr(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isMeccan ? Colors.green : Colors.blue,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        isArabic
            ? '${surah.nameEnTranslation} • ${NumberFormatter.withArabicNumerals('${surah.numberOfAyahs}')} ${'ayahs'.tr()}'
            : '${surah.nameEnTranslation} • ${surah.numberOfAyahs} ${'ayahs'.tr()}',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
        ),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuranReaderScreen(
              initialSurah: surah.number,
              initialPage: surah.startPage,
            ),
          ),
        );
      },
    );
  }

  Widget _buildJuzTab(bool isDark, bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: 30,
      itemBuilder: (context, index) {
        final juzNumber = index + 1;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppConstants.getPrimary(isDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  isArabic
                      ? NumberFormatter.withArabicNumerals('$juzNumber')
                      : '$juzNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.getPrimary(isDark),
                  ),
                ),
              ),
            ),
            title: Text(
              '${'juz'.tr()} $juzNumber',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppConstants.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              isArabic ? 'الجزء $juzNumber' : 'Part $juzNumber',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary),
            onTap: () {
              final pageIndexAsync = ref.read(quranPageIndexProvider);
              pageIndexAsync.whenData((pages) {
                final juzPage = pages.firstWhere(
                  (p) => p.juz == juzNumber,
                  orElse: () => pages.first,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuranReaderScreen(initialPage: juzPage.page),
                  ),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildBookmarksTab(bool isDark, bool isArabic) {
    final bookmarksAsync = ref.watch(quranBookmarksProvider);

    return bookmarksAsync.when(
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outline, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                const SizedBox(height: AppConstants.paddingMedium),
                Text('no_bookmarks'.tr(), style: TextStyle(color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            final surahMeta = QuranDataService.instance.getSurahMeta(bookmark.surahNumber);

            return ListTile(
              leading: Icon(Icons.bookmark, color: AppConstants.getPrimary(isDark)),
              title: Text(
                surahMeta != null
                    ? '${surahMeta.name(isArabic)} ${isArabic ? NumberFormatter.withArabicNumerals('${bookmark.ayahNumber}') : bookmark.ayahNumber}'
                    : '${'surah'.tr()} ${bookmark.surahNumber}:${bookmark.ayahNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppConstants.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                '${'page'.tr()} ${isArabic ? NumberFormatter.withArabicNumerals('${bookmark.page}') : bookmark.page}${bookmark.note != null ? ' • ${bookmark.note}' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                onPressed: () => _deleteBookmark(bookmark),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuranReaderScreen(initialPage: bookmark.page),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text('error_loading'.tr())),
    );
  }

  Future<void> _deleteBookmark(QuranBookmark bookmark) async {
    final userId = ref.read(currentUserIdProvider);
    await QuranReadingService.instance.removeBookmark(userId, bookmark.id ?? '');
    ref.invalidate(quranBookmarksProvider);
  }
}

// ─── Reminder Settings Sheet ─────────────────────────────────────────────────

class _ReminderSettingsSheet extends StatefulWidget {
  final VoidCallback? onChanged;
  const _ReminderSettingsSheet({this.onChanged});

  @override
  State<_ReminderSettingsSheet> createState() => _ReminderSettingsSheetState();
}

class _ReminderSettingsSheetState extends State<_ReminderSettingsSheet> {
  bool _enabled = false;
  List<TimeOfDay> _times = [];
  int _snoozeMins = 30;
  bool _loading = true;

  static const _snoozeOptions = [5, 10, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('quran_reminder_enabled') ?? false;
    final snooze = prefs.getInt('quran_snooze_minutes') ?? 30;

    // Load up to 3 reminder times
    final times = <TimeOfDay>[];
    for (int i = 0; i < 3; i++) {
      final h = prefs.getInt('quran_reminder_hour_$i');
      final m = prefs.getInt('quran_reminder_minute_$i');
      if (h != null && m != null) {
        times.add(TimeOfDay(hour: h, minute: m));
      }
    }
    // Fallback: check legacy single-time key
    if (times.isEmpty && enabled) {
      final h = prefs.getInt('quran_reminder_hour') ?? 21;
      final m = prefs.getInt('quran_reminder_minute') ?? 0;
      times.add(TimeOfDay(hour: h, minute: m));
    }

    if (mounted) {
      setState(() {
        _enabled = enabled;
        _times = times;
        _snoozeMins = snooze;
        _loading = false;
      });
    }
  }

  String _scheduleError = '';

  /// Returns "Today HH:MM" or "Tomorrow HH:MM" for display
  String _nextFireLabel(TimeOfDay t, bool isArabic) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    final isTomorrow = next.isBefore(now) || next.isAtSameMomentAs(now);
    if (isTomorrow) next = next.add(const Duration(days: 1));
    final dayLabel = isTomorrow
        ? (isArabic ? 'غداً' : 'Tomorrow')
        : (isArabic ? 'اليوم' : 'Today');
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? (isArabic ? 'ص' : 'AM') : (isArabic ? 'م' : 'PM');
    final hStr = isArabic ? NumberFormatter.withArabicNumerals('$hour') : '$hour';
    final mStr = isArabic ? NumberFormatter.withArabicNumerals(min) : min;
    return '$dayLabel $hStr:$mStr $period';
  }

  Future<void> _saveSettings({bool showFeedback = false}) async {
    setState(() => _scheduleError = '');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quran_snooze_minutes', _snoozeMins);

      for (int i = 0; i < 3; i++) {
        await prefs.remove('quran_reminder_hour_$i');
        await prefs.remove('quran_reminder_minute_$i');
      }

      if (!_enabled || _times.isEmpty) {
        await NotificationService.instance.cancelQuranReminders();
        await prefs.setBool('quran_reminder_enabled', false);
        return;
      }

      for (int i = 0; i < _times.length; i++) {
        await prefs.setInt('quran_reminder_hour_$i', _times[i].hour);
        await prefs.setInt('quran_reminder_minute_$i', _times[i].minute);
      }

      if (_times.length == 1) {
        await NotificationService.instance.scheduleQuranReminder(
          hour: _times[0].hour,
          minute: _times[0].minute,
        );
      } else {
        await NotificationService.instance.scheduleQuranReminders(
          hours: _times.map((t) => t.hour).toList(),
          minutes: _times.map((t) => t.minute).toList(),
        );
      }

      if (showFeedback && mounted) setState(() {}); // refresh next-fire labels
    } catch (e) {
      debugPrint('❌ [QURAN_REMINDER] Schedule failed: $e');
      if (mounted) setState(() => _scheduleError = e.toString());
    }
  }

  Future<void> _addTime() async {
    if (_times.length >= 3) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 21, minute: 0),
    );
    if (picked != null) {
      setState(() => _times.add(picked));
      await _saveSettings(showFeedback: true);
      widget.onChanged?.call();
    }
  }

  Future<void> _removeTime(int index) async {
    setState(() => _times.removeAt(index));
    await _saveSettings();
    widget.onChanged?.call();
  }

  Future<void> _editTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked != null) {
      setState(() => _times[index] = picked);
      await _saveSettings(showFeedback: true);
      widget.onChanged?.call();
    }
  }

  String _formatTime(TimeOfDay t, bool isArabic) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am
        ? (isArabic ? 'ص' : 'AM')
        : (isArabic ? 'م' : 'PM');
    final hourStr = isArabic ? NumberFormatter.withArabicNumerals('$hour') : '$hour';
    final minStr = isArabic ? NumberFormatter.withArabicNumerals(minute) : minute;
    return '$hourStr:$minStr $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primary = AppConstants.getPrimary(isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingMedium + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Text(
                  'quran_reminder_settings'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppConstants.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Enable toggle
                _SettingsRow(
                  isDark: isDark,
                  label: 'quran_reminder_enabled'.tr(),
                  trailing: Switch(
                    value: _enabled,
                    activeColor: primary,
                    onChanged: (val) async {
                      setState(() => _enabled = val);
                      if (!val) {
                        await NotificationService.instance.cancelQuranReminders();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('quran_reminder_enabled', false);
                      } else if (_times.isNotEmpty) {
                        await _saveSettings();
                      }
                      widget.onChanged?.call();
                    },
                  ),
                ),

                if (_enabled) ...[
                  const SizedBox(height: 12),

                  // Reminder times header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'quran_reminder_times'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppConstants.lightTextSecondary,
                        ),
                      ),
                      if (_times.length < 3)
                        TextButton.icon(
                          onPressed: _addTime,
                          icon: Icon(Icons.add, size: 18, color: primary),
                          label: Text(
                            'quran_add_reminder_time'.tr(),
                            style: TextStyle(color: primary, fontSize: 13),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Times list
                  if (_times.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'quran_no_reminder_times'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    )
                  else
                    ...List.generate(_times.length, (i) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2B2E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.access_time, color: primary, size: 20),
                          title: Text(
                            _formatTime(_times[i], isArabic),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppConstants.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '🔔 ${_nextFireLabel(_times[i], isArabic)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                            onPressed: () => _removeTime(i),
                          ),
                          onTap: () => _editTime(i),
                        ),
                      );
                    }),

                  // Error message
                  if (_scheduleError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isArabic ? 'فشل جدولة الإشعار' : 'Failed to schedule: $_scheduleError',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Snooze duration
                  Text(
                    'quran_snooze_duration'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppConstants.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _snoozeOptions.map((min) {
                      final selected = _snoozeMins == min;
                      return ChoiceChip(
                        label: Text(
                          isArabic
                              ? '${NumberFormatter.withArabicNumerals('$min')} د'
                              : '$min min',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: selected,
                        selectedColor: primary,
                        backgroundColor: isDark ? const Color(0xFF2A2B2E) : const Color(0xFFF0F0F0),
                        onSelected: (_) async {
                          setState(() => _snoozeMins = min);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('quran_snooze_minutes', min);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Test button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: Text(
                        isArabic ? 'اختبار الإشعار' : 'Test Notification',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await NotificationService.instance.sendTestQuranNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? 'تم إرسال الإشعار الآن'
                                    : 'Test notification sent',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final bool isDark;
  final String label;
  final Widget trailing;

  const _SettingsRow({
    required this.isDark,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : AppConstants.lightTextPrimary,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

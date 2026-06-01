import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/prayer_record.dart';
import '../../core/models/prayer_time.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/daily_prayer_status_provider.dart';
import '../../core/utils/haptic_feedback.dart' as haptic;
import '../../core/widgets/prayer_status_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/prayer_time_rules.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_typography.dart';

/// Prayer Tracking Screen - Shows prayer history and statistics
class PrayerTrackingScreen extends ConsumerStatefulWidget {
  const PrayerTrackingScreen({super.key});

  @override
  ConsumerState<PrayerTrackingScreen> createState() => _PrayerTrackingScreenState();
}

class _PrayerTrackingScreenState extends ConsumerState<PrayerTrackingScreen> {
  final PrayerTrackingService _trackingService = PrayerTrackingService.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late DateTime _effectiveToday;
  Map<DateTime, DailyPrayerSummary> _monthlyData = {};
  bool _isLoading = false;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Between midnight and Fajr → treat yesterday as the active day
    final prayerState = ref.read(prayerTimesProvider);
    final fajrMatches = (prayerState?.prayerTimes ?? []).where((p) => p.name == 'Fajr');
    if (fajrMatches.isNotEmpty && now.isBefore(fajrMatches.first.time)) {
      _selectedDay = today.subtract(const Duration(days: 1));
    } else {
      _selectedDay = today;
    }
    _effectiveToday = _selectedDay!;
    _focusedDay = _selectedDay!;
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);

    // Get user ID from auth
    final userId = getCurrentUserId();

    // Clear cache to ensure fresh data from Firestore
    _trackingService.clearCache();

    final data = await _trackingService.getMonthData(
      userId: userId,
      month: _focusedDay,
    );

    // Calculate streak using service (handles cross-month correctly)
    final streak = await _trackingService.calculateCurrentStreak(userId: userId);

    if (mounted) {
      setState(() {
        _monthlyData = data;
        _currentStreak = streak;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Sync real-time prayer marks from home/prayer screen into the calendar.
    // Uses _effectiveToday (computed once in initState) to avoid a race where
    // prayerTimesProvider hasn't loaded yet and the target date defaults to the
    // wrong calendar date.  Also guards against the provider reloading for the
    // calendar date (e.g. May 28) while the effective day is still yesterday
    // (May 27) — an empty reload must not overwrite correctly-loaded data.
    ref.listen<DailyPrayerStatus>(dailyPrayerStatusProvider, (_, next) {
      if (!mounted) return;
      final existing = _monthlyData[_effectiveToday];
      if (next.statuses.isEmpty && existing != null && existing.prayers.isNotEmpty) return;
      setState(() {
        _monthlyData[_effectiveToday] = DailyPrayerSummary(
          date: _effectiveToday,
          prayers: Map<String, PrayerStatus>.from(next.statuses),
        );
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تتبع الصلوات' : 'Prayer Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () {
              Navigator.of(context).pushNamed('/prayer_report');
            },
            tooltip: isArabic ? 'التقرير' : 'Report',
          ),
        ],
      ),
      body: Builder(builder: (ctx) {
        final ts = MediaQuery.textScalerOf(ctx);
        return RefreshIndicator(
        onRefresh: _loadMonthData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Statistics cards
              _buildStatisticsCards(context, isDark, isArabic),

              SizedBox(height: ts.scale(AppConstants.paddingLarge).clamp(0.0, 28.0)),

              // Calendar
              _buildCalendar(context, isDark, isArabic),

              SizedBox(height: ts.scale(AppConstants.paddingLarge).clamp(0.0, 28.0)),

              // Empty state when no records exist for this month
              if (!_isLoading && _monthlyData.isEmpty)
                EmptyState(
                  iconEmoji: '🕌',
                  title: isArabic ? 'لا توجد سجلات هذا الشهر' : 'No prayer records this month',
                  subtitle: isArabic
                      ? 'ابدأ بتسجيل صلواتك لبناء سلسلتك'
                      : 'Start marking your prayers to build your streak',
                ),

              // Selected day details
              if (_selectedDay != null)
                _buildDayDetails(context, _selectedDay!, isDark, isArabic,
                    ref.watch(prayerTimesProvider.select((s) => s.prayerTimes))),

              SizedBox(height: ts.scale(80.0)),
            ],
          ),
        ),
      );
      }),
    );
  }

  Widget _buildStatisticsCards(BuildContext context, bool isDark, bool isArabic) {
    final ts = MediaQuery.textScalerOf(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate stats from start of month to today
    final startOfMonth = DateTime(now.year, now.month, 1);
    int totalPrayers = 0;
    int completedPrayers = 0;
    int onTimePrayers = 0;

    // Count all days from start of month to today (5 prayers each)
    for (DateTime day = startOfMonth; !day.isAfter(today); day = day.add(const Duration(days: 1))) {
      final summary = _monthlyData[day];
      for (final prayerName in kPrayerNames) {
        totalPrayers++;
        final status = summary?.prayers[prayerName];
        if (status == PrayerStatus.onTime || status == PrayerStatus.late) {
          completedPrayers++;
        }
        if (status == PrayerStatus.onTime) {
          onTimePrayers++;
        }
      }
    }

    final completionRate = totalPrayers > 0 ? (completedPrayers / totalPrayers * 100).round() : 0;
    final onTimeRate = totalPrayers > 0 ? (onTimePrayers / totalPrayers * 100).round() : 0;

    // Use service-calculated streak (handles cross-month correctly)
    final streak = _currentStreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'إحصائيات الشهر' : 'This Month\'s Statistics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                label: isArabic ? 'التتابع' : 'Streak',
                value: NumberFormatter.withArabicNumeralsByLanguage('$streak', isArabic ? 'ar' : 'en'),
                color: Colors.orange,
                isDark: isDark,
              ),
            ),
            SizedBox(width: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                label: isArabic ? 'إتمام' : 'Complete',
                value: NumberFormatter.withArabicNumeralsByLanguage('$completionRate%', isArabic ? 'ar' : 'en'),
                color: Colors.green,
                isDark: isDark,
              ),
            ),
            SizedBox(width: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
            Expanded(
              child: _StatCard(
                icon: Icons.schedule,
                label: isArabic ? 'في الوقت' : 'On Time',
                value: NumberFormatter.withArabicNumeralsByLanguage('$onTimeRate%', isArabic ? 'ar' : 'en'),
                color: AppConstants.getPrimary(isDark),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, bool isDark, bool isArabic) {
    final ts = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'التقويم' : 'Calendar',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
        Container(
          decoration: BoxDecoration(
            color: AppConstants.card(isDark),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: AppConstants.border(isDark),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            daysOfWeekHeight: ts.scale(32.0).clamp(32.0, 56.0),
            rowHeight: ts.scale(44.0).clamp(40.0, 70.0),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                _focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadMonthData();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppConstants.getPrimary(isDark).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppConstants.getPrimary(isDark),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              weekendTextStyle: AppTypography.caption.copyWith(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: AppTypography.bodyL.copyWith(
                color: AppConstants.textPrimary(isDark),
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: AppConstants.textPrimary(isDark),
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: AppConstants.textPrimary(isDark),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: AppTypography.caption.copyWith(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              weekendStyle: AppTypography.caption.copyWith(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            eventLoader: (day) {
              final normalizedDay = DateTime(day.year, day.month, day.day);
              final summary = _monthlyData[normalizedDay];
              return summary != null && summary.isComplete ? ['completed'] : [];
            },
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayDetails(
    BuildContext context,
    DateTime day,
    bool isDark,
    bool isArabic,
    List<PrayerTime> todayPrayerTimes,
  ) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isPastDay = normalizedDay.isBefore(today);
    final isToday = normalizedDay == today;

    final summary = _monthlyData[normalizedDay];
    final prayerNames = kPrayerNames;
    final prayerDisplayNames = {
      'Fajr': isArabic ? 'الفجر' : 'Fajr',
      'Zuhr': isArabic ? 'الظهر' : 'Zuhr',
      'Asr': isArabic ? 'العصر' : 'Asr',
      'Maghrib': isArabic ? 'المغرب' : 'Maghrib',
      'Isha': isArabic ? 'العشاء' : 'Isha',
    };
    final prayerEmojis = {
      'Fajr': '🌙', 'Zuhr': '☀️', 'Asr': '🌤️', 'Maghrib': '🌇', 'Isha': '🌃',
    };

    // For today: hide any stored status for prayers whose Adhan + 20 min hasn't
    // passed yet — same rule as canMarkPrayer.  Past days are shown as-is.
    final Map<String, PrayerStatus?> statuses = {};
    for (final name in prayerNames) {
      final stored = summary?.prayers[name];
      statuses[name] = (isToday && stored != null && !isPrayerTimeReached(name, todayPrayerTimes))
          ? null
          : stored;
    }

    final ts = MediaQuery.textScalerOf(context);
    return Container(
      padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
      decoration: BoxDecoration(
        color: AppConstants.card(isDark),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppConstants.border(isDark),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday
                    ? (isArabic ? 'تفاصيل اليوم' : "Today's Details")
                    : '${isArabic ? 'تفاصيل' : 'Details'} - ${NumberFormatter.withArabicNumeralsByLanguage('${day.day}/${day.month}/${day.year}', isArabic ? 'ar' : 'en')}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (isPastDay || isToday)
                Text(
                  isArabic ? 'اضغط لتسجيل' : 'Tap to record',
                  style: AppTypography.labelS.copyWith(
                    color: AppConstants.textDisabled(isDark),
                  ),
                ),
            ],
          ),
          SizedBox(height: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
          ...prayerNames.map((prayerName) {
            final displayName = prayerDisplayNames[prayerName]!;
            final emoji = prayerEmojis[prayerName]!;
            final status = statuses[prayerName];

            return _buildPrayerActionRow(
              context: context,
              prayerName: prayerName,
              displayName: displayName,
              emoji: emoji,
              status: status,
              date: normalizedDay,
              isDark: isDark,
              isArabic: isArabic,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPrayerActionRow({
    required BuildContext context,
    required String prayerName,
    required String displayName,
    required String emoji,
    required PrayerStatus? status,
    required DateTime date,
    required bool isDark,
    required bool isArabic,
  }) {
    final ts = MediaQuery.textScalerOf(context);
    final isCompleted = status == PrayerStatus.onTime || status == PrayerStatus.late;
    final isExplicitlyMissed = status == PrayerStatus.excused || status == PrayerStatus.missed;

    final showBadge = isCompleted || isExplicitlyMissed;
    final badgeColor = isExplicitlyMissed
        ? Colors.red
        : (status == PrayerStatus.late ? Colors.orange : Colors.green);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: ts.scale(4.0)),
      child: InkWell(
        onTap: () => _togglePrayerStatus(prayerName, date, status, isArabic),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ts.scale(12.0), vertical: ts.scale(10.0)),
          decoration: BoxDecoration(
            color: showBadge ? badgeColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: showBadge
                ? Border.all(color: badgeColor.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Emoji
              Text(emoji, style: TextStyle(fontSize: ts.scale(20.0)), textScaler: TextScaler.noScaling),
              SizedBox(width: ts.scale(12.0)),

              // Prayer name
              Expanded(
                child: Text(
                  displayName,
                  style: AppTypography.bodyL.copyWith(
                    fontWeight: showBadge ? FontWeight.w600 : FontWeight.normal,
                    color: AppConstants.textPrimary(isDark),
                  ),
                ),
              ),

              // Status badge
              if (showBadge)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: ts.scale(10.0), vertical: ts.scale(4.0)),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExplicitlyMissed
                            ? Icons.cancel
                            : (status == PrayerStatus.late ? Icons.schedule : Icons.check_circle),
                        color: badgeColor,
                        size: ts.scale(16.0),
                      ),
                      SizedBox(width: ts.scale(4.0)),
                      Text(
                        isExplicitlyMissed
                            ? (isArabic ? 'لم أصلّ' : 'Missed')
                            : status == PrayerStatus.late
                                ? (isArabic ? 'متأخر' : 'Late')
                                : (isArabic ? 'في الوقت' : 'On Time'),
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: ts.scale(10.0), vertical: ts.scale(4.0)),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radio_button_unchecked,
                          color: AppConstants.textDisabled(isDark), size: ts.scale(16.0)),
                      SizedBox(width: ts.scale(4.0)),
                      Text(
                        isArabic ? 'غير مُصلّاة' : 'Not Prayed',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppConstants.textDisabled(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePrayerStatus(
    String prayerName,
    DateTime date,
    PrayerStatus? currentStatus,
    bool isArabic,
  ) async {
    final userId = getCurrentUserId();
    final calendarDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Read prayer times once for both effective-date check and 20-minute rule
    final prayerState = ref.read(prayerTimesProvider);
    final prayerTimes = prayerState?.prayerTimes ?? [];

    // Between midnight and Fajr → record to previous day
    DateTime effectiveDate = calendarDate;
    if (calendarDate == today) {
      final fajrMatches = prayerTimes.where((p) => p.name == 'Fajr');
      if (fajrMatches.isNotEmpty && now.isBefore(fajrMatches.first.time)) {
        effectiveDate = today.subtract(const Duration(days: 1));
      }
    }

    // 20-minute rule: only when recording for actual today (not post-midnight for yesterday)
    if (calendarDate == today && effectiveDate == today && currentStatus == null) {
      if (!canMarkPrayer(context: context, prayerName: prayerName, prayerTimes: prayerTimes, isArabic: isArabic)) {
        return;
      }
    }

    try {
      if (currentStatus != null) {
        // Show confirmation dialog before unmarking
        final confirmed = await showUnmarkConfirmDialog(
          context: context,
          prayerName: prayerName,
          isArabic: isArabic,
        );

        if (confirmed != true || !mounted) return;

        // Unmark — delete the record
        final deleted = await _trackingService.deletePrayerRecord(
          userId: userId,
          prayerName: prayerName,
          date: effectiveDate,
        );

        if (!deleted) {
          haptic.HapticFeedback.error();
          if (mounted) {
            final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic
                      ? 'فشل إلغاء التسجيل. حاول مرة أخرى.'
                      : 'Failed to unmark. Please try again.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              ),
            );
            Future.delayed(const Duration(seconds: 2), snackCtrl.close);
          }
          return;
        }

        // Immediately update local data
        haptic.HapticFeedback.light();
        setState(() {
          final dayKey = effectiveDate;
          final existing = _monthlyData[dayKey];
          if (existing != null) {
            final updatedPrayers = Map<String, PrayerStatus>.from(existing.prayers);
            updatedPrayers.remove(prayerName);
            _monthlyData[dayKey] = DailyPrayerSummary(
              date: effectiveDate,
              prayers: updatedPrayers,
            );
          }
        });

        // Refresh prayer cards on prayer screen and home screen
        if (effectiveDate == today) {
          _trackingService.clearCache();
          ref.read(dailyPrayerStatusProvider.notifier).load(forceRefresh: true);
        }

        if (mounted) {
          final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic ? 'تم إلغاء تسجيل $prayerName' : 'Unmarked $prayerName',
              ),
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            ),
          );
          Future.delayed(const Duration(milliseconds: 800), snackCtrl.close);
        }
      } else {
        // Show dialog to choose: On Time, Late, or Missed
        final chosenStatus = await showPrayerStatusDialog(
          context: context,
          prayerName: prayerName,
          isArabic: isArabic,
        );

        if (chosenStatus == null) return; // User cancelled

        // Mark as completed with chosen status
        final success = await _trackingService.recordPrayer(
          userId: userId,
          prayerName: prayerName,
          date: effectiveDate,
          prayedAt: DateTime.now(),
          status: chosenStatus,
          method: PrayerMethod.congregation,
        );

        if (!success) {
          haptic.HapticFeedback.error();
          if (mounted) {
            final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic
                      ? 'فشل تسجيل $prayerName. حاول مرة أخرى.'
                      : 'Failed to record $prayerName. Please try again.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              ),
            );
            Future.delayed(const Duration(seconds: 2), snackCtrl.close);
          }
          return;
        }

        // Immediately update local data
        haptic.HapticFeedback.success();
        setState(() {
          final dayKey = effectiveDate;
          final existing = _monthlyData[dayKey];
          if (existing != null) {
            final updatedPrayers = Map<String, PrayerStatus>.from(existing.prayers);
            updatedPrayers[prayerName] = chosenStatus;
            _monthlyData[dayKey] = DailyPrayerSummary(
              date: effectiveDate,
              prayers: updatedPrayers,
            );
          } else {
            _monthlyData[dayKey] = DailyPrayerSummary(
              date: effectiveDate,
              prayers: {prayerName: chosenStatus},
            );
          }
        });

        // Refresh prayer cards on prayer screen and home screen
        if (effectiveDate == today) {
          _trackingService.clearCache();
          ref.read(dailyPrayerStatusProvider.notifier).load(forceRefresh: true);
        }

        if (mounted) {
          final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                effectiveDate == today
                    ? (isArabic ? 'تم تسجيل $prayerName' : 'Recorded $prayerName')
                    : (isArabic ? 'تم تسجيل $prayerName ليوم أمس' : 'Recorded $prayerName for yesterday'),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            ),
          );
          Future.delayed(const Duration(milliseconds: 800), snackCtrl.close);
        }
      }
    } catch (e) {
      debugPrint('Error toggling prayer status: $e');
      haptic.HapticFeedback.error();
      if (mounted) {
        final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ: $e' : 'Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          ),
        );
        Future.delayed(const Duration(seconds: 3), snackCtrl.close);
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    return Container(
      padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
      decoration: BoxDecoration(
        color: AppConstants.card(isDark),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppConstants.border(isDark),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: ts.scale(28.0)),
          SizedBox(height: ts.scale(8.0)),
          Text(
            value,
            style: AppTypography.headingM.copyWith(
              fontWeight: FontWeight.bold,
              color: AppConstants.textPrimary(isDark),
            ),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppConstants.textMuted(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

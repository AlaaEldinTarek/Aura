import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Prayer Tracking Screen - Shows prayer history and statistics.
///
/// Reads and writes exclusively through [dailyPrayerStatusProvider] — the one
/// shared, date-keyed source of truth. It owns no prayer state of its own, so a
/// mark made here (or on the home card, Prayer Times page, or via a
/// notification button) is reflected everywhere immediately, and editing a past
/// day can never alter today.
class PrayerTrackingScreen extends ConsumerStatefulWidget {
  const PrayerTrackingScreen({super.key});

  @override
  ConsumerState<PrayerTrackingScreen> createState() =>
      _PrayerTrackingScreenState();
}

class _PrayerTrackingScreenState extends ConsumerState<PrayerTrackingScreen> {
  final PrayerTrackingService _trackingService = PrayerTrackingService.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late DateTime _effectiveToday;
  bool _isLoading = false;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    // Effective Islamic day comes from the single source of truth.
    _effectiveToday =
        ref.read(dailyPrayerStatusProvider.notifier).computeEffectiveToday();
    _selectedDay = _effectiveToday;
    _focusedDay = _effectiveToday;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await ref
        .read(dailyPrayerStatusProvider.notifier)
        .loadMonth(_focusedDay, forceRefresh: true);
    final streak = await _trackingService.calculateCurrentStreak(
        userId: getCurrentUserId());
    if (mounted) {
      setState(() {
        _currentStreak = streak;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStreak() async {
    final streak = await _trackingService.calculateCurrentStreak(
        userId: getCurrentUserId());
    if (mounted) setState(() => _currentStreak = streak);
  }

  /// Display-filtered statuses for [day]. For the actual calendar today, a
  /// prayer is hidden until its Adhan + 20 min has passed (same rule as
  /// canMarkPrayer); past days are shown as-is.
  Map<String, PrayerStatus> _displayStatuses(
      DateTime day, DailyPrayerStatus tracking, List<PrayerTime> times) {
    final raw = tracking.statusesFor(day);
    if (day != _d(DateTime.now())) return raw;
    final out = <String, PrayerStatus>{};
    raw.forEach((name, status) {
      if (isPrayerTimeReached(name, times)) out[name] = status;
    });
    return out;
  }

  bool _isDayComplete(
      DateTime day, DailyPrayerStatus tracking, List<PrayerTime> times) {
    final s = _displayStatuses(day, tracking, times);
    if (s.length < kPrayerNames.length) return false;
    return s.values.every((st) => st != PrayerStatus.missed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final tracking = ref.watch(dailyPrayerStatusProvider);
    final prayerTimes =
        ref.watch(prayerTimesProvider.select((s) => s.prayerTimes));
    final hasAnyData = tracking.byDate.keys
        .any((d) => d.year == _focusedDay.year && d.month == _focusedDay.month);

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
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatisticsCards(
                    context, isDark, isArabic, tracking, prayerTimes),
                SizedBox(
                    height:
                        ts.scale(AppConstants.paddingLarge).clamp(0.0, 28.0)),
                _buildCalendar(
                    context, isDark, isArabic, tracking, prayerTimes),
                SizedBox(
                    height:
                        ts.scale(AppConstants.paddingLarge).clamp(0.0, 28.0)),
                if (!_isLoading && !hasAnyData)
                  EmptyState(
                    iconEmoji: '🕌',
                    title: isArabic
                        ? 'لا توجد سجلات هذا الشهر'
                        : 'No prayer records this month',
                    subtitle: isArabic
                        ? 'ابدأ بتسجيل صلواتك لبناء سلسلتك'
                        : 'Start marking your prayers to build your streak',
                  ),
                if (_selectedDay != null)
                  _buildDayDetails(context, _selectedDay!, isDark, isArabic,
                      tracking, prayerTimes),
                SizedBox(height: ts.scale(80.0)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatisticsCards(BuildContext context, bool isDark, bool isArabic,
      DailyPrayerStatus tracking, List<PrayerTime> prayerTimes) {
    final ts = MediaQuery.textScalerOf(context);
    final now = DateTime.now();
    final today = _d(now);
    final startOfMonth = DateTime(now.year, now.month, 1);

    int totalPrayers = 0;
    int completedPrayers = 0;
    int onTimePrayers = 0;

    for (DateTime day = startOfMonth;
        !day.isAfter(today);
        day = day.add(const Duration(days: 1))) {
      final statuses = _displayStatuses(day, tracking, prayerTimes);
      for (final prayerName in kPrayerNames) {
        totalPrayers++;
        final status = statuses[prayerName];
        if (status == PrayerStatus.onTime || status == PrayerStatus.late) {
          completedPrayers++;
        }
        if (status == PrayerStatus.onTime) {
          onTimePrayers++;
        }
      }
    }

    final completionRate =
        totalPrayers > 0 ? (completedPrayers / totalPrayers * 100).round() : 0;
    final onTimeRate =
        totalPrayers > 0 ? (onTimePrayers / totalPrayers * 100).round() : 0;
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
                value: NumberFormatter.withArabicNumeralsByLanguage(
                    '$streak', isArabic ? 'ar' : 'en'),
                color: Colors.orange,
                isDark: isDark,
              ),
            ),
            SizedBox(
                width: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                label: isArabic ? 'إتمام' : 'Complete',
                value: NumberFormatter.withArabicNumeralsByLanguage(
                    '$completionRate%', isArabic ? 'ar' : 'en'),
                color: Colors.green,
                isDark: isDark,
              ),
            ),
            SizedBox(
                width: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
            Expanded(
              child: _StatCard(
                icon: Icons.schedule,
                label: isArabic ? 'في الوقت' : 'On Time',
                value: NumberFormatter.withArabicNumeralsByLanguage(
                    '$onTimeRate%', isArabic ? 'ar' : 'en'),
                color: AppConstants.getPrimary(isDark),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, bool isDark, bool isArabic,
      DailyPrayerStatus tracking, List<PrayerTime> prayerTimes) {
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
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
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
                  _selectedDay = _d(selectedDay);
                  _focusedDay = _d(focusedDay);
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadData();
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
                return _isDayComplete(_d(day), tracking, prayerTimes)
                    ? ['completed']
                    : [];
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
    DailyPrayerStatus tracking,
    List<PrayerTime> todayPrayerTimes,
  ) {
    final normalizedDay = _d(day);
    final today = _d(DateTime.now());
    final isPastDay = normalizedDay.isBefore(today);
    final isToday = normalizedDay == today;

    final prayerNames = kPrayerNames;
    final prayerDisplayNames = {
      'Fajr': isArabic ? 'الفجر' : 'Fajr',
      'Zuhr': isArabic ? 'الظهر' : 'Zuhr',
      'Asr': isArabic ? 'العصر' : 'Asr',
      'Maghrib': isArabic ? 'المغرب' : 'Maghrib',
      'Isha': isArabic ? 'العشاء' : 'Isha',
    };
    final prayerEmojis = {
      'Fajr': '🌙',
      'Zuhr': '☀️',
      'Asr': '🌤️',
      'Maghrib': '🌇',
      'Isha': '🌃',
    };

    final displayed =
        _displayStatuses(normalizedDay, tracking, todayPrayerTimes);

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
          SizedBox(
              height: ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0)),
          ...prayerNames.map((prayerName) {
            final displayName = prayerDisplayNames[prayerName]!;
            final emoji = prayerEmojis[prayerName]!;
            final status = displayed[prayerName];

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
    final isCompleted =
        status == PrayerStatus.onTime || status == PrayerStatus.late;
    final isExplicitlyMissed =
        status == PrayerStatus.excused || status == PrayerStatus.missed;

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
          padding: EdgeInsets.symmetric(
              horizontal: ts.scale(12.0), vertical: ts.scale(10.0)),
          decoration: BoxDecoration(
            color:
                showBadge ? badgeColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: showBadge
                ? Border.all(color: badgeColor.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Text(emoji,
                  style: TextStyle(fontSize: ts.scale(20.0)),
                  textScaler: TextScaler.noScaling),
              SizedBox(width: ts.scale(12.0)),
              Expanded(
                child: Text(
                  displayName,
                  style: AppTypography.bodyL.copyWith(
                    fontWeight: showBadge ? FontWeight.w600 : FontWeight.normal,
                    color: AppConstants.textPrimary(isDark),
                  ),
                ),
              ),
              if (showBadge)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: ts.scale(10.0), vertical: ts.scale(4.0)),
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
                            : (status == PrayerStatus.late
                                ? Icons.schedule
                                : Icons.check_circle),
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
                  padding: EdgeInsets.symmetric(
                      horizontal: ts.scale(10.0), vertical: ts.scale(4.0)),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radio_button_unchecked,
                          color: AppConstants.textDisabled(isDark),
                          size: ts.scale(16.0)),
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
    final notifier = ref.read(dailyPrayerStatusProvider.notifier);
    final calendarDate = _d(date);
    final realToday = _d(DateTime.now());
    final eff = notifier.computeEffectiveToday();
    final prayerTimes = ref.read(prayerTimesProvider).prayerTimes;

    try {
      if (currentStatus != null) {
        // ── Unmark ──────────────────────────────────────────────────────────
        final confirmed = await showUnmarkConfirmDialog(
          context: context,
          prayerName: prayerName,
          isArabic: isArabic,
        );
        if (confirmed != true || !mounted) return;

        final deleted = await notifier.unmarkDate(calendarDate, prayerName);
        if (!deleted) {
          haptic.HapticFeedback.error();
          _snack(
              isArabic
                  ? 'فشل إلغاء التسجيل. حاول مرة أخرى.'
                  : 'Failed to unmark. Please try again.',
              color: Colors.red);
          return;
        }
        haptic.HapticFeedback.light();
        await _refreshStreak();
        _snack(
            isArabic ? 'تم إلغاء تسجيل $prayerName' : 'Unmarked $prayerName');
      } else {
        // ── Mark ────────────────────────────────────────────────────────────
        // A future day (whose prayers haven't happened) can never be recorded.
        if (calendarDate.isAfter(eff)) {
          _snack(
            isArabic
                ? 'لا يمكن تسجيل صلاة لم يحن وقتها بعد'
                : "You can't record a prayer before its time",
            color: Colors.orange,
          );
          return;
        }
        // For the actual calendar today, surface the 20-minute countdown message.
        if (calendarDate == realToday &&
            !canMarkPrayer(
                context: context,
                prayerName: prayerName,
                prayerTimes: prayerTimes,
                isArabic: isArabic)) {
          return;
        }

        final chosenStatus = await showPrayerStatusDialog(
          context: context,
          prayerName: prayerName,
          isArabic: isArabic,
        );
        if (chosenStatus == null) return;

        final success =
            await notifier.markDate(calendarDate, prayerName, chosenStatus);
        if (!success) {
          haptic.HapticFeedback.error();
          _snack(
              isArabic
                  ? 'فشل تسجيل $prayerName. حاول مرة أخرى.'
                  : 'Failed to record $prayerName. Please try again.',
              color: Colors.red);
          return;
        }
        haptic.HapticFeedback.success();
        await _refreshStreak();
        final forYesterday = calendarDate == eff && eff != realToday;
        _snack(
          forYesterday
              ? (isArabic
                  ? 'تم تسجيل $prayerName ليوم أمس'
                  : 'Recorded $prayerName for yesterday')
              : (isArabic ? 'تم تسجيل $prayerName' : 'Recorded $prayerName'),
          color: Colors.green,
        );
      }
    } catch (e) {
      debugPrint('Error toggling prayer status: $e');
      haptic.HapticFeedback.error();
      _snack(isArabic ? 'خطأ: $e' : 'Error: $e', color: Colors.red, seconds: 3);
    }
  }

  void _snack(String message, {Color? color, int? seconds}) {
    if (!mounted) return;
    final duration =
        Duration(milliseconds: seconds != null ? seconds * 1000 : 800);
    final ctrl = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      ),
    );
    Future.delayed(duration, ctrl.close);
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

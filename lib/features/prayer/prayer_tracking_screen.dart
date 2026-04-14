import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/prayer_record.dart';
import '../../core/models/prayer_time.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/utils/haptic_feedback.dart' as haptic;
import '../../core/widgets/prayer_status_dialog.dart';
import '../../core/utils/prayer_time_rules.dart';
import '../../core/utils/number_formatter.dart';

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
  Map<DateTime, DailyPrayerSummary> _monthlyData = {};
  bool _isLoading = false;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
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
      body: RefreshIndicator(
        onRefresh: _loadMonthData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Statistics cards
              _buildStatisticsCards(context, isDark, isArabic),

              const SizedBox(height: AppConstants.paddingLarge),

              // Calendar
              _buildCalendar(context, isDark, isArabic),

              const SizedBox(height: AppConstants.paddingLarge),

              // Selected day details
              if (_selectedDay != null)
                _buildDayDetails(context, _selectedDay!, isDark, isArabic),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(BuildContext context, bool isDark, bool isArabic) {
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
        const SizedBox(height: AppConstants.paddingMedium),
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
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                label: isArabic ? 'إتمام' : 'Complete',
                value: NumberFormatter.withArabicNumeralsByLanguage('$completionRate%', isArabic ? 'ar' : 'en'),
                color: Colors.green,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: _StatCard(
                icon: Icons.schedule,
                label: isArabic ? 'في الوقت' : 'On Time',
                value: NumberFormatter.withArabicNumeralsByLanguage('$onTimeRate%', isArabic ? 'ar' : 'en'),
                color: AppConstants.primaryColor,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, bool isDark, bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'التقويم' : 'Calendar',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
            ),
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
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
                color: AppConstants.primaryColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppConstants.primaryColor,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              weekendTextStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: isDark ? Colors.white : Colors.black87,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              weekendStyle: TextStyle(
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
      ],
    );
  }

  Widget _buildDayDetails(
    BuildContext context,
    DateTime day,
    bool isDark,
    bool isArabic,
  ) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isPastDay = normalizedDay.isBefore(today);
    final isToday = normalizedDay == today;

    final summary = _monthlyData[normalizedDay];
    // Build prayer statuses from summary or default to missed
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

    // Get existing statuses or default to missed
    final Map<String, PrayerStatus> statuses = {};
    for (final name in prayerNames) {
      statuses[name] = summary?.prayers[name] ?? PrayerStatus.missed;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
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
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          ...prayerNames.map((prayerName) {
            final displayName = prayerDisplayNames[prayerName]!;
            final emoji = prayerEmojis[prayerName]!;
            final status = statuses[prayerName]!;

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
    required PrayerStatus status,
    required DateTime date,
    required bool isDark,
    required bool isArabic,
  }) {
    final isCompleted = status == PrayerStatus.onTime || status == PrayerStatus.late;
    final isExplicitlyMissed = status == PrayerStatus.excused;

    final showBadge = isCompleted || isExplicitlyMissed;
    final badgeColor = isExplicitlyMissed
        ? Colors.red
        : (status == PrayerStatus.late ? Colors.orange : Colors.green);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _togglePrayerStatus(prayerName, date, status, isArabic),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),

              // Prayer name
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: showBadge ? FontWeight.w600 : FontWeight.normal,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),

              // Status badge
              if (showBadge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExplicitlyMissed
                            ? (isArabic ? 'لم أصلّ' : 'Missed')
                            : status == PrayerStatus.late
                                ? (isArabic ? 'متأخر' : 'Late')
                                : (isArabic ? 'في الوقت' : 'On Time'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radio_button_unchecked,
                          color: isDark ? Colors.white38 : Colors.black38, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? 'غير مُصلّاة' : 'Not Prayed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
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
    PrayerStatus currentStatus,
    bool isArabic,
  ) async {
    final userId = getCurrentUserId();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // For today: check 20-minute rule before allowing mark
    if (normalizedDate == today && currentStatus == PrayerStatus.missed) {
      final prayerState = ref.read(prayerTimesProvider);
      final prayerTimes = prayerState?.prayerTimes ?? [];
      if (!canMarkPrayer(context: context, prayerName: prayerName, prayerTimes: prayerTimes, isArabic: isArabic)) {
        return;
      }
    }

    try {
      if (currentStatus == PrayerStatus.onTime || currentStatus == PrayerStatus.late || currentStatus == PrayerStatus.excused) {
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
          date: normalizedDate,
        );

        if (!deleted) {
          haptic.HapticFeedback.error();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic
                      ? 'فشل إلغاء التسجيل. حاول مرة أخرى.'
                      : 'Failed to unmark. Please try again.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Immediately update local data
        haptic.HapticFeedback.light();
        setState(() {
          final dayKey = normalizedDate;
          final existing = _monthlyData[dayKey];
          if (existing != null) {
            final updatedPrayers = Map<String, PrayerStatus>.from(existing.prayers);
            updatedPrayers[prayerName] = PrayerStatus.missed;
            _monthlyData[dayKey] = DailyPrayerSummary(
              date: normalizedDate,
              prayers: updatedPrayers,
            );
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic ? 'تم إلغاء تسجيل $prayerName' : 'Unmarked $prayerName',
              ),
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
            ),
          );
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
          date: normalizedDate,
          prayedAt: DateTime.now(),
          status: chosenStatus,
          method: PrayerMethod.congregation,
        );

        if (!success) {
          haptic.HapticFeedback.error();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic
                      ? 'فشل تسجيل $prayerName. حاول مرة أخرى.'
                      : 'Failed to record $prayerName. Please try again.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Immediately update local data
        haptic.HapticFeedback.success();
        setState(() {
          final dayKey = normalizedDate;
          final existing = _monthlyData[dayKey];
          if (existing != null) {
            final updatedPrayers = Map<String, PrayerStatus>.from(existing.prayers);
            updatedPrayers[prayerName] = chosenStatus;
            _monthlyData[dayKey] = DailyPrayerSummary(
              date: normalizedDate,
              prayers: updatedPrayers,
            );
          } else {
            // Create new entry for this day
            final newPrayers = {for (final p in kPrayerNames) p: PrayerStatus.missed};
            newPrayers[prayerName] = chosenStatus;
            _monthlyData[dayKey] = DailyPrayerSummary(
              date: normalizedDate,
              prayers: newPrayers,
            );
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic ? 'تم تسجيل $prayerName' : 'Recorded $prayerName',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling prayer status: $e');
      haptic.HapticFeedback.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ: $e' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/daily_prayer_status_provider.dart';
import '../../core/providers/task_provider.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/greeting_widget.dart';
import '../../core/widgets/permission_dialog.dart';
import '../../core/widgets/task_card.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/services/task_service.dart';
import '../../core/models/task.dart';
import '../../core/models/prayer_record.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdownTimer;

  // ValueNotifier for countdown - only rebuilds the countdown widget, not entire screen
  final ValueNotifier<Duration> _countdownNotifier = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    // Load prayer statuses via shared provider (cached, won't hit Firestore if fresh)
    Future.microtask(() => ref.read(dailyPrayerStatusProvider.notifier).load());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final prayer = ref.read(prayerTimesProvider).nextPrayer;
      if (prayer == null) return;
      final diff = prayer.time.difference(DateTime.now());
      _countdownNotifier.value = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownNotifier.dispose();
    super.dispose();
  }

  String _formatCountdown(Duration remaining, bool isArabic) {
    if (remaining == Duration.zero) return '--:--';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    String text;
    if (h > 0) {
      text = isArabic
          ? '$h س ${m.toString().padLeft(2, '0')} د'
          : '${h}h ${m.toString().padLeft(2, '0')}m';
    } else if (m > 0) {
      text = isArabic
          ? '$m د ${s.toString().padLeft(2, '0')} ث'
          : '${m}m ${s.toString().padLeft(2, '0')}s';
    } else {
      text = isArabic ? '$s ث' : '${s}s';
    }
    if (isArabic) text = NumberFormatter.withArabicNumeralsByLanguage(text, 'ar');
    return text;
  }

  String _getPrayerEmoji(String name) {
    switch (name.toLowerCase()) {
      case 'fajr': return '🌙';
      case 'sunrise': return '🌅';
      case 'dhuhr':
      case 'zuhr': return '☀️';
      case 'asr': return '🌤️';
      case 'maghrib': return '🌇';
      case 'isha': return '🌃';
      default: return '🕌';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final prayerState = ref.watch(prayerTimesProvider);

    final user = ref.watch(currentUserProvider);
    final userName = user?.displayName ?? 'User';
    final isGuest = ref.watch(guestModeProvider.select((async) => async.value ?? false));

    // Calculate prayer progress from shared provider
    final prayerStatuses = ref.watch(dailyPrayerStatusProvider).statuses;
    final trackablePrayers = kPrayerNames;
    final completedCount = trackablePrayers.where((p) {
      final status = prayerStatuses[p];
      return status == PrayerStatus.onTime || status == PrayerStatus.late;
    }).length;
    final totalPrayers = trackablePrayers.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aura | هالة'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          ConnectivityWrapper(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Greeting Section
                    GreetingWidget(
                      userName: isGuest ? null : userName,
                      onTap: () => Navigator.of(context).pushNamed('/prayer'),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Next Prayer Mini Card
                    _buildNextPrayerCard(context, prayerState, isDark, isArabic, completedCount, totalPrayers)
                        .animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: AppConstants.paddingMedium),

                    // Prayer Progress Bar
                    _buildPrayerProgress(context, isDark, isArabic, completedCount, totalPrayers, prayerStatuses)
                        .animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Task Progress Ring
                    _buildTaskProgress(context, isDark, isArabic),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Today's Tasks Preview
                    _buildTodayTasksPreview(context, isDark, isArabic)
                        .animate().fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Footer
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                        child: Text(
                          'version'.tr() + ' 1.0.2',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ),

                    // Bottom padding for nav bar
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // Permission dialog handler (shows dialogs after home loads)
          const PermissionDialogHandler(),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard(
    BuildContext context,
    PrayerTimesState? prayerState,
    bool isDark,
    bool isArabic,
    int completedCount,
    int totalPrayers,
  ) {
    final nextPrayer = prayerState?.nextPrayer;
    final hasData = nextPrayer != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/prayer'),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: isDark
                ? AppConstants.primaryColor.withOpacity(0.12)
                : AppConstants.primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Prayer emoji
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        hasData ? _getPrayerEmoji(nextPrayer.name) : '🕌',
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),

                  // Prayer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الصلاة القادمة' : 'Next Prayer',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasData
                              ? (isArabic ? nextPrayer.nameAr : nextPrayer.name)
                              : (isArabic ? 'جاري التحميل...' : 'Loading...'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Countdown
                  ValueListenableBuilder<Duration>(
                    valueListenable: _countdownNotifier,
                    builder: (context, remaining, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCountdown(remaining, isArabic),
                            style: TextStyle(
                              color: AppConstants.primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic ? 'حتى الأذان' : 'Until Adhan',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingMedium),

              // Prayer time
              if (hasData) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: AppConstants.primaryColor.withOpacity(0.7), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isArabic
                                ? NumberFormatter.withArabicNumeralsByLanguage(
                                    nextPrayer.time12h.replaceAll('AM', 'ص').replaceAll('PM', 'م'), 'ar')
                                : nextPrayer.time12h,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppConstants.primaryColor.withOpacity(0.7), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isArabic
                                ? '$completedCount من $totalPrayers'
                                : '$completedCount/$totalPrayers',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerProgress(
    BuildContext context,
    bool isDark,
    bool isArabic,
    int completedCount,
    int totalPrayers,
    Map<String, PrayerStatus> prayerStatuses,
  ) {
    final progress = totalPrayers > 0 ? completedCount / totalPrayers : 0.0;

    final prayerIcons = ['🌙', '☀️', '🌤️', '🌇', '🌃'];
    final trackablePrayers = kPrayerNames;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
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
                isArabic ? 'تقدم الصلوات اليوم' : "Today's Prayer Progress",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                isArabic
                    ? NumberFormatter.withArabicNumeralsByLanguage('$completedCount/${kPrayerNames.length}', 'ar')
                    : '$completedCount/${kPrayerNames.length}',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : AppConstants.primaryColor,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingSmall),

          // Prayer status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(trackablePrayers.length, (i) {
              final status = prayerStatuses[trackablePrayers[i]];
              final isTracked = status != null;

              // Match prayer_status_dialog.dart icon/color style
              Color color;
              IconData icon;
              if (status == PrayerStatus.onTime) {
                color = Colors.green;
                icon = Icons.check_circle;
              } else if (status == PrayerStatus.late) {
                color = Colors.orange;
                icon = Icons.schedule;
              } else if (status == PrayerStatus.excused) {
                // "Missed" in dialog stores as excused with red cancel icon
                color = Colors.red;
                icon = Icons.cancel;
              } else {
                color = isDark ? AppConstants.darkBorder : AppConstants.lightBorder;
                icon = Icons.circle_outlined;
              }

              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTracked
                          ? color.withValues(alpha: 0.15)
                          : (isDark ? AppConstants.darkSurface : Colors.grey[100]),
                      border: Border.all(
                        color: isTracked ? color : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isTracked
                          ? Icon(icon, color: color, size: 20)
                          : Text(prayerIcons[i], style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'][i]
                        : kPrayerNames[i],
                    style: TextStyle(
                      fontSize: 9,
                      color: isTracked
                          ? color
                          : (isDark ? Colors.white54 : Colors.black54),
                      fontWeight: isTracked ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskProgress(BuildContext context, bool isDark, bool isArabic) {
    final statsAsync = ref.watch(taskStatisticsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.total == 0) return const SizedBox.shrink();

        // Show TODAY's task completion progress
        final allTasksAsync = ref.watch(allTasksProvider);
        return allTasksAsync.when(
          data: (allTasks) {
            final todayTasks = allTasks.where((t) => t.isDueToday).toList();
            final todayDone = todayTasks.where((t) => t.isCompleted).length;
            final todayTotal = todayTasks.length;
            final progress = todayTotal > 0 ? todayDone / todayTotal : 0.0;
            final percentage = (progress * 100).round();

        return Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          ),
          child: Row(
            children: [
              // Progress ring
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.green : AppConstants.primaryColor,
                      ),
                    ),
                    Center(
                      child: Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'تقدم المهام' : 'Task Progress',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildMiniStat(Icons.today, '$todayTotal',
                            isArabic ? 'اليوم' : 'Today', AppConstants.primaryColor),
                        const SizedBox(width: 16),
                        _buildMiniStat(Icons.check_circle, '$todayDone',
                            isArabic ? 'مكتمل' : 'Done', Colors.green),
                        const SizedBox(width: 16),
                        _buildMiniStat(Icons.warning_amber_rounded, '${stats.overdue}',
                            isArabic ? 'متأخرة' : 'Late', stats.overdue > 0 ? Colors.red : Colors.grey),
                        const SizedBox(width: 16),
                        FutureBuilder<int>(
                          future: _getStreak(),
                          builder: (_, snap) => _buildMiniStat(Icons.local_fire_department,
                              '${snap.data ?? 0}',
                              isArabic ? 'سلسلة' : 'Streak',
                              (snap.data ?? 0) > 0 ? Colors.orange : Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildTodayTasksPreview(BuildContext context, bool isDark, bool isArabic) {
    final allTasksAsync = ref.watch(allTasksProvider);
    final statsAsync = ref.watch(taskStatisticsProvider);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'مهام اليوم' : "Today's Tasks",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to main Tasks tab (index 2 in bottom nav)
                  ref.read(tabNavigationProvider.notifier).state = 2;
                },
                child: Text(
                  isArabic ? 'عرض الكل' : 'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Progress bar
          statsAsync.when(
            data: (stats) {
              if (stats.dueToday == 0) return const SizedBox(height: 8);
              final done = (stats.completed).clamp(0, stats.dueToday);
              final progress = stats.dueToday > 0 ? done / stats.dueToday : 0.0;
              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor:
                            isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.green : AppConstants.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic
                          ? '$done من ${stats.dueToday} مكتملة'
                          : '$done of ${stats.dueToday} completed',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 8),
            error: (_, __) => const SizedBox(height: 8),
          ),

          const SizedBox(height: 4),

          // Task list
          allTasksAsync.when(
            data: (allTasks) {
              final todayTasks =
                  allTasks.where((t) => !t.isCompleted && t.isDueToday).toList();
              final upcomingTasks =
                  allTasks.where((t) => !t.isCompleted && t.isUpcoming).toList();
              final toShow = todayTasks.isNotEmpty ? todayTasks : upcomingTasks;

              if (toShow.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 22, color: Colors.green.shade400),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'أنجزت كل مهام اليوم!' : 'All done for today!',
                        style: TextStyle(
                          color:
                              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (todayTasks.isEmpty && upcomingTasks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        isArabic ? 'قريباً' : 'Upcoming',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ...toShow.take(3).map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: TaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onTap: () => _editTask(task),
                          onToggle: () => _toggleTask(task.id),
                        ),
                      )),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTask(String taskId) async {
    final userId = getCurrentUserId();
    try {
      // Check if this is the last today task before toggling
      final tasks = ref.read(allTasksProvider).valueOrNull ?? [];
      final todayIncomplete = tasks.where((t) => t.isDueToday && !t.isCompleted);
      final wasLastTask = todayIncomplete.length == 1 && todayIncomplete.first.id == taskId;

      await TaskService.instance.toggleTaskCompletion(
        userId: userId,
        taskId: taskId,
      );

      // Refresh providers so stats update immediately
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);

      // If this was the last today task, increment streak
      if (wasLastTask) {
        await _incrementStreak();
        setState(() {}); // Refresh to show updated streak
      }
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _editTask(Task task) async {
    final result = await Navigator.of(context).pushNamed(
      '/task_form',
      arguments: task,
    );
    if (result == true) {
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);
    }
  }

  // ─── Task Streak ──────────────────────────────────────────────────────────

  static const _streakKey = 'task_streak_count';
  static const _streakDateKey = 'task_streak_date';

  Future<int> _getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_streakKey) ?? 0;
    final lastDate = prefs.getString(_streakDateKey);
    if (lastDate == null) return 0;

    // If last date is not today or yesterday, streak is broken
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    if (lastDate != today && lastDate != yesterdayStr) {
      // Streak broken
      await prefs.setInt(_streakKey, 0);
      return 0;
    }
    return count;
  }

  Future<void> _incrementStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastDate = prefs.getString(_streakDateKey);

    if (lastDate == today) return; // Already counted today

    final count = prefs.getInt(_streakKey) ?? 0;
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final newCount = (lastDate == yesterdayStr) ? count + 1 : 1;
    await prefs.setInt(_streakKey, newCount);
    await prefs.setString(_streakDateKey, today);
  }

  Widget _buildDailyProgressRing(BuildContext context, bool isDark, bool isArabic, int completed, int total) {
    final progress = total > 0 ? completed / total : 0.0;
    final percentage = (progress * 100).round();
    final displayPercentage = isArabic
        ? NumberFormatter.withArabicNumerals('$percentage')
        : '$percentage';

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'تقدم اليوم' : "Today's Progress",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              // Progress ring
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.green : AppConstants.primaryColor,
                      ),
                    ),
                    Center(
                      child: Text(
                        '$displayPercentage%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              // Prayer dots
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: kPrayerNames.map((name) {
                    final prayerEmojis = {
                      'Fajr': '🌙', 'Zuhr': '☀️', 'Asr': '🌤️', 'Maghrib': '🌇', 'Isha': '🌃',
                    };
                    final prayerNamesAr = {
                      'Fajr': 'الفجر', 'Zuhr': 'الظهر', 'Asr': 'العصر', 'Maghrib': 'المغرب', 'Isha': 'العشاء',
                    };
                    final displayName = isArabic ? (prayerNamesAr[name] ?? name) : name;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(prayerEmojis[name] ?? '🕌', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(displayName, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDark, bool isArabic) {
    return FutureBuilder<List<PrayerRecord>>(
      future: _getRecentRecords(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final records = snapshot.data!.take(3).toList();
        final prayerEmojis = {
          'Fajr': '🌙', 'Zuhr': '☀️', 'Asr': '🌤️', 'Maghrib': '🌇', 'Isha': '🌃',
        };

        return Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'النشاط الأخير' : 'Recent Activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              ...records.map((record) {
                final statusIcon = record.status == PrayerStatus.onTime
                    ? Icons.check_circle
                    : record.status == PrayerStatus.late
                        ? Icons.schedule
                        : Icons.cancel;
                final statusColor = record.status == PrayerStatus.onTime
                    ? Colors.green
                    : record.status == PrayerStatus.late
                        ? Colors.orange
                        : Colors.red;
                final statusText = record.status == PrayerStatus.onTime
                    ? (isArabic ? 'في الوقت' : 'On Time')
                    : record.status == PrayerStatus.late
                        ? (isArabic ? 'متأخر' : 'Late')
                        : (isArabic ? 'معذور' : 'Excused');
                final timeStr = '${record.prayedAt.hour}:${record.prayedAt.minute.toString().padLeft(2, '0')}';
                final displayTime = isArabic ? NumberFormatter.withArabicNumerals(timeStr) : timeStr;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(prayerEmojis[record.prayerName] ?? '🕌', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabic ? record.prayerName : record.prayerName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        displayTime,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<List<PrayerRecord>> _getRecentRecords() async {
    try {
      final userId = getCurrentUserId();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      return await PrayerTrackingService.instance.getPrayersForDateRange(
        userId: userId,
        startDate: startOfDay,
        endDate: now,
      );
    } catch (_) {
      return [];
    }
  }
}

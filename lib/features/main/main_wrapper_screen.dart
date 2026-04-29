import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/utils/haptic_feedback.dart' as app_haptic;
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/task_provider.dart';
import '../../core/services/task_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/prayer_alarm_service.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/models/prayer_record.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/achievement.dart';
import '../../core/providers/daily_prayer_status_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/shared_preferences_service.dart';
import '../home/home_screen.dart';
import '../prayer/prayer_screen.dart';
import '../profile/profile_screen.dart';
import '../quran/quran_home_screen.dart';
import '../quran/quran_reader_screen.dart';
import '../tasks/tasks_screen.dart';

/// Main wrapper screen with TabController
class MainWrapperScreen extends ConsumerStatefulWidget {
  const MainWrapperScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends ConsumerState<MainWrapperScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late int _currentIndex;
  StreamSubscription<Achievement>? _achievementSub;

  // PageController for smooth page transitions
  final PageController _pageController = PageController();
  bool _isPageViewDragging = false;

  // Back to exit functionality
  DateTime? _lastBackPressTime;
  static const Duration _doubleTapDuration = Duration(seconds: 2);

  // Platform channel for navigation communication
  static const _navigationChannel = MethodChannel('com.aura.hala/navigation');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check untracked prayers BEFORE invalidating provider (would clear prayer times)
      _checkUntrackedPrayers();
      ref.invalidate(prayerTimesProvider);
      ref.invalidate(tasksProvider(const TaskFilterParams()));
      _handleWidgetIntent();
      _syncNativePrayerStatuses();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _tabController = TabController(length: 5, vsync: this);
    _tabController.index = _currentIndex;
    _updateCurrentRoute();

    // Listen for newly earned achievements and show a toast
    _achievementSub = AchievementService.instance.newAchievements.listen((achievement) {
      if (!mounted) return;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      _showAchievementToast(achievement, isArabic);
    });

    // Listen for tab navigation requests from child screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<int>(tabNavigationProvider, (prev, next) {
        if (next >= 0 && next != _currentIndex) {
          _handleTabTap(next);
          // Reset provider so it can be triggered again
          ref.read(tabNavigationProvider.notifier).state = -1;
        }
      });
      _handleWidgetIntent();
      _scheduleDailySummaryOnStartup();
      // On cold start, prayer times need time to load — check after a short delay
      Future.delayed(const Duration(seconds: 3), _checkUntrackedPrayers);
    });

    // Listen for app shortcut navigation from native side
    _navigationChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigateToRoute') {
        final route = call.arguments['route'] as String?;
        if (route != null && mounted) {
          Navigator.of(context).pushNamed(route);
        }
      } else if (call.method == 'openReminderPicker') {
        final prayerName = call.arguments['prayerName'] as String? ?? '';
        final prayerNameAr = call.arguments['prayerNameAr'] as String? ?? prayerName;
        final prayerTime = (call.arguments['prayerTime'] as num?)?.toInt() ?? 0;
        if (mounted) {
          _showReminderPicker(prayerName, prayerNameAr, prayerTime);
        }
      } else if (call.method == 'openPostPrayerPicker') {
        final prayerName = call.arguments['prayerName'] as String? ?? '';
        final prayerNameAr = call.arguments['prayerNameAr'] as String? ?? prayerName;
        final prayerTime = (call.arguments['prayerTime'] as num?)?.toInt() ?? 0;
        if (mounted) {
          _showPostPrayerReminderPicker(prayerName, prayerNameAr, prayerTime);
        }
      } else if (call.method == 'updatePrayerStatus') {
        final prayerName = call.arguments['prayerName'] as String? ?? '';
        final statusStr = call.arguments['status'] as String? ?? '';
        if (prayerName.isNotEmpty && statusStr.isNotEmpty) {
          await _recordPrayerStatusFromNotification(prayerName, statusStr);
        }
      } else if (call.method == 'openQuranReader') {
        if (mounted) {
          // Switch to Quran tab first
          _handleTabTap(2);
          // Then push reader with last page
          final prefs = await SharedPreferences.getInstance();
          final currentPage = prefs.getInt('quran_current_page') ?? 1;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuranReaderScreen(initialPage: currentPage),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _achievementSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showAchievementToast(Achievement achievement, bool isArabic) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AchievementToast(
        achievement: achievement,
        isArabic: isArabic,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _handleWidgetIntent() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Handle tap-to-complete from widget
      final taskId = prefs.getString('pending_complete_task_id');
      if (taskId != null && taskId.isNotEmpty) {
        prefs.remove('pending_complete_task_id');
        final userId = ref.read(currentUserIdProvider);
        await TaskService.instance.toggleTaskCompletion(userId: userId, taskId: taskId);
        debugPrint('✅ Widget tap-to-complete: toggled task $taskId');
      }

      // Handle quick-add from widget "+" button
      final openForm = prefs.getBool('widget_open_task_form');
      if (openForm == true) {
        prefs.remove('widget_open_task_form');
        if (mounted) {
          Navigator.of(context).pushNamed('/task_form');
        }
      }
    } catch (e) {
      debugPrint('Widget intent error: $e');
    }
  }

  Future<void> _syncNativePrayerStatuses() async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null && userId.isNotEmpty) {
        await PrayerAlarmService.instance.syncNativePrayerStatuses(userId);
      }
    } catch (e) {
      debugPrint('Error syncing native prayer statuses: $e');
    }
  }

  Future<void> _scheduleDailySummaryOnStartup() async {
    try {
      final prefs = SharedPreferencesService.instance;
      final enabled = await prefs.isPrayerTrackingEnabled();
      if (!enabled) return;
      final timeStr = await prefs.getDailySummaryTime();
      await PrayerAlarmService.instance.scheduleDailySummary(timeStr);
    } catch (e) {
      debugPrint('Error scheduling daily summary: $e');
    }
  }

  bool _untrackedCheckInProgress = false;

  Future<void> _checkUntrackedPrayers() async {
    if (_untrackedCheckInProgress) return;
    _untrackedCheckInProgress = true;
    try {
      final prefs = SharedPreferencesService.instance;
      final enabled = await prefs.isPrayerTrackingEnabled();
      if (!enabled) return;

      final userId = ref.read(currentUserProvider)?.uid;
      if (userId == null || userId.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final prayerState = ref.read(prayerTimesProvider);
      if (prayerState.prayerTimes.isEmpty) return;

      // Past prayers = prayers whose adhan time has already passed (excluding Sunrise)
      final pastPrayers = prayerState.prayerTimes
          .where((p) => p.name != 'Sunrise' && p.time.isBefore(now))
          .toList();
      if (pastPrayers.isEmpty) return;

      // Fetch today's tracked records
      final tracked = await PrayerTrackingService.instance.getPrayersForDate(
        userId: userId,
        date: today,
      );
      final trackedNames = tracked.map((r) => r.prayerName.toLowerCase()).toSet();

      final List<PrayerTime> untracked = pastPrayers
          .where((p) => !trackedNames.contains(p.name.toLowerCase()))
          .toList();

      if (untracked.isEmpty) return;

      if (!mounted) return;
      _showUntrackedPrayersSheet(untracked);
    } catch (e) {
      debugPrint('Error checking untracked prayers: $e');
    } finally {
      _untrackedCheckInProgress = false;
    }
  }

  void _showUntrackedPrayersSheet(List<PrayerTime> untrackedPrayers) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Mutable copy — rows are removed one-by-one as the user handles each prayer
    final remaining = List<PrayerTime>.from(untrackedPrayers);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1B1E) : const Color(0xFFFFF8EB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isArabic ? 'صلوات لم تُسجَّل' : 'Untracked Prayers',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
                Text(
                  isArabic ? 'كيف أدّيت هذه الصلوات؟' : 'How did you perform these prayers?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 16),
                ...remaining.map((prayer) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          isArabic ? prayer.nameAr : prayer.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        ...[
                          ('on_time', isArabic ? 'في وقتها' : 'On Time', AppConstants.primaryColor),
                          ('late', isArabic ? 'متأخر' : 'Late', Colors.orange),
                          ('missed', isArabic ? 'فاتت' : 'Missed', Colors.red),
                        ].map((option) {
                          final (statusStr, label, color) = option;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: TextButton(
                              onPressed: () async {
                                setSheetState(() => remaining.remove(prayer));
                                await _recordPrayerStatusFromNotification(prayer.name, statusStr);
                                // Auto-close when all prayers are handled
                                if (remaining.isEmpty && ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: color,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Align(
                  alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      isArabic ? 'لاحقاً' : 'Later',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateCurrentRoute() {
    final route = _currentIndex == 0 ? '/home' : '/tab/$_currentIndex';
    _navigationChannel.invokeMethod('setCurrentRoute', {'route': route});
  }

  void _showReminderPicker(String prayerName, String prayerNameAr, int prayerTime) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final prayerDate = DateTime.fromMillisecondsSinceEpoch(prayerTime);
    final minutesUntilAzan = prayerDate.difference(now).inMinutes;

    final options = [5, 10, 15, 20, 25, 30]
        .where((m) => m < minutesUntilAzan)
        .toList();

    if (options.isEmpty) {
      // Too close to azan, no remind-later options
      return;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1B1E) : const Color(0xFFFFF3D6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Text(
          isArabic
              ? 'ذكّرني لاحقاً - $prayerNameAr'
              : 'Remind Me Later - $prayerName',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
        ),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: options.map((minutes) {
            final label = isArabic
                ? '${_toArabicNumerals(minutes)} دقيقة'
                : '$minutes min';
            return ChoiceChip(
              label: Text(label),
              selected: false,
              onSelected: (_) {
                Navigator.of(ctx).pop();
                _scheduleRemindLater(prayerName, prayerNameAr, prayerTime, minutes);
              },
              backgroundColor: isDark ? const Color(0xFF2A2B2E) : const Color(0xFFFFEACC),
              selectedColor: AppConstants.primaryColor,
              labelStyle: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF2A2418),
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(color: AppConstants.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleRemindLater(
    String prayerName,
    String prayerNameAr,
    int prayerTime,
    int delayMinutes,
  ) async {
    try {
      // Clear reminder mode so notification returns to normal
      const bgChannel = MethodChannel('com.aura.hala/background_service');
      const alarmChannel = MethodChannel('com.aura.hala/prayer_alarms');

      // 1. Clear reminder active flag (notification goes back to normal)
      final prefs = await SharedPreferences.getInstance();
      // We can't directly write native prefs, so schedule a new alarm
      // that will re-activate reminder mode after delayMinutes
      final newTriggerTime = DateTime.now().add(Duration(minutes: delayMinutes)).millisecondsSinceEpoch;

      // 2. Schedule a re-reminder alarm
      await alarmChannel.invokeMethod('scheduleReminderAlarm', {
        'prayerName': prayerName,
        'prayerNameAr': prayerNameAr,
        'prayerTime': prayerTime,
        'requestCode': 7000 + delayMinutes,
        'delayMinutes': delayMinutes,
      });

      if (mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'سأذكرك بعد ${_toArabicNumerals(delayMinutes)} دقيقة'
                  : 'Will remind you in $delayMinutes minutes',
              textAlign: TextAlign.center,
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppConstants.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling remind later: $e');
    }
  }

  String _toArabicNumerals(int number) {
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? eastern[i] : c;
    }).join('');
  }

  void _showPostPrayerReminderPicker(String prayerName, String prayerNameAr, int prayerTime) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final prayerState = ref.read(prayerTimesProvider);
    final now = DateTime.now();

    // Find minutes until next prayer's adhan
    final prayerOrder = ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'];
    final currentIndex = prayerOrder.indexOf(prayerName);

    int minutesUntilNextAzan = 0;
    String nextPrayerName = '';
    String nextPrayerNameAr = '';

    if (currentIndex >= 0) {
      for (int i = currentIndex + 1; i < prayerOrder.length; i++) {
        final nextName = prayerOrder[i];
        try {
          final nextPrayer = prayerState.prayerTimes.firstWhere(
            (p) => p.name == nextName,
          );
          if (nextPrayer.time.isAfter(now)) {
            minutesUntilNextAzan = nextPrayer.time.difference(now).inMinutes;
            nextPrayerName = nextPrayer.name;
            nextPrayerNameAr = nextPrayer.nameAr;
            break;
          }
        } catch (_) {}
      }
    }

    // Filter: only show delays less than time until next azan
    final allOptions = [5, 10, 15, 20, 30];
    final options = allOptions.where((m) => m < minutesUntilNextAzan).toList();

    if (options.isEmpty) {
      // No time for any reminder
      return;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1B1E) : const Color(0xFFFFF3D6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Text(
          isArabic
              ? 'ذكّرني لاحقاً - $prayerNameAr'
              : 'Remind Me Later - $prayerName',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: options.map((minutes) {
                final label = isArabic
                    ? '${_toArabicNumerals(minutes)} دقيقة'
                    : '$minutes min';
                return ChoiceChip(
                  label: Text(label),
                  selected: false,
                  onSelected: (_) {
                    Navigator.of(ctx).pop();
                    _schedulePostPrayerRemindLater(prayerName, prayerNameAr, prayerTime, minutes);
                  },
                  backgroundColor: isDark ? const Color(0xFF2A2B2E) : const Color(0xFFFFEACC),
                  selectedColor: AppConstants.primaryColor,
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF2A2418),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'صلاة $nextPrayerNameAr ستبدأ بعد ${_toArabicNumerals(minutesUntilNextAzan)} دقيقة'
                  : 'Next $nextPrayerName will start in $minutesUntilNextAzan min',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(color: AppConstants.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordPrayerStatusFromNotification(String prayerName, String statusStr) async {
    final status = switch (statusStr) {
      'on_time' => PrayerStatus.onTime,
      'late' => PrayerStatus.late,
      'missed' => PrayerStatus.missed,
      'excused' => PrayerStatus.excused,
      _ => null,
    };
    if (status == null) return;
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;
    try {
      final now = DateTime.now();
      await PrayerTrackingService.instance.recordPrayer(
        userId: userId,
        prayerName: prayerName,
        date: DateTime(now.year, now.month, now.day),
        prayedAt: now,
        status: status,
      );
      if (mounted) {
        ref.invalidate(dailyPrayerStatusProvider);
        await ref.read(dailyPrayerStatusProvider.notifier).load();
      }
    } catch (e) {
      debugPrint('Error recording prayer from notification: $e');
    }
  }

  Future<void> _schedulePostPrayerRemindLater(
    String prayerName,
    String prayerNameAr,
    int prayerTime,
    int delayMinutes,
  ) async {
    try {
      const alarmChannel = MethodChannel('com.aura.hala/prayer_alarms');
      await alarmChannel.invokeMethod('schedulePostPrayerCheck', {
        'prayerName': prayerName,
        'prayerNameAr': prayerNameAr,
        'prayerTime': DateTime.now().add(Duration(minutes: delayMinutes)).millisecondsSinceEpoch,
        'requestCode': 9000 + delayMinutes,
      });

      if (mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'سأذكرك بعد ${_toArabicNumerals(delayMinutes)} دقيقة'
                  : 'Will remind you in $delayMinutes minutes',
              textAlign: TextAlign.center,
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppConstants.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling post-prayer remind later: $e');
    }
  }

  void _handleTabTap(int index) {
    if (_currentIndex == index) return;

    debugPrint('📍 Tab tapped: from $_currentIndex to $index');
    setState(() {
      _currentIndex = index;
    });
    _tabController.animateTo(index);
    _pageController.jumpToPage(index);
    _updateCurrentRoute();
  }

  /// Handle back button press with double-tap to exit
  Future<bool> _onWillPop() async {
    // If we're not on the first tab (Home), go to previous tab
    if (_currentIndex != 0) {
      _handleTabTap(0);
      return false; // Prevent default back behavior
    }

    // We're on the Home tab - check for double-tap to exit
    final now = DateTime.now();
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < _doubleTapDuration) {
      // Double tap detected - exit the app
      // Use SystemNavigator to actually exit the app
      SystemNavigator.pop();
      return false; // Don't pop since we're exiting
    }

    // First tap - show message
    _lastBackPressTime = now;
    await app_haptic.HapticFeedback.light();

    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final theme = Theme.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'press_again_to_exit'.tr(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          duration: _doubleTapDuration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark
              ? AppConstants.getPrimary(isDark).withOpacity(0.95)
              : AppConstants.getPrimary(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          elevation: 8,
          margin: const EdgeInsets.only(
            bottom: 80,
            left: 20,
            right: 20,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      );
    }

    return false; // Prevent default back behavior
  }

  @override
  Widget build(BuildContext context) {
    // Watch language so wrapper rebuilds when locale changes
    ref.watch(languageProvider);

    // Keep task widget synced
    ref.watch(taskWidgetSyncProvider);

    return PopScope(
      canPop: false, // We handle the back button manually
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            debugPrint('📖 PageView swiped to index: $index');
            app_haptic.HapticFeedback.light();
            setState(() {
              _currentIndex = index;
              _tabController.animateTo(index);
            });
            _updateCurrentRoute();
          },
          children: const [
            HomeScreen(),
            PrayerScreen(),
            QuranHomeScreen(),
            TasksScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: AuraBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _handleTabTap,
        ),
      ),
    );
  }
}

class _AchievementToast extends StatefulWidget {
  final Achievement achievement;
  final bool isArabic;
  final VoidCallback onDone;

  const _AchievementToast({
    required this.achievement,
    required this.isArabic,
    required this.onDone,
  });

  @override
  State<_AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<_AchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _slideAnim = Tween<double>(begin: -80, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
      ),
    );
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: Opacity(
                opacity: _opacityAnim.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppConstants.getPrimary(isDark), AppConstants.accentCyan],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.getPrimary(isDark).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.achievement.iconEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isArabic ? '🏆 إنجاز جديد!' : '🏆 Achievement Unlocked!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.achievement.name(widget.isArabic),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.achievement.description(widget.isArabic),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


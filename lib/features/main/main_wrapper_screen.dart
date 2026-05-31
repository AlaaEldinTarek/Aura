import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/utils/haptic_feedback.dart' as app_haptic;
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/task_provider.dart';
import '../../core/services/task_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/desktop_notification_service.dart';
import '../../core/services/desktop_adhan_service.dart';
import '../../core/services/desktop_prayer_scheduler.dart';
import '../../core/services/prayer_alarm_service.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/utils/prayer_time_rules.dart';
import '../../core/models/prayer_record.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/achievement.dart';
import '../../core/providers/daily_prayer_status_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/guest_migration_provider.dart';
import '../../core/services/shared_preferences_service.dart';
import '../home/home_screen.dart';
import '../prayer/prayer_screen.dart';
import '../prayer/prayer_tracking_screen.dart';
import '../prayer/prayer_report_screen.dart';
import '../dhikl/dhikr_screen.dart';
import '../dhikl/dhikr_stats_screen.dart';
import '../achievements/achievements_screen.dart';
import '../profile/profile_screen.dart';
import '../tasks/tasks_screen.dart';
import '../tasks/task_form_screen.dart';
import '../tasks/task_stats_screen.dart';
import '../settings/iqama_settings_screen.dart';
import '../settings/adhan_downloads_screen.dart';
import '../qibla/qibla_screen.dart';
import '../daily_content/daily_content_screen.dart';
import '../azkar/azkar_screen.dart';
import '../quran/quran_screen.dart';
import '../quran/quran_stats_screen.dart';
import '../islamic_events/islamic_events_screen.dart';
import '../../core/models/task.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aura_button.dart';

/// Desktop-only: controls sidebar visibility (false = hidden, e.g. during Quran reading)
final desktopSidebarVisibleProvider = StateProvider<bool>((ref) => true);

/// Compute desktop text scale from window dimensions.
/// Tuned so 900×1400 → 1.8×, scales smoothly for any window size.
double _desktopTextScale(double windowWidth, double windowHeight) {
  // Width drives ~70% of scale, height ~30% — matches vertical-scroll app layout
  final sw = windowWidth / 500.0;   // 900px → 1.80
  final sh = windowHeight / 1556.0; // 1400px → 0.90
  return (sw * 0.7 + sh * 0.3).clamp(0.9, 3.0);
}

/// Main wrapper screen with TabController
class MainWrapperScreen extends ConsumerStatefulWidget {
  const MainWrapperScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends ConsumerState<MainWrapperScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late int _currentIndex;
  StreamSubscription<Achievement>? _achievementSub;
  StreamSubscription<DesktopInAppNotif>? _desktopNotifSub;
  StreamSubscription<DesktopPrayerEvent>? _prayerSchedulerSub;

  // Desktop notification popup queue (replaces in-app banners)
  _NotifPopup? _activePopup;
  final List<_NotifPopup> _popupQueue = [];
  bool _isShowingPopup = false;
  bool _popupDismissing = false;
  bool _popupWasVisible = false;
  Timer? _autoDismissTimer;
  AnimationController? _popupAnimCtrl;
  Timer? _prayerSyncTimer;

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
      // Read fajr time before invalidating, so after-midnight detection still works
      final resumePrayerTimes = ref.read(prayerTimesProvider)?.prayerTimes ?? [];
      final resumeFajrTime = resumePrayerTimes.where((p) => p.name == 'Fajr').firstOrNull?.time;
      ref.invalidate(prayerTimesProvider);
      ref.invalidate(tasksProvider(const TaskFilterParams()));
      ref.invalidate(allTasksProvider);
      _handleWidgetIntent();
      _syncThenLoadPrayerStatus(resumeFajrTime);
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

    // Mobile: periodic prayer status sync so cross-device changes appear within 30s
    if (!_isDesktop) {
      _prayerSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          final timerPrayerTimes = ref.read(prayerTimesProvider)?.prayerTimes ?? [];
          final timerFajrTime = timerPrayerTimes.where((p) => p.name == 'Fajr').firstOrNull?.time;
          ref.read(dailyPrayerStatusProvider.notifier).load(fajrTime: timerFajrTime);
        }
      });
    }

    // Desktop: show in-app banners for reminders/tasks/wird.
    if (_isDesktop) {
      _desktopNotifSub =
          DesktopNotificationService.instance.notificationStream.listen((notif) {
        if (!mounted) return;
        _enqueuePopup(_NotifPopup(
          emoji: notif.emoji,
          title: notif.title,
          body: notif.body,
        ));
      });

      // Desktop: adhan overlay with action buttons when prayer time fires.
      _prayerSchedulerSub =
          DesktopPrayerScheduler.instance.prayerTimeStream.listen((event) {
        if (!mounted) return;
        _showAdhanOverlay(event.name, event.nameAr);
      });
    }

    // Listen for newly earned achievements and show a toast
    _achievementSub = AchievementService.instance.newAchievements.listen((achievement) {
      if (!mounted) return;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      _showAchievementToast(achievement, isArabic);
      if (DesktopNotificationService.isDesktop) {
        DesktopNotificationService.instance.showAchievementNotification(
          achievement.nameEn, achievement.nameAr, achievement.iconEmoji, isArabic);
      } else {
        NotificationService.instance.showAchievementNotification(achievement, isArabic);
      }
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
      Future.delayed(const Duration(seconds: 3), _checkUntrackedPrayers);

      Future.delayed(const Duration(seconds: 1), _checkGuestMigration);
    });

    // Listen for app shortcut navigation from native side (Android only)
    if (!kIsWeb && Platform.isAndroid) _navigationChannel.setMethodCallHandler((call) async {
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
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _prayerSyncTimer?.cancel();
    _popupAnimCtrl?.dispose();
    _achievementSub?.cancel();
    _desktopNotifSub?.cancel();
    _prayerSchedulerSub?.cancel();
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

  void _showAdhanOverlay(String prayerName, String prayerNameAr) {
    // Make window visible first (it may be hidden in tray)
    try { windowManager.show(); } catch (_) {}

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AdhanOverlay(
        prayerName: prayerName,
        prayerNameAr: prayerNameAr,
        onDismiss: () => entry.remove(),
        onPrayed: () {
          entry.remove();
          DesktopNotificationService.instance.recordPrayerOnTime(prayerName);
          DesktopAdhanService.instance.stop();
        },
        onStopAdhan: () {
          entry.remove();
          DesktopAdhanService.instance.stop();
        },
      ),
    );
    overlay.insert(entry);
  }

  // ── Desktop popup queue ──────────────────────────────────────────────────

  void _enqueuePopup(_NotifPopup popup) {
    _popupQueue.add(popup);
    if (!_isShowingPopup) _processNextPopup();
  }

  Future<void> _processNextPopup() async {
    if (_popupQueue.isEmpty || !mounted) {
      _isShowingPopup = false;
      return;
    }
    _isShowingPopup = true;
    final popup = _popupQueue.removeAt(0);
    await _showPopupWindow(popup);
  }

  Future<void> _showPopupWindow(_NotifPopup popup) async {
    _popupWasVisible = await windowManager.isVisible();

    const windowW = 360.0;
    final windowH = popup.isAdhan ? 190.0 : (popup.body != null ? 155.0 : 120.0);

    try {
      double screenW = 1920, screenH = 1080;
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final dpr = view.devicePixelRatio;
        screenW = view.display.size.width / dpr;
        screenH = view.display.size.height / dpr;
      } catch (_) {}

      const taskbarH = 52.0;
      const margin = 12.0;

      await windowManager.setTitleBarStyle(TitleBarStyle.hidden); // remove title bar
      await windowManager.setMinimumSize(const Size(1, 1));       // allow small resize
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(Size(windowW, windowH));
      await windowManager.setPosition(Offset(
        screenW - windowW - margin,
        screenH - windowH - taskbarH - margin,
      ));
      await windowManager.setSkipTaskbar(false);
      // show() is called after setState so popup content renders first (no flash)
    } catch (e) {
      debugPrint('⚠️ [DESKTOP] showPopupWindow failed: $e');
    }

    if (!mounted) return;

    // Set popup content BEFORE showing the window (prevents flash of main app content)
    _popupAnimCtrl?.dispose();
    _popupAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    setState(() => _activePopup = popup);
    _popupDismissing = false;

    // Wait one frame so popup content renders while window is still hidden
    await Future.delayed(const Duration(milliseconds: 32));
    if (!mounted) return;

    try {
      await windowManager.show();
    } catch (_) {}

    // Start slide-up after window is visible
    _popupAnimCtrl?.forward();

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(
      popup.isAdhan ? const Duration(minutes: 5) : const Duration(seconds: 8),
      () { if (mounted && _activePopup == popup) _dismissCurrentPopup(); },
    );
  }

  Future<void> _dismissCurrentPopup() async {
    if (_popupDismissing) return;
    _popupDismissing = true;
    _autoDismissTimer?.cancel();

    // Slide-down before hiding
    if (_popupAnimCtrl != null && mounted) {
      await _popupAnimCtrl!.reverse();
    }
    _popupAnimCtrl?.dispose();
    _popupAnimCtrl = null;

    if (!mounted) return;

    try {
      if (!_popupWasVisible) {
        // Hide FIRST so the main app content never flashes
        await windowManager.hide();
      }
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(const Size(400, 600));
      await windowManager.setSize(const Size(900, 1400));
      await windowManager.center();
      if (_popupWasVisible) {
        await windowManager.setSkipTaskbar(false);
      } else {
        await windowManager.setSkipTaskbar(true);
      }
    } catch (e) {
      debugPrint('⚠️ [DESKTOP] dismissCurrentPopup failed: $e');
    }

    setState(() => _activePopup = null);
    _popupDismissing = false;

    _isShowingPopup = false;
    await Future.delayed(const Duration(milliseconds: 300));
    _processNextPopup();
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

  // Sync notification-pressed statuses to Firestore first, then load provider once —
  // eliminates the flash where prayers appear untracked between load and sync.
  Future<void> _syncThenLoadPrayerStatus(DateTime? fajrTime) async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null && userId.isNotEmpty) {
        await PrayerAlarmService.instance.syncNativePrayerStatuses(userId);
      }
    } catch (e) {
      debugPrint('Error syncing native prayer statuses: $e');
    } finally {
      if (mounted) {
        ref.read(dailyPrayerStatusProvider.notifier).load(forceRefresh: true, fajrTime: fajrTime);
      }
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

  Future<void> _checkGuestMigration() async {
    if (!mounted) return;
    final migration = ref.read(guestMigrationProvider);
    if (!migration.isPending || migration.dialogShownThisSession) return;
    ref.read(guestMigrationProvider.notifier).markDialogShown();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final count = migration.taskCount;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('guest_sync_dialog_title'.tr()),
        content: Text(
          'guest_sync_dialog_body'.tr().replaceAll('%d', '$count'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('guest_sync_later'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(guestMigrationProvider.notifier).migrate();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('guest_sync_success'.tr())),
              );
            },
            child: Text('guest_sync_now'.tr()),
          ),
        ],
      ),
    );
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
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(isArabic ? '✅ أحسنت! جميع الصلوات مسجّلة' : '✅ All caught up!'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: color,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
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
                      style: AppTypography.bodyM.copyWith(color: Colors.grey[600]),
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
              backgroundColor: isDark ? const Color(0xFF1A1B1E) : const Color(0xFFFFF3D6),
              selectedColor: AppConstants.primaryColor,
              labelStyle: AppTypography.bodyM.copyWith(
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
              style: AppTypography.label.copyWith(color: AppConstants.primaryColor),
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
        final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
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
            margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
          ),
        );
        Future.delayed(const Duration(seconds: 2), snackCtrl.close);
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
                  backgroundColor: isDark ? const Color(0xFF1A1B1E) : const Color(0xFFFFF3D6),
                  selectedColor: AppConstants.primaryColor,
                  labelStyle: AppTypography.bodyM.copyWith(
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
              style: AppTypography.label.copyWith(color: AppConstants.primaryColor),
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
      final prayerState = ref.read(prayerTimesProvider);
      final fajrTime = prayerState.prayerTimes.where((p) => p.name == 'Fajr').firstOrNull?.time;
      await PrayerTrackingService.instance.recordPrayer(
        userId: userId,
        prayerName: prayerName,
        date: getPrayerDate(now, fajrTime: fajrTime),
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
        final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
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
            margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
          ),
        );
        Future.delayed(const Duration(seconds: 2), snackCtrl.close);
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

      final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
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
            bottom: 82,
            left: 20,
            right: 20,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      );
      Future.delayed(_doubleTapDuration, snackCtrl.close);
    }

    return false; // Prevent default back behavior
  }

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    // Watch language so wrapper rebuilds when locale changes
    ref.watch(languageProvider);

    // Keep task widget synced
    ref.watch(taskWidgetSyncProvider);

    // Desktop notification popup — slides up above taskbar clock, no focus steal
    if (_isDesktop && _activePopup != null && _popupAnimCtrl != null) {
      final popup = _activePopup!;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final primary = isDark ? const Color(0xFFF5B301) : const Color(0xFFB5821B);
      final bgColor = isDark ? const Color(0xFF1A1B1E) : Colors.white;

      final title = popup.isAdhan
          ? (isArabic ? 'حان وقت الصلاة' : 'Prayer Time')
          : popup.title;
      final body = popup.isAdhan
          ? (isArabic
              ? 'حان موعد صلاة ${popup.prayerNameAr ?? popup.prayerName}'
              : "It's time for ${popup.prayerName} prayer")
          : popup.body;

      final slideAnim = Tween<Offset>(
        begin: const Offset(0, 1),  // starts below (from taskbar)
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _popupAnimCtrl!,
        curve: Curves.easeOutCubic,
      ));

      return Scaffold(
        backgroundColor: bgColor,
        body: SlideTransition(
          position: slideAnim,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: primary.withOpacity(0.4), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(popup.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.headingS.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _dismissCurrentPopup,
                        child: Icon(Icons.close, size: 18,
                            color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: AppTypography.bodyS.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                  if (popup.isAdhan) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _dismissCurrentPopup,
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white54 : Colors.black45,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: Text(isArabic ? 'إغلاق' : 'Dismiss'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            DesktopAdhanService.instance.stop();
                            _dismissCurrentPopup();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white54 : Colors.black45,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: Text(isArabic ? 'إيقاف الأذان' : 'Stop Adhan'),
                        ),
                        const SizedBox(width: 8),
                        AuraButton(
                          label: isArabic ? 'صليت ✓' : 'Prayed ✓',
                          onPressed: () async {
                            final name = popup.prayerName ?? '';
                            if (name.isNotEmpty) {
                              await DesktopNotificationService.instance
                                  .recordPrayerOnTime(name);
                            }
                            DesktopAdhanService.instance.stop();
                            _dismissCurrentPopup();
                          },
                          verticalPadding: 6,
                          fontSize: 12,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pageView = PageView(
      controller: _pageController,
      // Disable swipe on desktop — navigation is via sidebar
      physics: _isDesktop ? const NeverScrollableScrollPhysics() : null,
      onPageChanged: (index) {
        if (_isDesktop) return;
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
        QuranScreen(),
        TasksScreen(),
        ProfileScreen(),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) await _onWillPop();
      },
      child: _isDesktop
          ? _DesktopShell(
              currentIndex: _currentIndex,
              onTap: _handleTabTap,
              child: pageView,
            )
          : Scaffold(
              body: pageView,
              bottomNavigationBar: AuraBottomNavBar(
                currentIndex: _currentIndex,
                onTap: _handleTabTap,
              ),
            ),
    );
  }
}

/// Full desktop shell: sidebar + content area with nested Navigator
class _DesktopShell extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  const _DesktopShell({
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  @override
  ConsumerState<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<_DesktopShell> {
  bool _sidebarCollapsed = false;
  final GlobalKey<NavigatorState> _contentNavKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasBg = isDark ? const Color(0xFF0D0E11) : const Color(0xFFEDE4D0);
    final sidebarVisible = ref.watch(desktopSidebarVisibleProvider);

    return Scaffold(
      backgroundColor: canvasBg,
      body: Row(
        children: [
          if (sidebarVisible) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: _sidebarCollapsed ? 72.0 : 260.0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCollapsed = constraints.maxWidth < 166;
                  return _DesktopSidebar(
                    currentIndex: widget.currentIndex,
                    onTap: widget.onTap,
                    collapsed: isCollapsed,
                    onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  );
                },
              ),
            ),
            Container(width: 1, color: isDark ? Colors.white10 : Colors.black12),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final mq = MediaQuery.of(ctx);
                final scale = _desktopTextScale(mq.size.width, mq.size.height);
                final iconSize = (24.0 * scale).clamp(18.0, 52.0);
                final chipPadH = (8.0 * scale).clamp(6.0, 20.0);
                final chipPadV = (4.0 * scale).clamp(2.0, 12.0);
                // VisualDensity scales Material component padding — capped to avoid
                // excessive expansion at very large window sizes.
                final density = ((scale - 1.0) * 2.0).clamp(-4.0, 2.0);
                final baseTheme = Theme.of(ctx);
                return Theme(
                  data: baseTheme.copyWith(
                    visualDensity: VisualDensity(
                      horizontal: density,
                      vertical: density,
                    ),
                    iconTheme: baseTheme.iconTheme.copyWith(size: iconSize),
                    chipTheme: baseTheme.chipTheme.copyWith(
                      padding: EdgeInsets.symmetric(
                          horizontal: chipPadH, vertical: chipPadV),
                    ),
                    listTileTheme: baseTheme.listTileTheme.copyWith(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: (16.0 * scale).clamp(0, 24.0),
                        vertical: 0,
                      ),
                      minVerticalPadding: (8.0 * scale).clamp(0, 12.0),
                    ),
                    cardTheme: baseTheme.cardTheme.copyWith(
                      margin: EdgeInsets.all((4.0 * scale).clamp(0, 6.0)),
                    ),
                  ),
                  child: MediaQuery(
                    data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                    child: Navigator(
                      key: _contentNavKey,
                      onGenerateRoute: _generateDesktopRoute,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Route<dynamic> _generateDesktopRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case '/prayer':
        page = const PrayerScreen();
        break;
      case '/prayer_tracking':
        page = const PrayerTrackingScreen();
        break;
      case '/prayer_report':
        page = const PrayerReportScreen();
        break;
      case '/dhikr':
        page = const DhikrScreen();
        break;
      case '/dhikr_stats':
        page = const DhikrStatsScreen();
        break;
      case '/achievements':
        page = const AchievementsScreen();
        break;
      case '/task_form':
        page = TaskFormScreen(task: settings.arguments as Task?);
        break;
      case '/task_stats':
        page = const TaskStatsScreen();
        break;
      case '/iqama_settings':
        page = const IqamaSettingsScreen();
        break;
      case '/adhan_downloads':
        page = const AdhanDownloadsScreen();
        break;
      case '/qibla':
        page = const QiblaScreen();
        break;
      case '/daily_content':
        page = const DailyContentScreen();
        break;
      case '/azkar':
        page = const AzkarScreen();
        break;
      case '/quran':
        page = const QuranScreen();
        break;
      case '/quran_stats':
        page = const QuranStatsScreen();
        break;
      case '/islamic_events':
        page = const IslamicEventsScreen();
        break;
      default:
        page = widget.child; // PageView (main tabs)
    }

    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}

/// Desktop sidebar navigation — supports expanded (220 px) and collapsed (72 px) modes
class _DesktopSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool collapsed;
  final VoidCallback onToggle;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onTap,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final appMode = ref.watch(appModeProvider);

    final showPrayer = appMode != AppMode.tasksOnly;
    final showQuran = appMode == AppMode.both || appMode == AppMode.prayerOnly;
    final showTasks = appMode != AppMode.prayerOnly;

    final overdueCount = ref.watch(allTasksProvider).whenOrNull(
          data: (tasks) => tasks.where((t) => !t.isCompleted && t.isOverdue).length,
        ) ?? 0;

    final bgColor = AppConstants.surface(isDark);

    return Container(
      width: double.infinity,
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          SizedBox(
            height: 72,
            child: collapsed
                // Collapsed: just the expand button, centered
                ? Center(
                    child: Tooltip(
                      message: 'Expand sidebar',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onToggle,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.menu, size: 26, color: primary),
                        ),
                      ),
                    ),
                  )
                // Expanded: logo + name + toggle in a row
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) => Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.mosque, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aura | هالة',
                            style: AppTypography.headingS.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: primary,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Tooltip(
                          message: 'Collapse sidebar',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onToggle,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.menu_open, size: 22, color: isDark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Container(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 10),

          // ── Nav items ─────────────────────────────────────────────────────
          _sidebarItem(context, isDark, primary, Icons.home_outlined, Icons.home, 'home'.tr(), 0),
          if (showPrayer)
            _sidebarItem(context, isDark, primary, Icons.mosque_outlined, Icons.mosque, 'prayer_times_title'.tr(), 1),
          if (showQuran)
            _sidebarItem(context, isDark, primary, Icons.menu_book_outlined, Icons.menu_book, 'quran'.tr(), 2),
          if (showTasks)
            _sidebarItem(context, isDark, primary, Icons.task_alt_outlined, Icons.task_alt, 'tasks_nav'.tr(), 3,
                badge: overdueCount),
          _sidebarItem(context, isDark, primary, Icons.person_outline, Icons.person, 'profile'.tr(), 4),

          const Spacer(),
          Container(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context,
    bool isDark,
    Color primary,
    IconData iconOutlined,
    IconData iconFilled,
    String label,
    int index, {
    int badge = 0,
  }) {
    final isSelected = currentIndex == index;
    final textColor = isSelected ? primary : (AppConstants.textSecondary(isDark));
    final itemBg = isSelected ? primary.withOpacity(0.13) : Colors.transparent;
    final icon = isSelected ? iconFilled : iconOutlined;

    if (collapsed) {
      // Icon-only mode: centered, tooltip shows label
      return Tooltip(
        message: label,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: itemBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onTap(index),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 28, color: isSelected ? primary : textColor),
                      if (badge > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                            child: Text('$badge', style: AppTypography.caption.copyWith(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded mode: icon + label + active indicator
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: itemBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 28, color: isSelected ? primary : textColor),
                    if (badge > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                          child: Text('$badge', style: AppTypography.caption.copyWith(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.headingS.copyWith(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Desktop in-app adhan popup overlay (bottom-right corner, stays for 5 min).
class _AdhanOverlay extends StatefulWidget {
  final String prayerName;
  final String prayerNameAr;
  final VoidCallback onDismiss;
  final VoidCallback onPrayed;
  final VoidCallback onStopAdhan;

  const _AdhanOverlay({
    required this.prayerName,
    required this.prayerNameAr,
    required this.onDismiss,
    required this.onPrayed,
    required this.onStopAdhan,
  });

  @override
  State<_AdhanOverlay> createState() => _AdhanOverlayState();
}

class _AdhanOverlayState extends State<_AdhanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _timer = Timer(const Duration(minutes: 5), _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFFF5B301) : const Color(0xFFB5821B);
    final bg = isDark ? const Color(0xFF1A1B1E) : Colors.white;
    final name = isArabic ? widget.prayerNameAr : widget.prayerName;

    return Positioned(
      right: 16,
      bottom: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: bg,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🕌', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic ? 'حان وقت الصلاة' : 'Prayer Time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: primary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(Icons.close, size: 16,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isArabic ? 'حان موعد صلاة $name' : "Time for $name prayer",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () { _timer?.cancel(); widget.onStopAdhan(); },
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white54 : Colors.black45,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(isArabic ? 'إيقاف الأذان' : 'Stop Adhan'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () { _timer?.cancel(); widget.onPrayed(); },
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(
                        isArabic ? 'صليت ✓' : 'Prayed ✓',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Internal model for a desktop notification popup.
class _NotifPopup {
  final String emoji;
  final String title;
  final String? body;
  final bool isAdhan;
  final String? prayerName;
  final String? prayerNameAr;

  const _NotifPopup({
    this.emoji = '🔔',
    this.title = '',
    this.body,
    this.isAdhan = false,
    this.prayerName,
    this.prayerNameAr,
  });
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
                              style: AppTypography.labelS.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.achievement.name(widget.isArabic),
                              style: AppTypography.headingS.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.achievement.description(widget.isArabic),
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
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


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
import '../../core/models/achievement.dart';
import '../home/home_screen.dart';
import '../prayer/prayer_screen.dart';
import '../profile/profile_screen.dart';
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
      ref.invalidate(prayerTimesProvider);
      ref.invalidate(tasksProvider(const TaskFilterParams()));
      _handleWidgetIntent();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _tabController = TabController(length: 4, vsync: this);
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

  void _updateCurrentRoute() {
    final route = _currentIndex == 0 ? '/home' : '/tab/$_currentIndex';
    _navigationChannel.invokeMethod('setCurrentRoute', {'route': route});
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
              ? AppConstants.primaryColor.withOpacity(0.95)
              : AppConstants.primaryColor,
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
                    gradient: const LinearGradient(
                      colors: [AppConstants.primaryColor, AppConstants.accentCyan],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.primaryColor.withValues(alpha: 0.35),
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


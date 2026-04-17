import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/utils/haptic_feedback.dart' as app_haptic;
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';
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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentIndex;

  // PageController for smooth page transitions
  final PageController _pageController = PageController();
  bool _isPageViewDragging = false;

  // Back to exit functionality
  DateTime? _lastBackPressTime;
  static const Duration _doubleTapDuration = Duration(seconds: 2);

  // Platform channel for navigation communication
  static const _navigationChannel = MethodChannel('com.aura.hala/navigation');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.index = _currentIndex;
    _updateCurrentRoute();

    // Listen for tab navigation requests from child screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<int>(tabNavigationProvider, (prev, next) {
        if (next >= 0 && next != _currentIndex) {
          _handleTabTap(next);
          // Reset provider so it can be triggered again
          ref.read(tabNavigationProvider.notifier).state = -1;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
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


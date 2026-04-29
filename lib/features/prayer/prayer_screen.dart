import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/prayer_record.dart';
import '../../core/widgets/prayer_card.dart';
import '../../core/widgets/prayer_status_dialog.dart';
import '../../core/widgets/circular_countdown.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/utils/hijri_date.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/services/adhan_player_service.dart';
import '../../core/services/background_service_manager.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/prayer_alarm_service.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../settings/prayer_calculation_settings_dialog.dart';
import '../settings/adhan_calculation_method.dart';
import '../settings/asr_madhab_selection.dart';
import '../../core/utils/haptic_feedback.dart' as haptic;
import '../../core/providers/preferences_provider.dart';
import '../../core/utils/prayer_time_rules.dart';
import '../../core/providers/daily_prayer_status_provider.dart';

/// Prayer Screen - Displays prayer times for the day
class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen>
    with TickerProviderStateMixin {
  // Local state for prayer data (prevents full page rebuilds)
  List<PrayerTime> _prayerTimes = [];
  PrayerTime? _nextPrayer;
  PrayerTime? _currentPrayer;
  LocationData? _location;
  bool _isLoading = true;
  String? _errorMessage;

  // Prayer tracking state
  final Map<String, PrayerStatus> _prayerStatuses = {}; // prayer name -> status
  final Set<String> _explicitlyMarked = {}; // prayers the user actively marked (including missed)
  final PrayerTrackingService _trackingService = PrayerTrackingService.instance;

  // Prayer calculation settings
  String _calculationMethod = 'MuslimWorldLeague';
  String _asrMadhab = 'Shafi';

  @override
  void initState() {
    super.initState();
    // Load initial prayer times after build completes
    Future.microtask(() => _loadPrayerTimes());
    // Load calculation settings
    _loadCalculationSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    // Check if provider already has valid data (from app startup init)
    final existingState = ref.read(prayerTimesProvider);
    final hasExistingData = existingState != null &&
        existingState.prayerTimes.isNotEmpty &&
        existingState.isLoading == false;

    if (hasExistingData) {
      // Use existing data right away - no shimmer
      setState(() {
        _prayerTimes = existingState.prayerTimes;
        _nextPrayer = existingState.nextPrayer;
        _currentPrayer = existingState.currentPrayer;
        _location = existingState.location;
        _isLoading = false;
        _errorMessage = existingState.errorMessage;
      });

      // Load completed prayers in background
      _loadCompletedPrayers();

      // Refresh in background (don't block UI)
      try {
        final notifier = ref.read(prayerTimesProvider.notifier);
        await notifier.loadPrayerTimes(DateTime.now());
        if (!mounted) return;
        final freshState = ref.read(prayerTimesProvider);
        if (freshState != null) {
          setState(() {
            _prayerTimes = freshState.prayerTimes;
            _nextPrayer = freshState.nextPrayer;
            _currentPrayer = freshState.currentPrayer;
            _location = freshState.location;
            _errorMessage = freshState.errorMessage;
          });
          await _loadCompletedPrayers();
        }
      } catch (e) {
        debugPrint('Error refreshing prayer times: $e');
      }
      return;
    }

    // No existing data - show shimmer while loading
    setState(() {
      _isLoading = true;
    });

    try {
      final notifier = ref.read(prayerTimesProvider.notifier);
      await notifier.loadPrayerTimes(DateTime.now());

      // Get the updated state from provider
      final state = ref.read(prayerTimesProvider);
      if (state != null) {
        setState(() {
          _prayerTimes = state.prayerTimes ?? [];
          _nextPrayer = state.nextPrayer;
          _currentPrayer = state.currentPrayer;
          _location = state.location;
          _isLoading = state.isLoading ?? false;
          _errorMessage = state.errorMessage;
        });

        // Load completed prayers for today
        await _loadCompletedPrayers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshPrayerTimes() async {
    await _loadPrayerTimes();
  }

  /// Load completed prayers for today (uses shared provider)
  Future<void> _loadCompletedPrayers() async {
    try {
      final notifier = ref.read(dailyPrayerStatusProvider.notifier);
      await notifier.load();

      final statuses = ref.read(dailyPrayerStatusProvider).statuses;
      setState(() {
        _prayerStatuses.clear();
        _explicitlyMarked.clear();
        for (final entry in statuses.entries) {
          _prayerStatuses[entry.key] = entry.value;
          if (entry.value != PrayerStatus.missed) {
            _explicitlyMarked.add(entry.key);
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading completed prayers: $e');
    }
  }

  /// Mark a prayer as completed
  Future<void> _markPrayerAsCompleted(String prayerName) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Check 20-minute rule: must be at least 20 minutes past prayer time
    if (!canMarkPrayer(context: context, prayerName: prayerName, prayerTimes: _prayerTimes, isArabic: isArabic)) {
      return;
    }

    await _trackingService.initialize();

    // Get user ID from auth
    final userId = getCurrentUserId();

    // Show dialog to choose: On Time, Late, or Missed
    final chosenStatus = await showPrayerStatusDialog(
      context: context,
      prayerName: prayerName,
      isArabic: isArabic,
    );

    if (chosenStatus == null || !mounted) return;

    try {
      final success = await _trackingService.recordPrayer(
        userId: userId,
        prayerName: prayerName,
        date: DateTime.now(),
        prayedAt: DateTime.now(),
        status: chosenStatus,
        method: PrayerMethod.congregation,
      );

      if (success && mounted) {
        haptic.HapticFeedback.success();
        // Update shared provider so home screen also gets the change
        ref.read(dailyPrayerStatusProvider.notifier).updatePrayer(prayerName, chosenStatus);
        setState(() {
          _prayerStatuses[prayerName] = chosenStatus;
          _explicitlyMarked.add(prayerName);
        });

        final snackBarColor = chosenStatus == PrayerStatus.late
            ? Colors.orange
            : chosenStatus == PrayerStatus.excused
                ? Colors.red
                : Colors.green;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'تم تسجيل $prayerName' : 'Recorded $prayerName',
            ),
            backgroundColor: snackBarColor,
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking prayer as completed: $e');
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

  /// Unmark a prayer directly (when tapping Done button)
  Future<void> _unmarkPrayerDirect(String prayerName) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Show confirmation dialog before unmarking
    final confirmed = await showUnmarkConfirmDialog(
      context: context,
      prayerName: prayerName,
      isArabic: isArabic,
    );

    if (confirmed != true || !mounted) return;

    await _trackingService.initialize();

    // Get user ID from auth
    final userId = getCurrentUserId();

    try {
      final today = DateTime.now();
      final normalizedDate = DateTime(today.year, today.month, today.day);

      debugPrint('🔄 [UNMARK] Unmarking $prayerName for $normalizedDate');

      final deleted = await _trackingService.deletePrayerRecord(
        userId: userId,
        prayerName: prayerName,
        date: normalizedDate,
      );

      debugPrint('🔄 [UNMARK] Delete result: $deleted');

      if (!deleted) {
        haptic.HapticFeedback.error();
        // Delete failed - do not change UI state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? 'فشل إلغاء تسجيل $prayerName. حاول مرة أخرى.'
                    : 'Failed to unmark $prayerName. Please try again.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (mounted) {
        haptic.HapticFeedback.light();
        // Update shared provider so home screen also gets the change
        ref.read(dailyPrayerStatusProvider.notifier).removePrayer(prayerName);
        setState(() {
          _prayerStatuses[prayerName] = PrayerStatus.missed;
          _explicitlyMarked.remove(prayerName);
        });

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
    } catch (e) {
      debugPrint('Error unmarking prayer: $e');
    }
  }

  /// Save calculation settings to SharedPreferences
  Future<void> _saveCalculationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyCalculationMethod, _calculationMethod);
    await prefs.setString(AppConstants.keyAsrMadhab, _asrMadhab);
    debugPrint('Saved calculation settings: $_calculationMethod, $_asrMadhab');
  }

  /// Load calculation settings from SharedPreferences
  Future<void> _loadCalculationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final method = prefs.getString(AppConstants.keyCalculationMethod) ?? 'MuslimWorldLeague';
    final madhab = prefs.getString(AppConstants.keyAsrMadhab) ?? 'Shafi';

    setState(() {
      _calculationMethod = method;
      _asrMadhab = madhab;
    });

    debugPrint('Loaded calculation settings: $_calculationMethod, $_asrMadhab');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Create local state for passing to _buildContent
    final localState = PrayerTimesState(
      prayerTimes: _prayerTimes,
      nextPrayer: _nextPrayer,
      currentPrayer: _currentPrayer,
      selectedDate: DateTime.now(),
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      location: _location,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('prayer_times_title'.tr()),
        actions: [
          // Qibla button
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/qibla');
            },
            tooltip: isArabic ? 'القبلة' : 'Qibla',
          ),
          // Prayer Tracking button
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              await Navigator.of(context).pushNamed('/prayer_tracking');
              // Reload completed prayers when returning from tracker
              if (mounted) _loadCompletedPrayers();
            },
            tooltip: isArabic ? 'تتبع الصلوات' : 'Prayer Tracking',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showPrayerSettings(context, ref, isArabic),
            tooltip: isArabic ? 'إعدادات الصلاة' : 'Prayer Settings',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(_isLoading),
          child: _buildContent(context, localState, isDark, isArabic),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PrayerTimesState state,
    bool isDark,
    bool isArabic,
  ) {
    if (state.isLoading) {
      return _buildLoadingState(context, isDark);
    }

    if (state.errorMessage != null) {
      return _buildErrorState(context, state.errorMessage!, isArabic);
    }

    return RefreshIndicator(
      onRefresh: _refreshPrayerTimes,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Offline Banner (inline, not wrapped)
            const OfflineBanner(),
            // Location header
            if (state.location != null)
              _buildLocationHeader(context, state.location!, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingSmall),

            // Date Header Card with Hijri-style design
            _buildDateHeader(context, state.selectedDate, state.prayerTimes,
                    isDark, isArabic)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.08, duration: 400.ms),

            const SizedBox(height: AppConstants.paddingMedium),

            // Next Prayer Countdown (Circular)
            if (state.nextPrayer != null) ...[
              _buildNextPrayerSection(
                      context, state.nextPrayer!, isDark, isArabic)
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: AppConstants.paddingLarge),
            ],

            // Prayers List Header
            _buildPrayersListHeader(context, isArabic)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: AppConstants.paddingSmall),

            // Prayer Cards
            ..._buildPrayerCards(context, state, isDark, isArabic),

            // Muslim Toolkit
            const SizedBox(height: AppConstants.paddingLarge),
            _buildMuslimToolkit(context, isDark, isArabic)
                .animate()
                .fadeIn(delay: 600.ms, duration: 400.ms),

            // Bottom padding for nav bar
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHeader(
    BuildContext context,
    dynamic location,
    bool isDark,
    bool isArabic,
  ) {
    // Get localized city name
    final cityName = location.cityName ?? 'Unknown';
    final localizedCityName =
        getLocalizedCityName(cityName, isArabic ? 'ar' : 'en');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            color: AppConstants.getPrimary(isDark),
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            localizedCityName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(
    BuildContext context,
    DateTime date,
    List<PrayerTime> prayerTimes,
    bool isDark,
    bool isArabic,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(date.year, date.month, date.day);
    final isToday = selectedDay == today;

    // Calculate Hijri date
    final hijri = HijriDate.toHijri(date);
    final hijriDateStr =
        isArabic ? HijriDate.formatAr(hijri) : HijriDate.formatEn(hijri);

    // Format Gregorian date
    final gregorianDateStr = _formatDate(date, isArabic ? 'ar' : 'en');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.getPrimary(isDark),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppConstants.getPrimary(isDark).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Hijri Date (left)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(
                  Icons.nights_stay,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hijriDateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Today Badge (center)
          if (isToday)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Text(
                  isArabic ? 'اليوم' : 'Today',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Gregorian Date (right)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    gregorianDateStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerSection(
    BuildContext context,
    PrayerTime nextPrayer,
    bool isDark,
    bool isArabic,
  ) {
    return Column(
      children: [
        Text(
          isArabic ? 'الصلاة القادمة' : 'Next Prayer',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppConstants.getPrimary(isDark),
              ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        CircularCountdownTimer(
          targetTime: nextPrayer.time,
          prayerName: isArabic ? nextPrayer.nameAr : nextPrayer.name,
          prayerTime: DateFormatter.formatTime(nextPrayer.time, languageCode: isArabic ? 'ar' : 'en'),
          onComplete: () {
            // Refresh when prayer time is reached - wrap in microtask to avoid modifying during build
            Future.microtask(() async {
              if (mounted) {
                debugPrint('🔔 [COUNTDOWN] Prayer time reached! Refreshing prayer times...');
                // Do a full refresh to ensure next day's prayers are loaded if needed
                await ref
                    .read(prayerTimesProvider.notifier)
                    .loadPrayerTimes(DateTime.now());
                debugPrint('🔔 [COUNTDOWN] Prayer times refreshed');
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildPrayersListHeader(BuildContext context, bool isArabic) {
    return Row(
      children: [
        Text(
          isArabic ? 'أوقات الصلاة اليوم' : 'Today\'s Prayer Times',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  List<Widget> _buildPrayerCards(
    BuildContext context,
    PrayerTimesState state,
    bool isDark,
    bool isArabic,
  ) {
    // Show all prayers including Sunrise
    return state.prayerTimes.asMap().entries.map((entry) {
      final index = entry.key;
      final prayer = entry.value;
      final isNext = state.nextPrayer?.name == prayer.name;
      final isCurrent = state.currentPrayer?.name == prayer.name;
      final status = _prayerStatuses[prayer.name] ?? PrayerStatus.missed;
      final isCompleted = status != PrayerStatus.missed;

      // Don't show mark button for Sunrise
      final canMark = prayer.name != 'Sunrise';

      return Padding(
        padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
        child: PrayerCard(
          prayer: prayer,
          isNext: isNext,
          isCurrent: isCurrent,
          isCompleted: isCompleted,
          prayerStatus: status,
          wasExplicitlyMarked: _explicitlyMarked.contains(prayer.name),
          onMarkPrayed: canMark
              ? () => _explicitlyMarked.contains(prayer.name) ? _unmarkPrayerDirect(prayer.name) : _markPrayerAsCompleted(prayer.name)
              : null,
        ),
      ).animate().fadeIn(
            delay: Duration(milliseconds: 250 + (index * 50)),
            duration: 400.ms,
          );
    }).toList();
  }

  Widget _buildMuslimToolkit(
    BuildContext context,
    bool isDark,
    bool isArabic,
  ) {
    final primary = AppConstants.getPrimary(isDark);
    final actions = [
      _ToolkitAction(icon: Icons.explore, label: isArabic ? 'القبلة' : 'Qibla', route: '/qibla', color: primary),
      _ToolkitAction(icon: Icons.pan_tool, label: isArabic ? 'أذكار' : 'Azkar', route: '/dhikr', color: primary),
      _ToolkitAction(icon: Icons.bar_chart, label: isArabic ? 'التقرير' : 'Report', route: '/prayer_report', color: primary),
    ];

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
          Text(
            isArabic ? 'أدوات المسلم' : 'Muslim Toolkit',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: actions.map((action) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (action.route != null) {
                          Navigator.of(context).pushNamed(action.route!);
                        }
                      },
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: action.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: action.color.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(action.icon, color: action.color, size: 24),
                            const SizedBox(height: 6),
                            Text(
                              action.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: action.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Offline Banner
          const OfflineBanner(),

          // Location header
          const ShimmerLocationHeader(),

          const SizedBox(height: AppConstants.paddingSmall),

          // Date header (mirrors the blue bar with Hijri/Gregorian)
          const ShimmerDateHeader(),

          const SizedBox(height: AppConstants.paddingMedium),

          // "Next Prayer" label
          const ShimmerSectionLabel(width: 100),
          const SizedBox(height: AppConstants.paddingMedium),

          // Circular countdown (mirrors the 180x180 circle)
          const Center(child: ShimmerCircularCountdown()),

          const SizedBox(height: AppConstants.paddingLarge),

          // "Today's Prayer Times" section header
          const ShimmerSectionHeader(width: 180),

          const SizedBox(height: AppConstants.paddingSmall),

          // 6 Prayer cards (mirrors PrayerCard layout)
          ...List.generate(
            6,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: AppConstants.paddingSmall),
              child: ShimmerPrayerCard(),
            ),
          ),

          // Quick Actions section
          const SizedBox(height: AppConstants.paddingLarge),
          const ShimmerQuickActions(),

          // Bottom padding for nav bar
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingXLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppConstants.error,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            isArabic ? 'خطأ في جلب أوقات الصلاة' : 'Error Loading Prayer Times',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.error,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          ElevatedButton.icon(
            onPressed: () => _loadPrayerTimes(),
            icon: const Icon(Icons.refresh),
            label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.getPrimary(isDark),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date, String languageCode) {
    final monthsEn = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final monthsAr = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];

    final day = date.day;
    final year = date.year;
    final month = languageCode == 'ar'
        ? monthsAr[date.month - 1]
        : monthsEn[date.month - 1];

    String dateStr;
    if (languageCode == 'ar') {
      dateStr = '$day $month $year';
      // Convert numbers to Arabic numerals
      dateStr = NumberFormatter.withArabicNumeralsByLanguage(dateStr, 'ar');
    } else {
      dateStr = '$day $month $year';
    }

    return dateStr;
  }

  void _showPrayerSettings(BuildContext context, WidgetRef ref, bool isArabic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrayerSettingsPage(),
      ),
    );
  }
}

/// Prayer Settings Page (Full Screen)
class PrayerSettingsPage extends StatefulWidget {
  const PrayerSettingsPage({super.key});

  @override
  State<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends State<PrayerSettingsPage> {
  bool _notificationsEnabled = true;
  bool _backgroundNotificationEnabled = true;
  bool _adhanEnabled = true;
  bool _silentModeEnabled = true;
  int _silentModeDuration = 20;

  // Prayer calculation settings
  String _calculationMethod = 'MuslimWorldLeague';
  String _asrMadhab = 'Shafi';
  bool _isPlayingAdhan = false;

  @override
  void initState() {
    super.initState();
    _loadAdhanSetting();
  }

  @override
  void dispose() {
    // Stop adhan if playing when sheet is closed
    if (_isPlayingAdhan) {
      AdhanPlayerService.instance.stopAdhan();
    }
    super.dispose();
  }

  Future<void> _loadAdhanSetting() async {
    final prefs = await SharedPreferences.getInstance();

    // Load adhan setting
    final enabled = AdhanPlayerService.instance.isEnabled;

    // Load calculation settings
    final method = prefs.getString(AppConstants.keyCalculationMethod) ?? 'MuslimWorldLeague';
    final madhab = prefs.getString(AppConstants.keyAsrMadhab) ?? 'Shafi';

    // Load settings from shared prefs
    final notificationsEnabled = prefs.getBool(AppConstants.keyPrayerNotificationsEnabled) ?? true;
    final backgroundNotificationEnabled = prefs.getBool(AppConstants.keyBackgroundNotificationEnabled) ?? true;
    final silentModeEnabled = prefs.getBool(AppConstants.keySilentModeEnabled) ?? true;
    final silentModeDuration = prefs.getInt(AppConstants.keySilentModeDuration) ?? 20;

    if (mounted) {
      setState(() {
        _notificationsEnabled = notificationsEnabled;
        _backgroundNotificationEnabled = backgroundNotificationEnabled;
        _adhanEnabled = enabled;
        _silentModeEnabled = silentModeEnabled;
        _silentModeDuration = silentModeDuration;
        _calculationMethod = method;
        _asrMadhab = madhab;
      });
    }
  }

  Future<void> _toggleAdhan() async {
    if (_isPlayingAdhan) {
      // Stop adhan
      await AdhanPlayerService.instance.stopAdhan();
      if (mounted) {
        setState(() {
          _isPlayingAdhan = false;
        });
      }
    } else {
      // Play adhan
      if (mounted) {
        setState(() {
          _isPlayingAdhan = true;
        });
      }
      await AdhanPlayerService.instance.playAdhan('Fajr');
      // Reset state after adhan finishes (approx 45-50 seconds)
      Future.delayed(const Duration(seconds: 50), () {
        if (mounted) {
          setState(() {
            _isPlayingAdhan = false;
          });
        }
      });
    }
  }

  void _showDurationDialog(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durations = [10, 15, 20, 25, 30];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isArabic ? 'مدة الوضع الصامت' : 'Silent Mode Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: durations.map((duration) {
            return ListTile(
              title: Text(
                isArabic ? '$duration دقيقة' : '$duration minutes',
              ),
              trailing: _silentModeDuration == duration
                  ? Icon(Icons.check, color: AppConstants.getPrimary(isDark))
                  : null,
              onTap: () async {
                setState(() {
                  _silentModeDuration = duration;
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt(AppConstants.keySilentModeDuration, duration);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: isDark ? AppConstants.darkBackground : AppConstants.lightBackground,
      appBar: AppBar(
        title: Text(isArabic ? 'إعدادات الصلاة' : 'Prayer Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
        children: [
          // ==================== NOTIFICATIONS SECTION ====================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingSmall,
            ),
            child: Text(
              isArabic ? 'الإشعارات' : 'Notifications',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          // Reminder Prayer Toggle
          SwitchListTile(
            secondary: Icon(Icons.notifications,
                color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic ? 'تذكير الصلاة' : 'Reminder Prayer'),
            subtitle: Text(isArabic
                ? 'تنبيه قبل موعد الصلاة بـ 10 دقائق'
                : 'Remind 10 minutes before prayer time'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() {
                _notificationsEnabled = value;
              });
              // Save to shared preferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppConstants.keyPrayerNotificationsEnabled, value);
            },
          ),
          // Background Notification Toggle
          SwitchListTile(
            secondary: Icon(Icons.notifications_active,
                color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic ? 'إشعار الصلاة' : 'Prayer Notification'),
            subtitle: Text(isArabic
                ? 'عرض موعد الصلاة القادم في الإشعار'
                : 'Show next prayer countdown in notification'),
            value: _backgroundNotificationEnabled,
            onChanged: (value) async {
              setState(() {
                _backgroundNotificationEnabled = value;
              });
              // Save to shared preferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppConstants.keyBackgroundNotificationEnabled, value);

              // Start or stop foreground service based on toggle
              if (value) {
                await BackgroundServiceManager.instance.startForegroundService();
              } else {
                await BackgroundServiceManager.instance.stopForegroundService();
              }
            },
          ),
          // Prayer Tracking Notifications Toggle
          Consumer(builder: (context, ref, _) {
            final enabled = ref.watch(prayerTrackingEnabledProvider);
            final timeStr = ref.watch(dailySummaryTimeProvider);
            final timeParts = timeStr.split(':');
            final hour = int.tryParse(timeParts[0]) ?? 21;
            final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
            return Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.track_changes, color: AppConstants.getPrimary(isDark)),
                  title: Text(isArabic ? 'تذكير تسجيل الصلاة' : 'Prayer Tracking Reminders'),
                  subtitle: Text(isArabic
                      ? 'إشعار بعد الصلاة وملخص يومي'
                      : 'Post-prayer check & daily summary'),
                  value: enabled,
                  onChanged: (value) {
                    ref.read(prayerTrackingEnabledProvider.notifier).setEnabled(value);
                  },
                ),
                if (enabled)
                  ListTile(
                    leading: Icon(Icons.schedule, color: AppConstants.getPrimary(isDark)),
                    title: Text(isArabic ? 'وقت الملخص اليومي' : 'Daily Summary Time'),
                    subtitle: Text(isArabic
                        ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
                        : '${hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)}:${minute.toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}'),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: hour, minute: minute),
                      );
                      if (picked != null) {
                        final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        await ref.read(dailySummaryTimeProvider.notifier).setTime(newTime);
                      }
                    },
                  ),
              ],
            );
          }),
          const SizedBox(height: AppConstants.paddingLarge),

          // ==================== PRAYER ALERTS SECTION ====================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingSmall,
            ),
            child: Text(
              isArabic ? 'تنبيهات الصلاة' : 'Prayer Alerts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          // Adhan Sound Toggle
          SwitchListTile(
            secondary:
                Icon(Icons.volume_up, color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic ? 'صوت الأذان' : 'Azan Sound'),
            subtitle: Text(isArabic
                ? 'تشغيل صوت الأذان عند موعد الصلاة'
                : 'Play azan sound at prayer time'),
            value: _adhanEnabled,
            onChanged: (value) async {
              setState(() {
                _adhanEnabled = value;
              });
              await AdhanPlayerService.instance.setEnabled(value);
            },
          ),
          const Divider(height: 1),
          // Download Adhan Sounds
          ListTile(
            leading: Icon(Icons.download_for_offline_outlined,
                color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic
                ? 'تحميل أصوات الأذان'
                : 'Download Adhan Sounds'),
            subtitle: Text(isArabic
                ? 'تصفح وتحميل أصوات مؤذنين مختلفين'
                : 'Browse and download different adhan reciters'),
            trailing: Icon(Icons.chevron_right,
                color: AppConstants.getPrimary(isDark)),
            onTap: () {
              Navigator.of(context).pushNamed('/adhan_downloads');
            },
          ),
          const Divider(height: 1),
          // Silent Mode Automation Toggle
          SwitchListTile(
            secondary: Icon(Icons.phone_paused,
                color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic
                ? 'الوضع الصامت التلقائي'
                : 'Auto Silent Mode'),
            subtitle: Text(
              isArabic
                  ? 'تشغيل الوضع الصامت تلقائياً عند الأذان لمدة $_silentModeDuration دقيقة'
                  : 'Enable silent mode at Adhan for $_silentModeDuration minutes',
            ),
            value: _silentModeEnabled,
            onChanged: (value) async {
              setState(() {
                _silentModeEnabled = value;
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppConstants.keySilentModeEnabled, value);
            },
          ),
          // Silent Mode Duration (only show if silent mode is enabled)
          if (_silentModeEnabled)
            ListTile(
              leading: Icon(Icons.timer_outlined,
                  color: AppConstants.getPrimary(isDark)),
              title: Text(isArabic
                  ? 'مدة الوضع الصامت'
                  : 'Silent Mode Duration'),
              subtitle: Text(
                isArabic
                    ? '$_silentModeDuration دقيقة'
                    : '$_silentModeDuration minutes',
              ),
              trailing:
                  Icon(Icons.chevron_right, color: AppConstants.getPrimary(isDark)),
              onTap: () => _showDurationDialog(context),
            ),

          const SizedBox(height: AppConstants.paddingLarge),

          // ==================== PRAYER EDITS SECTION ====================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingSmall,
            ),
            child: Text(
              isArabic ? 'تعديلات الصلاة' : 'Prayer Edits',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          // Iqama Times
          ListTile(
            leading: Icon(Icons.timer_outlined,
                color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic ? 'أوقات الإقامة' : 'Iqama Times'),
            subtitle: Text(isArabic
                ? 'تعديل وقت الإقامة لكل صلاة'
                : 'Adjust iqama time for each prayer'),
            trailing: Icon(Icons.chevron_right,
                color: AppConstants.getPrimary(isDark)),
            onTap: () {
              Navigator.of(context).pushNamed('/iqama_settings');
            },
          ),
          const Divider(height: 1),
          // Calculation Method
          ListTile(
            leading: Icon(Icons.calculate_outlined,
                color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic ? 'طريقة الحساب' : 'Calculation Method'),
            subtitle: Text(
              AdhanCalculationMethod.fromValue(_calculationMethod)
                  .getLocalizedName(isArabic),
            ),
            trailing: Icon(Icons.chevron_right,
                color: AppConstants.getPrimary(isDark)),
            onTap: () {
              PrayerCalculationSettingsDialog.show(
                context: context,
                currentMethod: _calculationMethod,
                currentMadhab: _asrMadhab,
                onMethodChanged: (value) {
                  setState(() {
                    _calculationMethod = value;
                  });
                  _saveCalculationSettings();
                },
                onMadhabChanged: (value) {
                  setState(() {
                    _asrMadhab = value;
                  });
                  _saveCalculationSettings();
                },
              );
            },
          ),
          const Divider(height: 1),
          // Asr Madhab
          ListTile(
            leading: Icon(Icons.mosque_outlined,
                color: AppConstants.getPrimary(isDark)),
            title: Text(isArabic ? 'مذهب العصر' : 'Asr Madhab'),
            subtitle: Text(
              AsrMadhab.fromValue(_asrMadhab).getLocalizedName(isArabic),
            ),
            trailing: Icon(Icons.chevron_right,
                color: AppConstants.getPrimary(isDark)),
            onTap: () {
              PrayerCalculationSettingsDialog.show(
                context: context,
                currentMethod: _calculationMethod,
                currentMadhab: _asrMadhab,
                onMethodChanged: (value) {
                  setState(() {
                    _calculationMethod = value;
                  });
                  _saveCalculationSettings();
                },
                onMadhabChanged: (value) {
                  setState(() {
                    _asrMadhab = value;
                  });
                  _saveCalculationSettings();
                },
              );
            },
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // ==================== TESTING SECTION ====================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingMedium,
              AppConstants.paddingSmall,
            ),
            child: Text(
              isArabic ? 'الاختبار' : 'Testing',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          // Test Adhan Button
          ListTile(
            leading: Icon(
              _isPlayingAdhan ? Icons.stop_circle : Icons.play_circle_outline,
              color: _isPlayingAdhan ? Colors.red : AppConstants.getPrimary(isDark),
            ),
            title: Text(
              _isPlayingAdhan
                  ? (isArabic ? 'إيقاف الأذان' : 'Stop Adhan')
                  : (isArabic ? 'اختبار الأذان' : 'Test Adhan'),
            ),
            subtitle: Text(
              _isPlayingAdhan
                  ? (isArabic
                      ? 'جاري تشغيل الأذان...'
                      : 'Playing adhan...')
                  : (isArabic
                      ? 'تشغيل الأذان للاختبار'
                      : 'Play adhan for testing'),
            ),
            onTap: _toggleAdhan,
          ),
          // Test Adhan Notification Button
          ListTile(
            leading: Icon(Icons.notifications_active_outlined,
                color: AppConstants.getPrimary(isDark)),
            title: Text(
              isArabic ? 'اختبار إشعار الأذان' : 'Test Adhan Notification',
            ),
            subtitle: Text(
              isArabic
                  ? 'يشغل الإشعار والشاشة الكاملة بعد 10 ثوان'
                  : 'Triggers notification & full screen in 10 sec',
            ),
            trailing: Icon(Icons.play_arrow, color: AppConstants.getPrimary(isDark)),
            onTap: () async {
              await PrayerAlarmService.instance.testAdhanNow('Maghrib');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic
                        ? 'تم تشغيل إشعار الأذان'
                        : 'Adhan notification triggered'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          // Test Notification Button
          ListTile(
            leading: Icon(Icons.notifications_active_outlined,
                color: AppConstants.getPrimary(isDark)),
            title: Text('test_notification'.tr()),
            subtitle: Text('test_notification_desc'.tr()),
            trailing: Icon(Icons.chevron_right,
                color: AppConstants.getPrimary(isDark)),
            onTap: () async {
              await NotificationService.instance.showTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('test_notification_sent'.tr()),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          // Check Notification Status Button
          ListTile(
            leading: const Icon(Icons.bug_report_outlined,
                color: Colors.orange),
            title: Text('check_notification_status'.tr()),
            subtitle: Text('check_notification_status_desc'.tr()),
            trailing: Icon(Icons.chevron_right,
                color: AppConstants.getPrimary(isDark)),
            onTap: () async {
              await NotificationService.instance.debugCheckNotificationStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('debug_info_shown'.tr()),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: AppConstants.paddingMedium),
          ],
        ),
      );
  }

  /// Save calculation settings
  Future<void> _saveCalculationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyCalculationMethod, _calculationMethod);
    await prefs.setString(AppConstants.keyAsrMadhab, _asrMadhab);
    debugPrint('Saved calculation settings: $_calculationMethod, $_asrMadhab');

    // Refresh prayer times with new calculation settings
    if (mounted) {
      // Navigate back and refresh
      Navigator.pop(context);
      // The parent screen will refresh when we return
    }
  }
}

class _ToolkitAction {
  final IconData icon;
  final String label;
  final String? route;
  final Color color;

  const _ToolkitAction({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

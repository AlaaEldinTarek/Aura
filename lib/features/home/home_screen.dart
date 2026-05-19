import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/models/prayer_time.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/daily_prayer_status_provider.dart';
import '../../core/providers/task_provider.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/info_tip_icon.dart';
import '../../core/widgets/tutorial_overlay.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/services/shared_preferences_service.dart';
import '../../core/widgets/greeting_widget.dart';
import '../../core/widgets/permission_dialog.dart';
import '../../core/widgets/task_card.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/services/task_service.dart';
import '../../core/models/task.dart';
import '../../core/models/prayer_record.dart';
import '../../core/models/daily_content.dart';
import '../../core/services/daily_content_service.dart';
import '../../core/widgets/prayer_status_dialog.dart';
import '../../core/services/prayer_tracking_service.dart' show PrayerTrackingService;
import '../../core/utils/prayer_time_rules.dart';
import '../../core/providers/islamic_events_provider.dart';
import '../../core/models/islamic_event.dart';
import '../../core/utils/hijri_date.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;

  // ValueNotifier for countdown - only rebuilds the countdown widget, not entire screen
  final ValueNotifier<Duration> _countdownNotifier = ValueNotifier(Duration.zero);

  // GlobalKeys for tutorial overlay targeting
  final _greetingKey = GlobalKey();
  final _dailyContentKey = GlobalKey();
  final _nextPrayerKey = GlobalKey();
  final _prayerProgressKey = GlobalKey();
  final _taskProgressKey = GlobalKey();
  final _todayTasksKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load prayer statuses via shared provider (cached, won't hit Firestore if fresh)
    Future.microtask(() => ref.read(dailyPrayerStatusProvider.notifier).load());
    _startCountdownTimer();
  }

  void _onPermissionsDone() {
    if (!mounted) return;
    if (!SharedPreferencesService.instance.isTutorialCompleted()) {
      _launchTutorialWhenActive();
    }
  }

  void _launchTutorialWhenActive() {
    if (!mounted) return;
    // Only launch when home screen is the topmost route (permissions page fully gone)
    if (ModalRoute.of(context)?.isCurrent == true) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _launchTutorial();
        }
      });
    } else {
      // Another route is still on top — retry every 300ms
      Future.delayed(const Duration(milliseconds: 300), _launchTutorialWhenActive);
    }
  }

  void _launchTutorial() {
    if (!mounted) return;
    final appMode = ref.read(appModeProvider);
    final showPrayer = appMode != AppMode.tasksOnly;
    final showTasks = appMode != AppMode.prayerOnly;

    final steps = <TutorialStep>[
      if (_greetingKey.currentContext != null)
        TutorialStep(
          targetKey: _greetingKey,
          titleKey: 'tutorial_welcome_title',
          bodyKey: 'tutorial_welcome_body',
        ),
      if (showPrayer && _dailyContentKey.currentContext != null)
        TutorialStep(
          targetKey: _dailyContentKey,
          titleKey: 'tutorial_daily_content_title',
          bodyKey: 'tutorial_daily_content_body',
        ),
      if (showPrayer && _nextPrayerKey.currentContext != null)
        TutorialStep(
          targetKey: _nextPrayerKey,
          titleKey: 'tutorial_next_prayer_title',
          bodyKey: 'tutorial_next_prayer_body',
        ),
      if (showPrayer && _prayerProgressKey.currentContext != null)
        TutorialStep(
          targetKey: _prayerProgressKey,
          titleKey: 'tutorial_prayer_progress_title',
          bodyKey: 'tutorial_prayer_progress_body',
        ),
      if (showTasks && _taskProgressKey.currentContext != null)
        TutorialStep(
          targetKey: _taskProgressKey,
          titleKey: 'tutorial_task_progress_title',
          bodyKey: 'tutorial_task_progress_body',
        ),
      if (showTasks && _todayTasksKey.currentContext != null)
        TutorialStep(
          targetKey: _todayTasksKey,
          titleKey: 'tutorial_today_tasks_title',
          bodyKey: 'tutorial_today_tasks_body',
        ),
      if (AuraBottomNavBar.navBarKey.currentContext != null)
        TutorialStep(
          targetKey: AuraBottomNavBar.navBarKey,
          titleKey: 'tutorial_nav_title',
          bodyKey: 'tutorial_nav_body',
        ),
    ];

    if (steps.isEmpty) return;

    showTutorial(
      context: context,
      steps: steps,
      onDone: () => SharedPreferencesService.instance.setTutorialCompleted(true),
    );
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final prayer = ref.read(prayerTimesProvider).nextPrayer;
      if (prayer == null) return;
      final diff = prayer.time.difference(DateTime.now());
      _countdownNotifier.value = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _countdownTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startCountdownTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  String _getPrayerIconAsset(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
      case 'sunrise':
        return 'assets/images/ic_prayer_fajr.png';
      case 'dhuhr':
      case 'zuhr':
        return 'assets/images/ic_prayer_dhuhr.png';
      case 'asr':
        return 'assets/images/ic_prayer_asr.png';
      case 'maghrib':
        return 'assets/images/ic_prayer_maghrib.png';
      case 'isha':
        return 'assets/images/ic_prayer_isha.png';
      default:
        return 'assets/images/ic_prayer_fajr.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // select() ensures rebuild only when the specific field changes, not the entire provider state
    final nextPrayer = ref.watch(prayerTimesProvider.select((s) => s.nextPrayer));
    final _firebaseUser = ref.watch(currentUserProvider);
    final userName = _firebaseUser?.displayName?.isNotEmpty == true
        ? _firebaseUser!.displayName!
        : (_firebaseUser?.email?.split('@').first ?? '');
    final isGuest = ref.watch(guestModeProvider.select((async) => async.value ?? false));
    final appMode = ref.watch(appModeProvider.select((m) => m));
    final showPrayer = appMode != AppMode.tasksOnly;
    final showTasks = appMode != AppMode.prayerOnly;

    // Calculate prayer progress from shared provider
    final prayerStatuses = ref.watch(dailyPrayerStatusProvider.select((s) => s.statuses));
    final trackablePrayers = kPrayerNames;
    final completedCount = trackablePrayers.where((p) {
      final status = prayerStatuses[p];
      return status == PrayerStatus.onTime || status == PrayerStatus.late;
    }).length;
    final totalPrayers = trackablePrayers.length;

    ref.listen(showTutorialProvider, (_, show) {
      if (show) {
        ref.read(showTutorialProvider.notifier).state = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _launchTutorial());
      }
    });

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
              padding: EdgeInsets.all(MediaQuery.textScalerOf(context).scale(AppSpacing.base).clamp(0, 16.0)),
              child: _buildHomeBody(
                context, isDark, isArabic, showPrayer, showTasks,
                nextPrayer, completedCount, totalPrayers, prayerStatuses,
                userName: isGuest ? '' : userName,
                isGuest: isGuest,
              ),
            ),
          ),
          // Permission dialog handler (shows dialogs after home loads)
          PermissionDialogHandler(onDone: _onPermissionsDone),
        ],
      ),
    );
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Widget _buildHomeBody(
    BuildContext context,
    bool isDark,
    bool isArabic,
    bool showPrayer,
    bool showTasks,
    PrayerTime? nextPrayer,
    int completedCount,
    int totalPrayers,
    Map<String, PrayerStatus> prayerStatuses, {
    required String userName,
    required bool isGuest,
  }) {
    final footer = Center(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
        child: Text(
          '${'version'.tr()} 1.0.2',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ),
    );

    // ── Desktop: single-column layout ──────────────────────────────────────
    if (_isDesktop) {
      final ts = MediaQuery.textScalerOf(context);
      final gapL = ts.scale(AppConstants.paddingLarge).clamp(0.0, 28.0);
      final gapM = ts.scale(AppConstants.paddingMedium).clamp(0.0, 18.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: _greetingKey,
            child: GreetingWidget(
              userName: isGuest ? null : (userName.isNotEmpty ? userName : null),
              onTap: () => Navigator.of(context).pushNamed('/prayer'),
            ).animate().fadeIn(duration: 400.ms),
          ),
          if (showPrayer) ...[
            SizedBox(height: gapL),
            SizedBox(
              key: _dailyContentKey,
              child: _buildDailyContentCard(context, isDark, isArabic),
            ),
          ],
          if (showPrayer && DateTime.now().weekday == DateTime.friday) ...[
            SizedBox(height: gapL),
            _buildJumuahBanner(context, isDark, isArabic),
          ],
          if (showPrayer) Builder(builder: (ctx) {
            final events = ref.watch(islamicEventsProvider);
            if (events.isEmpty || events.first.daysUntil > 30) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(height: gapL),
              _buildIslamicEventCard(context, events.first, isDark, isArabic),
            ]);
          }),
          if (showPrayer) ...[
            SizedBox(height: gapL),
            SizedBox(key: _nextPrayerKey,
              child: _buildNextPrayerCard(context, nextPrayer, isDark, isArabic, completedCount, totalPrayers)),
            SizedBox(height: gapM),
            SizedBox(key: _prayerProgressKey,
              child: _buildPrayerProgress(context, isDark, isArabic, completedCount, totalPrayers, prayerStatuses)),
          ],
          if (showTasks) ...[
            SizedBox(height: gapL),
            SizedBox(key: _taskProgressKey,
              child: _buildTaskProgress(context, isDark, isArabic)),
            SizedBox(height: gapL),
            SizedBox(key: _todayTasksKey,
              child: _buildTodayTasksPreview(context, isDark, isArabic)),
          ],
          footer,
        ],
      );
    }

    // ── Mobile: original single-column layout (maxWidth 800 preserved) ────────
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: _greetingKey,
          child: GreetingWidget(
            userName: isGuest ? null : (userName.isNotEmpty ? userName : null),
            onTap: () => Navigator.of(context).pushNamed('/prayer'),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
        ),
        if (showPrayer) ...[
          const SizedBox(height: 12),
          SizedBox(
            key: _dailyContentKey,
            child: _buildDailyContentCard(context, isDark, isArabic)
                .animate().fadeIn(delay: 50.ms, duration: 400.ms).slideY(begin: 0.08),
          ),
        ],
        if (showPrayer && DateTime.now().weekday == DateTime.friday) ...[
          const SizedBox(height: 12),
          _buildJumuahBanner(context, isDark, isArabic)
              .animate().fadeIn(delay: 80.ms, duration: 500.ms).slideY(begin: 0.08),
        ],
        if (showPrayer) Builder(builder: (ctx) {
          final events = ref.watch(islamicEventsProvider);
          if (events.isEmpty || events.first.daysUntil > 30) return const SizedBox.shrink();
          return Column(children: [
            const SizedBox(height: 12),
            _buildIslamicEventCard(context, events.first, isDark, isArabic)
                .animate().fadeIn(delay: 90.ms, duration: 400.ms).slideY(begin: 0.08),
          ]);
        }),
        const SizedBox(height: 12),
        if (showPrayer) ...[
          SizedBox(
            key: _nextPrayerKey,
            child: _buildNextPrayerCard(context, nextPrayer, isDark, isArabic, completedCount, totalPrayers)
                .animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),
          ),
          const SizedBox(height: 8),
          SizedBox(
            key: _prayerProgressKey,
            child: _buildPrayerProgress(context, isDark, isArabic, completedCount, totalPrayers, prayerStatuses)
                .animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
          ),
          const SizedBox(height: 12),
        ],
        if (showTasks) ...[
          SizedBox(
            key: _taskProgressKey,
            child: _buildTaskProgress(context, isDark, isArabic)
                .animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.1),
          ),
          const SizedBox(height: 12),
          SizedBox(
            key: _todayTasksKey,
            child: _buildTodayTasksPreview(context, isDark, isArabic)
                .animate().fadeIn(delay: 350.ms, duration: 400.ms).slideY(begin: 0.1),
          ),
          const SizedBox(height: 12),
        ],
        footer,
        const SizedBox(height: 80),
      ],
      ),
    );
  }

  Widget _buildDailyContentCard(BuildContext context, bool isDark, bool isArabic) {
    final content = DailyContentService.instance.getToday();
    final isAyah = content.type == DailyContentType.ayah;
    final primary = AppConstants.getPrimary(isDark);

    final String typeLabel = isAyah
        ? (isArabic ? '📖 آية اليوم' : '📖 Verse of the Day')
        : (isArabic ? '📜 حديث اليوم' : '📜 Hadith of the Day');

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/daily_content'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: primary.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row: label + source badge
            Row(
              children: [
                Text(
                  typeLabel,
                  style: AppTypography.labelS.copyWith(color: primary),
                ),
                InfoTipIcon(
                  titleKey: 'info_tip_daily_content_title',
                  bodyKey: 'info_tip_daily_content_body',
                  key: Key('tip_$typeLabel'),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    content.source,
                    style: AppTypography.caption.copyWith(color: primary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Divider
            Divider(height: 1, color: primary.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            // Arabic text — centered, RTL
            Text(
              content.arabic,
              style: AppTypography.ar(AppTypography.bodyL).copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2A2418),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Small amber center line
            Center(
              child: Container(
                width: 36,
                height: 2,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Translation
            Text(
              content.translation,
              style: AppTypography.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white60 : AppConstants.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayPrayerName(String name, bool isArabic) =>
      getPrayerDisplayName(name, isArabic: isArabic);

  Widget _buildJumuahBanner(BuildContext context, bool isDark, bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF5C4200), const Color(0xFF3D2C00)]
              : [const Color(0xFFFFF3CC), const Color(0xFFFFE484)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: const Color(0xFFD4A017).withOpacity(isDark ? 0.6 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A017).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD4A017).withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: const Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text('🕌', style: TextStyle(fontSize: 26)))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(builder: (ctx) {
              final mq = MediaQuery.of(ctx);
              final cappedScale = mq.textScaler.scale(1.0).clamp(0.9, 1.5);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(cappedScale)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'جمعة مباركة' : "Jumu'ah Mubarak",
                      style: (isArabic
                              ? AppTypography.ar(AppTypography.bodyL)
                              : AppTypography.bodyL)
                          .copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFFD966) : const Color(0xFF7A5700),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isArabic
                          ? 'جعلها الله جمعة مباركة وتقبّل صلاتك'
                          : 'May Allah bless your Friday and accept your prayers',
                      style: (isArabic
                              ? AppTypography.ar(AppTypography.caption)
                              : AppTypography.caption)
                          .copyWith(
                        color: isDark
                            ? const Color(0xFFFFD966).withOpacity(0.75)
                            : const Color(0xFF7A5700).withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildIslamicEventCard(
    BuildContext context,
    IslamicEventWithDate item,
    bool isDark,
    bool isArabic,
  ) {
    final primary = AppConstants.getPrimary(isDark);
    final Color accent = item.daysUntil == 0
        ? Colors.green
        : item.daysUntil <= 7
            ? const Color(0xFFFF8F00)
            : primary;

    String countdown;
    if (item.daysUntil == 0) {
      countdown = isArabic ? 'اليوم!' : 'Today!';
    } else if (item.daysUntil == 1) {
      countdown = isArabic ? 'غداً' : 'Tomorrow';
    } else {
      final n = NumberFormatter.withArabicNumeralsByLanguage(
        item.daysUntil.toString(),
        isArabic ? 'ar' : 'en',
      );
      countdown = isArabic ? 'بعد $n يوم' : 'in $n days';
    }

    final h = HijriDate.toHijri(item.date);
    final hijriLabel = isArabic ? HijriDate.formatAr(h) : HijriDate.formatEn(h);

    final tsPad = MediaQuery.textScalerOf(context).scale(AppConstants.paddingMedium);
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/islamic_events'),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(tsPad),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.15), accent.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Builder(builder: (ctx2) {
          final ets = MediaQuery.textScalerOf(ctx2);
          final eContSz = ets.scale(48.0).clamp(0.0, 72.0);
          return Row(
          children: [
            Container(
              width: eContSz,
              height: eContSz,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Center(child: Text(item.event.emoji, style: TextStyle(fontSize: ets.scale(26.0).clamp(0, 40.0)))),
            ),
            SizedBox(width: ets.scale(12.0).clamp(0, 16.0)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? item.event.nameAr : item.event.nameEn,
                    style: (isArabic
                            ? AppTypography.ar(AppTypography.bodyM)
                            : AppTypography.bodyM)
                        .copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hijriLabel,
                    style: AppTypography.caption.copyWith(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    countdown,
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: accent),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 16, color: accent.withOpacity(0.6)),
              ],
            ),
          ],
        );
        }),
      ),
    );
  }

  Widget _buildNextPrayerCard(
    BuildContext context,
    PrayerTime? nextPrayer,
    bool isDark,
    bool isArabic,
    int completedCount,
    int totalPrayers,
  ) {
    final hasData = nextPrayer != null;
    final pad = MediaQuery.textScalerOf(context).scale(AppConstants.paddingMedium);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/prayer'),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: isDark
                ? AppConstants.getPrimary(isDark).withOpacity(0.12)
                : AppConstants.getPrimary(isDark).withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: AppConstants.getPrimary(isDark).withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Prayer icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppConstants.getPrimary(isDark).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Image.asset(
                        hasData
                            ? _getPrayerIconAsset(nextPrayer.name)
                            : 'assets/images/ic_prayer_fajr.png',
                        width: 28,
                        height: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),

                  // Prayer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الصلاة القادمة' : 'Next Prayer',
                          style: AppTypography.caption.copyWith(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasData
                              ? _getDisplayPrayerName(nextPrayer.name, isArabic)
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
                      final mq = MediaQuery.of(context);
                      final cappedScale = mq.textScaler.scale(1.0).clamp(0.9, 1.5);
                      return MediaQuery(
                        data: mq.copyWith(textScaler: TextScaler.linear(cappedScale)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCountdown(remaining, isArabic),
                              style: AppTypography.headingM.copyWith(
                                color: AppConstants.getPrimary(isDark),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              isArabic ? 'حتى الأذان' : 'Until Adhan',
                              style: AppTypography.caption.copyWith(
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
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
                    color: AppConstants.getPrimary(isDark).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: AppConstants.getPrimary(isDark).withOpacity(0.7), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isArabic
                                ? NumberFormatter.withArabicNumeralsByLanguage(
                                    nextPrayer.time12h.replaceAll('AM', 'ص').replaceAll('PM', 'م'), 'ar')
                                : nextPrayer.time12h,
                            style: AppTypography.bodyS.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppConstants.getPrimary(isDark).withOpacity(0.7), size: 14),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            isArabic
                                ? '${NumberFormatter.withArabicNumerals('$completedCount')} من ${NumberFormatter.withArabicNumerals('$totalPrayers')}'
                                : '$completedCount/$totalPrayers',
                            style: AppTypography.bodyS.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
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

    final prayerIconAssets = [
      'assets/images/ic_prayer_fajr.png',
      'assets/images/ic_prayer_dhuhr.png',
      'assets/images/ic_prayer_asr.png',
      'assets/images/ic_prayer_maghrib.png',
      'assets/images/ic_prayer_isha.png',
    ];
    final trackablePrayers = kPrayerNames;

    return Container(
      padding: EdgeInsets.all(MediaQuery.textScalerOf(context).scale(AppConstants.paddingMedium)),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'تقدم الصلوات اليوم' : "Today's Prayer Progress",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const InfoTipIcon(
                    titleKey: 'info_tip_prayer_progress_title',
                    bodyKey: 'info_tip_prayer_progress_body',
                  ),
                ],
              ),
              Text(
                isArabic
                    ? NumberFormatter.withArabicNumeralsByLanguage('$completedCount/${kPrayerNames.length}', 'ar')
                    : '$completedCount/${kPrayerNames.length}',
                style: AppTypography.label.copyWith(
                  color: AppConstants.getPrimary(isDark),
                  fontWeight: FontWeight.bold,
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
                progress >= 1.0 ? Colors.green : AppConstants.getPrimary(isDark),
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
              final ts = MediaQuery.textScalerOf(context);
              final circleSize = ts.scale(34.0);
              final iconSize = ts.scale(20.0);
              final imgSize = ts.scale(18.0);

              Color color;
              IconData icon;
              if (status == PrayerStatus.onTime) {
                color = Colors.green;
                icon = Icons.check_circle;
              } else if (status == PrayerStatus.late) {
                color = Colors.orange;
                icon = Icons.schedule;
              } else if (status == PrayerStatus.missed) {
                color = Colors.red;
                icon = Icons.cancel;
              } else if (status == PrayerStatus.excused) {
                color = Colors.red;
                icon = Icons.cancel;
              } else {
                color = isDark ? AppConstants.darkBorder : AppConstants.lightBorder;
                icon = Icons.circle_outlined;
              }

              return GestureDetector(
                onTap: () => _markPrayerFromHome(context, trackablePrayers[i], isArabic),
                child: Column(
                  children: [
                    Container(
                      width: circleSize,
                      height: circleSize,
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
                            ? Icon(icon, color: color, size: iconSize)
                            : Image.asset(prayerIconAssets[i], width: imgSize, height: imgSize),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Builder(builder: (ctx) {
                      final mq = MediaQuery.of(ctx);
                      final cappedScale = mq.textScaler.scale(1.0).clamp(0.9, 1.3);
                      return MediaQuery(
                        data: mq.copyWith(textScaler: TextScaler.linear(cappedScale)),
                        child: Text(
                          isArabic
                              ? ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'][i]
                              : kPrayerNames[i],
                          style: AppTypography.caption.copyWith(
                            fontSize: 9,
                            color: isTracked ? color : (isDark ? Colors.white54 : Colors.black54),
                            fontWeight: isTracked ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
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
        // Show TODAY's task completion progress
        final allTasksAsync = ref.watch(allTasksProvider);
        return allTasksAsync.when(
          data: (allTasks) {
            final todayTasks = allTasks.where((t) => t.isDueToday || t.dueDate == null).toList();
            final todayDone = todayTasks.where((t) => t.isCompleted).length;
            final todayTotal = todayTasks.length;
            final progress = todayTotal > 0 ? todayDone / todayTotal : 0.0;
            final percentage = (progress * 100).round();

        return Container(
          padding: EdgeInsets.all(MediaQuery.textScalerOf(context).scale(AppConstants.paddingMedium)),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          ),
          child: Row(
            children: [
              // Progress ring
              Builder(builder: (ctx) {
                final ts = MediaQuery.textScalerOf(ctx);
                final ringSize = ts.scale(64.0);
                return SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.green : AppConstants.getPrimary(isDark),
                        ),
                      ),
                      Center(
                        child: Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: ts.scale(15.0),
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(width: AppSpacing.base),
              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic ? 'تقدم المهام' : 'Task Progress',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const InfoTipIcon(
                              titleKey: 'info_tip_task_progress_title',
                              bodyKey: 'info_tip_task_progress_body',
                            ),
                          ],
                        ),
                        Text(
                          todayTotal > 0
                              ? (isArabic ? '${NumberFormatter.withArabicNumerals('$todayDone')} من ${NumberFormatter.withArabicNumerals('$todayTotal')}' : '$todayDone of $todayTotal')
                              : (isArabic ? 'لا مهام' : 'No tasks'),
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: progress >= 1.0 ? Colors.green : AppConstants.getPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (todayTotal > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? Colors.green : AppConstants.getPrimary(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        _buildMiniStat(Icons.today, '$todayTotal',
                            isArabic ? 'اليوم' : 'Today', AppConstants.getPrimary(isDark)),
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
    return Builder(builder: (ctx) {
      final ts = MediaQuery.textScalerOf(ctx);
      final iconSz = ts.scale(13.0);
      final textSz = ts.scale(13.0);
      final labelSz = ts.scale(10.0);
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSz, color: color),
              SizedBox(width: ts.scale(3.0)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: textSz, color: color)),
            ],
          ),
          Text(label, style: TextStyle(fontSize: labelSz, color: color.withOpacity(0.7))),
        ],
      );
    });
  }

  Widget _buildTodayTasksPreview(BuildContext context, bool isDark, bool isArabic) {
    final allTasksAsync = ref.watch(allTasksProvider);
    final statsAsync = ref.watch(taskStatisticsProvider);

    return Container(
      padding: EdgeInsets.all(MediaQuery.textScalerOf(context).scale(AppConstants.paddingMedium)),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'مهام اليوم' : "Today's Tasks",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const InfoTipIcon(
                    titleKey: 'info_tip_today_tasks_title',
                    bodyKey: 'info_tip_today_tasks_body',
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to main Tasks tab (index 3 in bottom nav)
                  ref.read(tabNavigationProvider.notifier).state = 3;
                },
                child: Text(
                  isArabic ? 'عرض الكل' : 'View All',
                  style: AppTypography.caption.copyWith(
                    color: AppConstants.getPrimary(isDark),
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
                          progress >= 1.0 ? Colors.green : AppConstants.getPrimary(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic
                          ? '${NumberFormatter.withArabicNumerals('$done')} من ${NumberFormatter.withArabicNumerals('${stats.dueToday}')} مكتملة'
                          : '$done of ${stats.dueToday} completed',
                      style: AppTypography.caption.copyWith(
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
                  allTasks.where((t) => !t.isCompleted && (t.isDueToday || t.dueDate == null)).toList();
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
                        style: AppTypography.bodyS.copyWith(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: Column(
                  key: ValueKey(toShow.take(3).map((t) => t.id).join()),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (todayTasks.isEmpty && upcomingTasks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          isArabic ? 'قريباً' : 'Upcoming',
                          style: AppTypography.caption.copyWith(
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
                ),
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

  Future<void> _markPrayerFromHome(BuildContext context, String prayerName, bool isArabic) async {
    // Use the same 20-min rule as the prayer screen
    final prayerTimes = ref.read(prayerTimesProvider).prayerTimes;
    if (!canMarkPrayer(
      context: context,
      prayerName: prayerName,
      prayerTimes: prayerTimes,
      isArabic: isArabic,
    )) return;

    final chosenStatus = await showPrayerStatusDialog(
      context: context,
      prayerName: prayerName,
      isArabic: isArabic,
    );
    if (chosenStatus == null || !mounted) return;

    // Optimistic update: UI reflects change instantly before Firestore write
    ref.read(dailyPrayerStatusProvider.notifier).updatePrayer(prayerName, chosenStatus);

    final userId = getCurrentUserId();
    final now = DateTime.now();
    final fajrTime = prayerTimes.where((p) => p.name == 'Fajr').firstOrNull?.time;
    await PrayerTrackingService.instance.recordPrayer(
      userId: userId,
      prayerName: prayerName,
      date: getPrayerDate(now, fajrTime: fajrTime),
      prayedAt: now,
      status: chosenStatus,
    );
  }

  Future<void> _toggleTask(String taskId) async {
    final userId = getCurrentUserId();
    try {
      // Check if this is the last today task before toggling
      final tasks = ref.read(allTasksProvider).valueOrNull ?? [];
      final todayIncomplete = tasks.where((t) => (t.isDueToday || t.dueDate == null) && !t.isCompleted);
      final wasLastTask = todayIncomplete.length == 1 && todayIncomplete.first.id == taskId;

      await TaskService.instance.toggleTaskCompletion(
        userId: userId,
        taskId: taskId,
      );

      // Refresh providers so stats update immediately
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);

      // If this was the last today task, increment streak + celebrate
      if (wasLastTask) {
        await _incrementStreak();
        setState(() {});
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showCelebration();
        });
      }
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  void _showCelebration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final overlay = OverlayEntry(
      builder: (_) => _HomeCelebrationOverlay(isDark: isDark, isArabic: isArabic),
    );
    Overlay.of(context).insert(overlay);
    Future.delayed(const Duration(seconds: 3), () => overlay.remove());
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
      padding: EdgeInsets.all(MediaQuery.textScalerOf(context).scale(AppConstants.paddingMedium)),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
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
                        progress >= 1.0 ? Colors.green : AppConstants.getPrimary(isDark),
                      ),
                    ),
                    Center(
                      child: Text(
                        '$displayPercentage%',
                        style: AppTypography.bodyL.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              // Prayer dots
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: kPrayerNames.map((name) {
                    final prayerNamesAr = {
                      'Fajr': 'الفجر', 'Zuhr': 'الظهر', 'Asr': 'العصر', 'Maghrib': 'المغرب', 'Isha': 'العشاء',
                    };
                    final displayName = isArabic ? (prayerNamesAr[name] ?? name) : name;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Image.asset(_getPrayerIconAsset(name), width: 16, height: 16),
                          const SizedBox(width: 6),
                          Text(displayName, style: AppTypography.caption.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
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

        return Container(
          padding: EdgeInsets.all(MediaQuery.textScalerOf(context).scale(AppSpacing.base)),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
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
              const SizedBox(height: AppSpacing.sm),
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
                      Image.asset(_getPrayerIconAsset(record.prayerName), width: 20, height: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabic ? record.prayerName : record.prayerName,
                          style: AppTypography.bodyS.copyWith(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusText,
                          style: AppTypography.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        displayTime,
                        style: AppTypography.caption.copyWith(color: isDark ? Colors.white38 : Colors.black38),
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

class _HomeCelebrationOverlay extends StatefulWidget {
  final bool isDark;
  final bool isArabic;
  const _HomeCelebrationOverlay({required this.isDark, required this.isArabic});

  @override
  State<_HomeCelebrationOverlay> createState() => _HomeCelebrationOverlayState();
}

class _HomeCelebrationOverlayState extends State<_HomeCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Positioned.fill(
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Container(
                color: AppConstants.getPrimary(isDark).withValues(alpha: 0.12 * _opacityAnim.value),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 36),
                      decoration: BoxDecoration(
                        color: widget.isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppConstants.getPrimary(isDark).withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.getPrimary(isDark).withValues(alpha: 0.22),
                            blurRadius: 36,
                            offset: const Offset(0, 10),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppConstants.getPrimary(isDark), AppConstants.accentCyan],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.check_rounded, size: 42, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (i) => Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: i == 1 ? 0.9 : 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                  )),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                            child: Column(
                              children: [
                                Text(
                                  widget.isArabic ? 'أُنجز الكل! ✨' : 'All Done! ✨',
                                  style: AppTypography.headingL.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.isArabic
                                      ? 'أكملت جميع مهام اليوم، استمر!'
                                      : 'You crushed every task today!',
                                  style: AppTypography.label.copyWith(
                                    height: 1.5,
                                    color: widget.isDark ? Colors.white60 : Colors.black45,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppConstants.getPrimary(isDark).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: AppConstants.getPrimary(isDark).withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    widget.isArabic ? '🎯  يوم منتج!' : '🎯  Productive day!',
                                    style: AppTypography.bodyS.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.getPrimary(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

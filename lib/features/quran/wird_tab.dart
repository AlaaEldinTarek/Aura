import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/providers/auth_provider.dart' show isLoggedInProvider;
import 'package:aura_app/core/providers/connectivity_provider.dart' show isOnlineProvider;
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import 'package:aura_app/core/widgets/info_tip_icon.dart';
import 'package:aura_app/core/widgets/tutorial_overlay.dart';
import 'package:aura_app/core/services/shared_preferences_service.dart';
import 'quran_reader_screen.dart';
import 'khatma_celebration_screen.dart';
import 'wird_marker_widgets.dart';
import 'package:aura_app/core/theme/app_typography.dart';
import 'package:aura_app/core/theme/app_spacing.dart';

/// Computes the counted-pages set for page-mode "Choose One" (F38c).
///
/// Same color already linked: existing counted pages plus the chosen page;
/// `alreadyCounted` is true when the chosen page was already in the set.
/// Not linked, or a different color: all pages of the chosen color plus the
/// chosen page (the current bookmarks become the baseline); never already
/// counted.
@visibleForTesting
({Set<int> counted, bool alreadyCounted}) countedPagesAfterChooseOne({
  required String? linkedColor,
  required Set<int> existingCounted,
  required String chosenColor,
  required int chosenPage,
  required Set<int> colorPages,
}) {
  if (linkedColor == chosenColor) {
    return (
      counted: {...existingCounted, chosenPage},
      alreadyCounted: existingCounted.contains(chosenPage),
    );
  }
  return (counted: {...colorPages, chosenPage}, alreadyCounted: false);
}

class WirdTab extends ConsumerWidget {
  final String lang;

  const WirdTab({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wirdAsync = ref.watch(wirdStateProvider);

    return wirdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (wirdState) {
        return _WirdContentView(initialState: wirdState, lang: lang);
      },
    );
  }
}

class _WirdContentView extends ConsumerStatefulWidget {
  final WirdState initialState;
  final String lang;

  const _WirdContentView({required this.initialState, required this.lang});

  @override
  ConsumerState<_WirdContentView> createState() => _WirdContentViewState();
}

class _WirdContentViewState extends ConsumerState<_WirdContentView> {
  bool _undoBusy = false;
  bool _khatmaHandled = false;

  final _streakKey = GlobalKey();
  final _progressKey = GlobalKey();
  final _actionsKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _settingsKey = GlobalKey();
  final _juzGridKey = GlobalKey();
  final _juzScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = SharedPreferencesService.instance;
      if (!prefs.isTutorialWirdSeen()) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) _launchWirdTutorial();
      }
    });
  }

  void _launchWirdTutorial() {
    if (!mounted) return;
    final state = ref.read(wirdStateProvider).valueOrNull ?? widget.initialState;
    final isJuzMode = state.settings.wirdUnit == WirdUnit.juz;
    final steps = <TutorialStep>[
      if (_streakKey.currentContext != null)
        TutorialStep(
          targetKey: _streakKey,
          titleKey: 'tutorial_wird_streak_title',
          bodyKey: 'tutorial_wird_streak_body',
        ),
      if (_progressKey.currentContext != null)
        TutorialStep(
          targetKey: _progressKey,
          titleKey: isJuzMode ? 'tutorial_wird_juz_progress_title' : 'tutorial_wird_progress_title',
          bodyKey: isJuzMode ? 'tutorial_wird_juz_progress_body' : 'tutorial_wird_progress_body',
        ),
      if (_actionsKey.currentContext != null)
        TutorialStep(
          targetKey: _actionsKey,
          titleKey: isJuzMode ? 'tutorial_wird_juz_actions_title' : 'tutorial_wird_actions_title',
          bodyKey: isJuzMode ? 'tutorial_wird_juz_actions_body' : 'tutorial_wird_actions_body',
        ),
      if (isJuzMode && _juzGridKey.currentContext != null)
        TutorialStep(
          targetKey: _juzGridKey,
          titleKey: 'tutorial_wird_juz_grid_title',
          bodyKey: 'tutorial_wird_juz_grid_body',
        ),
      if (_statsKey.currentContext != null)
        TutorialStep(
          targetKey: _statsKey,
          titleKey: 'tutorial_wird_stats_title',
          bodyKey: 'tutorial_wird_stats_body',
        ),
      if (_settingsKey.currentContext != null)
        TutorialStep(
          targetKey: _settingsKey,
          titleKey: 'tutorial_wird_settings_title',
          bodyKey: 'tutorial_wird_settings_body',
        ),
    ];
    if (steps.isEmpty) return;
    showTutorial(
      context: context,
      steps: steps,
      onDone: () => SharedPreferencesService.instance.setTutorialWirdSeen(),
    );
  }

  Future<void> _handleJuzKhatma() async {
    if (!mounted) return;
    final legacyCount = await ref.read(wirdStateProvider.notifier).resetJuzForKhatma();
    if (!mounted) return;
    // The reloaded state holds the combined count (juz + page-mode khatmas).
    final count = ref.read(wirdStateProvider).valueOrNull?.khatmCount ?? legacyCount;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KhatmaCelebrationScreen(khatmCount: count, date: DateTime.now()),
      ),
    );
  }

  @override
  void dispose() {
    _juzScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wirdAsync = ref.watch(wirdStateProvider);
    final state = wirdAsync.valueOrNull ?? widget.initialState;
    final isJuzMode = state.settings.wirdUnit == WirdUnit.juz;

    // Detect when all 30 juz are completed — trigger khatma celebration
    // Also scroll to first uncompleted juz whenever completed list changes
    ref.listen<AsyncValue<WirdState>>(wirdStateProvider, (previous, next) {
      if (!isJuzMode) return;
      final prevCompleted = previous?.valueOrNull?.allCompletedJuz ?? [];
      final nextCompleted = next.valueOrNull?.allCompletedJuz ?? [];
      final nextLen = nextCompleted.length;
      if (prevCompleted.length < 30 && nextLen == 30 && !_khatmaHandled) {
        _khatmaHandled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleJuzKhatma();
        });
      }
      if (nextLen == 0) _khatmaHandled = false;
      // Scroll to first uncompleted juz after state update
      if (prevCompleted != nextCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToFirstUnmarkedJuz(nextCompleted);
        });
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final progress = state.todayProgress;
    final isCompleted = progress?.isCompleted ?? false;

    // Page mode vars
    final goal = state.settings.dailyPageGoal;
    final pagesRead = progress?.pagesRead ?? 0;
    final progressRatio = goal > 0 ? pagesRead / goal : 0.0;

    // Juz mode vars
    final allCompletedJuz = state.allCompletedJuz;

    // On first render in juz mode, scroll to first uncompleted juz
    if (isJuzMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToFirstUnmarkedJuz(allCompletedJuz);
      });
    }
    final juzReadToday = progress?.juzRead ?? 0;
    final dailyJuzGoal = state.settings.dailyJuzGoal;

    final ts = MediaQuery.textScalerOf(context);
    final gapS = ts.scale(10.0).clamp(0.0, 16.0);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(16.0), vertical: ts.scale(12.0)),
      children: [
        SizedBox(key: _streakKey, child: _buildStreakCard(context, state, primary, isDark)),
        SizedBox(height: gapS),

        if (isJuzMode) ...[
          SizedBox(key: _progressKey, child: _buildJuzProgressCard(context, state, primary, isDark, allCompletedJuz, juzReadToday, dailyJuzGoal, isCompleted)),
          SizedBox(height: gapS),
          if (isCompleted)
            _buildCompletedBanner(context, state, primary, isDark)
          else ...[
            SizedBox(key: _actionsKey, child: _buildJuzActions(context, state, primary)),
            SizedBox(height: gapS),
          ],
          SizedBox(key: _juzGridKey, child: _buildJuzGrid(context, allCompletedJuz, primary, isDark)),
        ] else ...[
          SizedBox(key: _progressKey, child: _buildProgressCard(context, state, primary, isDark, pagesRead, goal, isCompleted, progressRatio)),
          SizedBox(height: gapS),
          if (isCompleted) ...[
            _buildCompletedBanner(context, state, primary, isDark),
            // After Restart Wird on a completed day there is no marker and the
            // action block is not built, so offer the setup here.
            if (shouldShowMarkerSetupCard(
              unit: state.settings.wirdUnit,
              markerPage: state.marker?.markerPage,
              dayCompleted: isCompleted,
            )) ...[
              SizedBox(height: gapS),
              WirdMarkerSetupCard(
                onSetMarker: () => _setMarkerFromTab(state, progress),
                onAddFromBookmarks: _addFromBookmarks,
              ),
            ],
          ] else ...[
            SizedBox(key: _actionsKey, child: _buildActionButtons(context, state, primary, progress)),
            SizedBox(height: gapS),
          ],
        ],

        SizedBox(height: gapS),
        SizedBox(key: _statsKey, child: _buildStatsRow(context, state, primary, isDark, isJuzMode, allCompletedJuz)),
        SizedBox(height: gapS),
        SizedBox(key: _settingsKey, child: _buildSettingsSection(context, state, primary, isDark)),
      ],
    );
  }

  // ── Completed Banner ──────────────────────────────────────────────────────

  Widget _buildCompletedBanner(BuildContext context, WirdState state, Color primary, bool isDark) {
    final ts = MediaQuery.textScalerOf(context);
    final offline = ref.watch(isLoggedInProvider) && !ref.watch(isOnlineProvider);
    return Container(
      padding: EdgeInsets.all(ts.scale(16.0)),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: ts.scale(12.0)),
              Expanded(
                child: Text(
                  'wird_completed_today'.tr(),
                  style: AppTypography.label.copyWith(color: Colors.green),
                ),
              ),
              // One controller: shown only when today was completed by "Mark Complete".
              if (state.todayProgress?.manualCredit == true)
                TextButton(
                  onPressed: () => ref.read(wirdStateProvider.notifier).undoComplete(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: ts.scale(12.0)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('wird_undo'.tr()),
                ),
            ],
          ),
          // A move that completes the goal still needs its undo (page mode only).
          WirdUndoMoveButton(
            state: state,
            offline: offline,
            busy: _undoBusy,
            onPressed: _undoLastMove,
          ),
        ],
      ),
    );
  }

  /// Undoes the last marker move and shows the result (one mapping, shared with
  /// the reader snackbar).
  Future<void> _undoLastMove() async {
    if (_undoBusy) return;
    setState(() => _undoBusy = true);
    try {
      final outcome = await ref.read(wirdStateProvider.notifier).undoMove();
      if (mounted) showUndoOutcome(context, outcome);
    } finally {
      if (mounted) setState(() => _undoBusy = false);
    }
  }

  /// Bookmark pick sheet, then the color grid, then the marker is placed.
  /// Cancelling either sheet changes nothing.
  /// "Set Wird marker" on a completed day: the start sheet (Start here and
  /// Cancel) for the page the reader would open at, then place the marker and
  /// stay on the tab with the "placed" snackbar (no Undo; Restart Wird corrects).
  Future<void> _setMarkerFromTab(WirdState state, WirdProgress? progress) async {
    final page = startSheetPage(state, progress);
    final choice = await showWirdStartSheetRemembered(
      context,
      ref,
      page: page,
      readingMode: false,
    );
    if (choice is! StartHere || !mounted) return;
    final outcome = await ref
        .read(wirdStateProvider.notifier)
        .placeMarker(page, choice.color.toARGB32());
    if (!mounted) return;
    switch (outcome) {
      case Placed():
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('wird_marker_placed'.tr().replaceAll(
                '%d',
                NumberFormatter.withArabicNumeralsByLanguage(
                    page.toString(), widget.lang))),
            duration: const Duration(seconds: 3),
          ));
      case PlaceFailed(failure: final f):
        debugPrint('⚠️ [WIRD] Marker not placed: $f');
    }
  }

  Future<void> _addFromBookmarks() async {
    final page = await WirdBookmarkPickSheet.show(
      context,
      onOpenReader: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QuranReaderScreen(suraNo: 1, initialPage: 1)),
      ),
    );
    if (page == null || !mounted) return;
    final color = await WirdColorGridSheet.show(context);
    if (color == null || !mounted) return;
    final outcome =
        await ref.read(wirdStateProvider.notifier).placeMarker(page, color.toARGB32());
    if (outcome is PlaceFailed) debugPrint('⚠️ [WIRD] Marker not placed: ${outcome.failure}');
  }

  /// Start / Continue Reading (page mode). With no marker it first offers to start
  /// the Wird: "Start here" places the marker on N, "Choose another page" and
  /// "Just read" open the reader with no marker, and dismissing the sheet does
  /// nothing. The reader then opens at the page the fresh state gives.
  Future<void> _startReading(WirdState state, WirdProgress? progress) async {
    final noMarker = state.marker?.markerPage == null;
    if (state.settings.wirdUnit == WirdUnit.page && noMarker) {
      final choice = await showWirdStartSheetRemembered(
        context,
        ref,
        page: startSheetPage(state, progress),
        readingMode: true,
      );
      if (choice == null || !mounted) return;
      if (choice is StartHere) {
        final outcome = await ref
            .read(wirdStateProvider.notifier)
            .placeMarker(startSheetPage(state, progress), choice.color.toARGB32());
        if (outcome is PlaceFailed) {
          debugPrint('⚠️ [WIRD] Marker not placed: ${outcome.failure}');
        }
        if (!mounted) return;
      }
    }
    final fresh = ref.read(wirdStateProvider).valueOrNull ?? state;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(
            suraNo: 1, initialPage: startSheetPage(fresh, progress)),
      ),
    );
  }

  Future<void> _confirmRestart(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('wird_restart_confirm_title'.tr()),
        content: Text('wird_restart_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('wird_restart_confirm_yes'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(wirdStateProvider.notifier).restartWird();
  }

  // ── Juz Progress Card ─────────────────────────────────────────────────────

  Widget _buildJuzProgressCard(
    BuildContext context, WirdState state, Color primary, bool isDark,
    List<int> allCompleted, int juzToday, int dailyGoal, bool isCompleted,
  ) {
    final ts = MediaQuery.textScalerOf(context);
    final total = 30;
    final done = allCompleted.length;
    final remaining = total - done;
    final ratio = done / total;
    final daysEst = dailyGoal > 0 && remaining > 0
        ? (remaining / dailyGoal).ceil()
        : 0;
    final secondaryColor = AppConstants.textSecondary(isDark);
    final circleSz = ts.scale(88.0).clamp(88.0, 140.0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ts.scale(16.0).clamp(16.0, 24.0), vertical: ts.scale(14.0).clamp(14.0, 20.0)),
        child: Row(
          children: [
            // Circle — on start side (left for LTR, right for RTL)
            SizedBox(
              width: circleSz,
              height: circleSz,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: done == total ? 1.0 : ratio.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: secondaryColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(done == total ? Colors.green : primary),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${NumberFormatter.withArabicNumeralsByLanguage(done.toString(), widget.lang)}/30',
                            textScaler: TextScaler.noScaling,
                            style: AppTypography.bodyL.copyWith(fontWeight: FontWeight.bold, fontSize: ts.scale(18.0).clamp(14.0, 26.0)),
                          ),
                          Text(
                            'wird_unit_juz'.tr(),
                            textScaler: TextScaler.noScaling,
                            style: AppTypography.caption.copyWith(fontSize: ts.scale(9.0).clamp(8.0, 13.0), color: secondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: ts.scale(16.0)),
            // Text — on end side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'wird_khatm_progress'.tr(),
                          style: AppTypography.label,
                        ),
                      ),
                      SizedBox(width: ts.scale(4.0)),
                      const InfoTipIcon(
                        titleKey: 'tutorial_wird_juz_progress_title',
                        bodyKey: 'tutorial_wird_juz_progress_body',
                      ),
                    ],
                  ),
                  SizedBox(height: ts.scale(6.0)),
                  if (done == total)
                    Text('wird_khatm_done'.tr(), style: AppTypography.bodyS.copyWith(fontWeight: FontWeight.bold, color: Colors.green))
                  else
                    Text(
                      '${NumberFormatter.withArabicNumeralsByLanguage(remaining.toString(), widget.lang)} ${'wird_juz_remaining'.tr()}',
                      style: AppTypography.caption.copyWith(color: secondaryColor),
                    ),
                  if (daysEst > 0) ...[
                    SizedBox(height: ts.scale(2.0)),
                    Text(
                      '~${NumberFormatter.withArabicNumeralsByLanguage(daysEst.toString(), widget.lang)} ${'wird_days_to_finish'.tr()}',
                      style: AppTypography.caption.copyWith(color: secondaryColor),
                    ),
                  ],
                  if (juzToday > 0) ...[
                    SizedBox(height: ts.scale(4.0)),
                    Text(
                      '${NumberFormatter.withArabicNumeralsByLanguage(juzToday.toString(), widget.lang)}/${NumberFormatter.withArabicNumeralsByLanguage(dailyGoal.toString(), widget.lang)} ${'wird_juz_today'.tr()}',
                      style: AppTypography.caption.copyWith(color: primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Juz Actions Row ───────────────────────────────────────────────────────

  Widget _buildJuzActions(BuildContext context, WirdState state, Color primary) {
    final ts = MediaQuery.textScalerOf(context);
    final readingProgress = ref.watch(quranReadingProgressProvider).valueOrNull;
    final juzList = ref.watch(juzListProvider).valueOrNull ?? [];

    // Determine the juz to open: use current reading position, else next uncompleted juz
    int startJuz = 1;
    if (juzList.isNotEmpty) {
      if (readingProgress != null) {
        startJuz = juzList
            .lastWhere((j) => j.startPage <= readingProgress.page, orElse: () => juzList.first)
            .juzNo;
      } else {
        final completed = state.allCompletedJuz.toSet();
        startJuz = Iterable.generate(30, (i) => i + 1).firstWhere((j) => !completed.contains(j), orElse: () => 1);
      }
    }
    final startPage = juzList.isNotEmpty
        ? juzList.firstWhere((j) => j.juzNo == startJuz, orElse: () => juzList.first).startPage
        : 1;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuranReaderScreen(suraNo: 1, initialPage: startPage),
              ),
            ),
            icon: Icon(Icons.menu_book, size: ts.scale(18.0)),
            label: Text('wird_start_reading'.tr()),
          ),
        ),
        SizedBox(height: ts.scale(8.0)),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(wirdStateProvider.notifier).markComplete(),
                icon: Icon(Icons.check, size: ts.scale(18.0)),
                // scaleDown shrinks the label at large system fonts instead of
                // truncating it to "Mark ...".
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('wird_mark_complete'.tr()),
                      SizedBox(width: ts.scale(4.0)),
                      const InfoTipIcon(
                        titleKey: 'tutorial_wird_juz_actions_title',
                        bodyKey: 'tutorial_wird_juz_actions_body',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _scrollToFirstUnmarkedJuz(List<int> allCompleted) {
    if (!_juzScrollController.hasClients) return;
    final completedSet = allCompleted.toSet();
    // Find first juz (1-30) not yet completed
    int firstUnmarked = -1;
    for (int j = 1; j <= 30; j++) {
      if (!completedSet.contains(j)) { firstUnmarked = j; break; }
    }
    if (firstUnmarked == -1) return; // all done
    final index = firstUnmarked - 1;
    // Each cell: scale(44) wide + scale(6) separator ≈ scale(50) per item
    final ts = MediaQuery.textScalerOf(context);
    final itemWidth = ts.scale(50.0);
    final targetOffset = (index * itemWidth)
        .clamp(0.0, _juzScrollController.position.maxScrollExtent);
    _juzScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('wird_reset_confirm_title'.tr()),
        content: Text('wird_reset_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('wird_reset_today'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(wirdStateProvider.notifier).resetAllProgress();
    if (!mounted) return;
    // A full wipe starts the start sheet blank again (session memory only).
    ref.invalidate(wirdStartColorProvider);
  }

  // ── Juz Grid ──────────────────────────────────────────────────────────────

  Widget _buildJuzGrid(BuildContext context, List<int> allCompleted, Color primary, bool isDark) {
    final ts = MediaQuery.textScalerOf(context);
    final secondaryColor = AppConstants.textSecondary(isDark);
    final cellW = ts.scale(44.0);
    final cellH = ts.scale(52.0);
    final chevronSz = ts.scale(28.0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ts.scale(12.0), vertical: ts.scale(14.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('wird_juz_grid'.tr(), style: AppTypography.label),
                SizedBox(width: ts.scale(4.0)),
                const InfoTipIcon(
                  titleKey: 'tutorial_wird_juz_grid_title',
                  bodyKey: 'tutorial_wird_juz_grid_body',
                ),
              ],
            ),
            SizedBox(height: ts.scale(10.0)),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    _juzScrollController.animateTo(
                      (_juzScrollController.offset - 220).clamp(0, _juzScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: Icon(Icons.chevron_left, color: primary),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: chevronSz, minHeight: chevronSz),
                  iconSize: chevronSz,
                ),
                Expanded(
                  child: SizedBox(
                    height: cellH,
                    child: ListView.separated(
                      controller: _juzScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: 30,
                      separatorBuilder: (_, __) => SizedBox(width: ts.scale(6.0)),
                      itemBuilder: (context, index) {
                        final juzNo = index + 1;
                        final done = allCompleted.contains(juzNo);
                        return GestureDetector(
                          onTap: () => ref.read(wirdStateProvider.notifier).toggleJuzCompleted(juzNo),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: cellW,
                            height: cellH,
                            decoration: BoxDecoration(
                              color: done
                                  ? primary.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: done ? primary : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (done)
                                  Icon(Icons.check_circle, color: primary, size: ts.scale(18.0))
                                else
                                  Text(
                                    NumberFormatter.withArabicNumeralsByLanguage(juzNo.toString(), widget.lang),
                                    style: AppTypography.label.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                SizedBox(height: ts.scale(2.0)),
                                Text(
                                  'wird_unit_juz'.tr(),
                                  textScaler: TextScaler.noScaling,
                                  style: AppTypography.caption.copyWith(fontSize: ts.scale(9.0), color: secondaryColor),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _juzScrollController.animateTo(
                      (_juzScrollController.offset + 220).clamp(0, _juzScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: Icon(Icons.chevron_right, color: primary),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: chevronSz, minHeight: chevronSz),
                  iconSize: chevronSz,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Streak Card ───────────────────────────────────────────────────────────

  Widget _buildStreakCard(BuildContext context, WirdState state, Color primary, bool isDark) {
    final ts = MediaQuery.textScalerOf(context);
    final streak = state.streakCount;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(20.0), vertical: ts.scale(16.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.2),
            primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(streak > 0 ? '🔥' : '📚', style: TextStyle(fontSize: ts.scale(32.0)), textScaler: TextScaler.noScaling),
          SizedBox(width: ts.scale(16.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'wird_streak'.tr(),
                  style: AppTypography.caption.copyWith(
                    color: AppConstants.textSecondary(isDark),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      NumberFormatter.withArabicNumeralsByLanguage(streak.toString(), widget.lang),
                      style: AppTypography.headingL.copyWith(fontWeight: FontWeight.bold, color: primary),
                    ),
                    SizedBox(width: ts.scale(6.0)),
                    Text(
                      'wird_streak_days'.tr(),
                      style: AppTypography.label.copyWith(
                        color: AppConstants.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const InfoTipIcon(
            titleKey: 'tutorial_wird_streak_title',
            bodyKey: 'tutorial_wird_streak_body',
          ),
          SizedBox(width: ts.scale(4.0)),
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, color: primary, size: ts.scale(22.0)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: widget.lang == 'ar' ? 'إحصاءات القرآن' : 'Quran Stats',
            onPressed: () => Navigator.pushNamed(context, '/quran_stats'),
          ),
        ],
      ),
    );
  }

  // ── Progress Card ─────────────────────────────────────────────────────────

  Widget _buildProgressCard(
    BuildContext context, WirdState state, Color primary, bool isDark,
    int pagesRead, int goal, bool isCompleted, double progressRatio,
  ) {
    final ts = MediaQuery.textScalerOf(context);
    final secondaryColor = AppConstants.textSecondary(isDark);
    final remaining = goal - pagesRead;
    final circleSz = ts.scale(88.0).clamp(88.0, 140.0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ts.scale(16.0).clamp(16.0, 24.0), vertical: ts.scale(14.0).clamp(14.0, 20.0)),
        child: Row(
          children: [
            // Circle — start side (left LTR, right RTL)
            SizedBox(
              width: circleSz,
              height: circleSz,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: isCompleted ? 1.0 : progressRatio.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: secondaryColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : primary),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${NumberFormatter.withArabicNumeralsByLanguage(pagesRead.toString(), widget.lang)}'
                            '/${NumberFormatter.withArabicNumeralsByLanguage(goal.toString(), widget.lang)}',
                            textScaler: TextScaler.noScaling,
                            style: AppTypography.headingS.copyWith(fontWeight: FontWeight.bold, fontSize: ts.scale(18.0).clamp(14.0, 26.0)),
                          ),
                          Text(
                            'page'.tr(),
                            textScaler: TextScaler.noScaling,
                            style: AppTypography.caption.copyWith(fontSize: ts.scale(9.0).clamp(8.0, 13.0), color: secondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: ts.scale(16.0)),
            // Text — end side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'wird_today_progress'.tr(),
                          style: AppTypography.label,
                        ),
                      ),
                      SizedBox(width: ts.scale(4.0)),
                      const InfoTipIcon(
                        titleKey: 'tutorial_wird_progress_title',
                        bodyKey: 'tutorial_wird_progress_body',
                      ),
                    ],
                  ),
                  SizedBox(height: ts.scale(6.0)),
                  if (isCompleted)
                    Text('wird_completed_today'.tr(), style: AppTypography.bodyS.copyWith(fontWeight: FontWeight.bold, color: Colors.green))
                  else if (remaining > 0)
                    Text(
                      '${NumberFormatter.withArabicNumeralsByLanguage(remaining.toString(), widget.lang)} ${'wird_pages_remaining'.tr()}',
                      style: AppTypography.caption.copyWith(color: secondaryColor),
                    ),
                  if (state.marker?.markerPage != null) ...[
                    SizedBox(height: ts.scale(6.0)),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(state.marker!.color ?? kWirdMarkerPalette.first.toARGB32()),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ts.scale(6.0)),
                        Flexible(
                          child: Text(
                            'wird_marker_page_label'.tr().replaceAll(
                                '%d',
                                NumberFormatter.withArabicNumeralsByLanguage(
                                    state.marker!.markerPage.toString(), widget.lang)),
                            style: AppTypography.caption.copyWith(color: secondaryColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context, WirdState state, Color primary, WirdProgress? progress) {
    final ts = MediaQuery.textScalerOf(context);
    final goal = state.settings.dailyPageGoal;
    final startPage = wirdRangeStart(state, progress?.startPage);
    final endPage = (startPage + goal - 1).clamp(1, 604);

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(ts.scale(12.0)),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'wird_page_range'.tr()
                    .replaceAll('%s', NumberFormatter.withArabicNumeralsByLanguage(startPage.toString(), widget.lang))
                    .replaceAll('%e', NumberFormatter.withArabicNumeralsByLanguage(endPage.toString(), widget.lang)),
                style: AppTypography.label.copyWith(color: primary),
              ),
              SizedBox(width: ts.scale(4.0)),
              InfoTipIcon(
                titleKey: 'tutorial_wird_actions_title',
                bodyKey: 'tutorial_wird_actions_body',
              ),
            ],
          ),
        ),
        SizedBox(height: ts.scale(12.0)),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _startReading(state, progress),
                icon: Icon(progress == null ? Icons.play_arrow : Icons.arrow_forward, size: ts.scale(18.0)),
                label: Text(progress == null ? 'wird_start_reading'.tr() : 'wird_continue_reading'.tr()),
              ),
            ),
          ],
        ),
        SizedBox(height: ts.scale(8.0)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(wirdStateProvider.notifier).markComplete(),
            icon: Icon(Icons.check, size: ts.scale(18.0)),
            label: FittedBox(fit: BoxFit.scaleDown, child: Text('wird_mark_complete'.tr())),
          ),
        ),
        WirdUndoMoveButton(
          state: state,
          offline: ref.watch(isLoggedInProvider) && !ref.watch(isOnlineProvider),
          busy: _undoBusy,
          onPressed: _undoLastMove,
        ),
        SizedBox(height: ts.scale(8.0)),
        if (state.marker?.markerPage == null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addFromBookmarks,
              icon: Icon(Icons.bookmark_outline, size: ts.scale(18.0)),
              label: Text('wird_add_from_bookmarks'.tr()),
            ),
          )
        else
          Text(
            'wird_marker_restart_hint'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
      ],
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context, WirdState state, Color primary, bool isDark, bool isJuzMode, List<int> allCompletedJuz) {
    final ts = MediaQuery.textScalerOf(context);
    final secondary = AppConstants.textSecondary(isDark);
    return Row(
      children: [
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(ts.scale(12.0)),
              child: Column(
                children: [
                  Text(
                    isJuzMode
                        ? '${NumberFormatter.withArabicNumeralsByLanguage(allCompletedJuz.length.toString(), widget.lang)}/30'
                        : NumberFormatter.withArabicNumeralsByLanguage(state.totalPagesRead.toString(), widget.lang),
                    style: AppTypography.headingM.copyWith(fontWeight: FontWeight.bold, color: primary),
                  ),
                  Text(
                    isJuzMode ? 'wird_total_juz_done'.tr() : 'wird_total_pages'.tr(),
                    style: AppTypography.labelS.copyWith(color: secondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: ts.scale(8.0)),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(ts.scale(12.0)),
              child: Column(
                children: [
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.totalDaysCompleted.toString(), widget.lang),
                    style: AppTypography.headingM.copyWith(fontWeight: FontWeight.bold, color: primary),
                  ),
                  Text(
                    'wird_total_days'.tr(),
                    style: AppTypography.labelS.copyWith(color: secondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Settings Section ──────────────────────────────────────────────────────

  Widget _buildSettingsSection(BuildContext context, WirdState state, Color primary, bool isDark) {
    final ts = MediaQuery.textScalerOf(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ── Tracking Mode Toggle ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(ts.scale(16.0).clamp(16.0, 24.0), ts.scale(12.0).clamp(12.0, 18.0), ts.scale(16.0).clamp(16.0, 24.0), ts.scale(4.0).clamp(4.0, 8.0)),
            child: Row(
              children: [
                Icon(Icons.tune, color: primary, size: ts.scale(20.0).clamp(20.0, 28.0)),
                SizedBox(width: ts.scale(12.0).clamp(12.0, 16.0)),
                Text('wird_tracking_mode'.tr(), style: AppTypography.label),
                SizedBox(width: ts.scale(4.0)),
                const InfoTipIcon(
                  titleKey: 'tutorial_wird_settings_title',
                  bodyKey: 'tutorial_wird_settings_body',
                ),
                const Spacer(),
                SegmentedButton<WirdUnit>(
                  segments: [
                    ButtonSegment(value: WirdUnit.page, label: Text('wird_unit_page'.tr())),
                    ButtonSegment(value: WirdUnit.juz, label: Text('wird_unit_juz'.tr())),
                  ],
                  selected: {state.settings.wirdUnit},
                  onSelectionChanged: (sel) =>
                      ref.read(wirdStateProvider.notifier).setWirdUnit(sel.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Daily Goal ────────────────────────────────────────────────────
          if (state.settings.wirdUnit == WirdUnit.page)
            ListTile(
              leading: Icon(Icons.menu_book, color: primary, size: ts.scale(20.0)),
              title: Text('wird_daily_goal'.tr()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyPageGoal;
                      if (current > 1) ref.read(wirdStateProvider.notifier).setDailyPageGoal(current - 1);
                    },
                    icon: Icon(Icons.remove, size: ts.scale(20.0)),
                  ),
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.settings.dailyPageGoal.toString(), widget.lang),
                    style: AppTypography.label.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyPageGoal;
                      if (current < 604) ref.read(wirdStateProvider.notifier).setDailyPageGoal(current + 1);
                    },
                    icon: Icon(Icons.add, size: ts.scale(20.0)),
                  ),
                ],
              ),
            )
          else
            ListTile(
              leading: Icon(Icons.layers, color: primary, size: ts.scale(20.0)),
              title: Text('wird_daily_juz_goal'.tr()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyJuzGoal;
                      if (current > 1) ref.read(wirdStateProvider.notifier).setDailyJuzGoal(current - 1);
                    },
                    icon: Icon(Icons.remove, size: ts.scale(20.0)),
                  ),
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.settings.dailyJuzGoal.toString(), widget.lang),
                    style: AppTypography.label.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyJuzGoal;
                      if (current < 30) ref.read(wirdStateProvider.notifier).setDailyJuzGoal(current + 1);
                    },
                    icon: Icon(Icons.add, size: ts.scale(20.0)),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active, color: primary, size: ts.scale(20.0)),
            title: Text('wird_reminder_enabled'.tr()),
            subtitle: Text('wird_reminder_subtitle'.tr()),
            value: state.settings.remindersEnabled,
            onChanged: (v) => ref.read(wirdStateProvider.notifier).setRemindersEnabled(v),
          ),
          if (state.settings.remindersEnabled) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(ts.scale(16.0).clamp(16.0, 24.0), ts.scale(12.0).clamp(12.0, 18.0), ts.scale(16.0).clamp(16.0, 24.0), ts.scale(4.0).clamp(4.0, 8.0)),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('wird_reminders'.tr(), style: AppTypography.label),
              ),
            ),
            ...state.settings.reminderTimes.asMap().entries.map((entry) {
              final idx = entry.key;
              final time = entry.value;
              final parts = time.split(':');
              final timeOfDay = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

              return ListTile(
                dense: true,
                leading: Icon(Icons.access_time, size: ts.scale(20.0)),
                title: Text(timeOfDay.format(context), style: AppTypography.label),
                trailing: IconButton(
                  icon: Icon(Icons.close, size: ts.scale(18.0)),
                  onPressed: () => ref.read(wirdStateProvider.notifier).removeReminder(idx),
                ),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                  if (picked != null) {
                    final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    final times = [...state.settings.reminderTimes];
                    times[idx] = newTime;
                    ref.read(wirdStateProvider.notifier).setReminderTimes(times);
                  }
                },
              );
            }),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ts.scale(16.0), vertical: ts.scale(8.0)),
              child: OutlinedButton.icon(
                onPressed: state.settings.reminderTimes.length >= 10
                    ? null
                    : () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 6, minute: 0),
                        );
                        if (picked != null) {
                          final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          ref.read(wirdStateProvider.notifier).addReminder(time);
                        }
                      },
                icon: const Icon(Icons.add),
                label: Text('wird_add_reminder'.tr()),
              ),
            ),
          ],
          // Last two rows: Restart Wird (page mode, with a marker), then Reset All
          // Progress (red, always last, both modes).
          const Divider(height: 1),
          WirdRestartTile(state: state, onPressed: () => _confirmRestart(context)),
          ListTile(
            leading: Icon(Icons.refresh, color: Colors.red.shade400, size: ts.scale(20.0)),
            title: Text('wird_reset_today'.tr(), style: TextStyle(color: Colors.red.shade400)),
            onTap: () => _confirmReset(context),
          ),
        ],
      ),
    );
  }
}

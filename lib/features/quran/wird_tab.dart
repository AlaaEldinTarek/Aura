import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import 'quran_reader_screen.dart';

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
  bool _showUndo = true;
  bool _syncInProgress = false;

  @override
  Widget build(BuildContext context) {
    final wirdAsync = ref.watch(wirdStateProvider);
    final state = wirdAsync.valueOrNull ?? widget.initialState;
    final isJuzMode = state.settings.wirdUnit == WirdUnit.juz;

    // Auto-sync: watch bookmarks and sync any new pages not yet counted
    final linkedColor = state.settings.linkedBookmarkColor;
    if (linkedColor != null && !_syncInProgress) {
      final bookmarkColor = BookmarkColor.values.firstWhere(
        (c) => c.name == linkedColor,
        orElse: () => BookmarkColor.green,
      );
      final bookmarks = ref.watch(quranBookmarksProvider).valueOrNull ?? [];
      final currentPages = bookmarks
          .where((b) => b.color == bookmarkColor)
          .map((b) => b.page)
          .toSet();
      final counted = state.settings.countedBookmarkPages.toSet();
      final newPages = currentPages.difference(counted);
      if (newPages.isNotEmpty) {
        _syncInProgress = true;
        if (isJuzMode) {
          final juzList = ref.watch(juzListProvider).valueOrNull ?? [];
          if (juzList.isNotEmpty) {
            // Mark all juz 1..maxJuz sequentially (bookmark in juz 4 implies juz 1-4 done)
            final maxJuz = currentPages.map((page) {
              return juzList.lastWhere((j) => j.startPage <= page, orElse: () => juzList.first).juzNo;
            }).reduce((a, b) => a > b ? a : b);
            final toMark = Set<int>.from(List.generate(maxJuz, (i) => i + 1));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(wirdStateProvider.notifier).markJuzFromBookmarks(toMark, currentPages).then((_) {
                if (mounted) setState(() => _syncInProgress = false);
              });
            });
          } else {
            _syncInProgress = false;
          }
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(wirdStateProvider.notifier).syncBookmarkPages(currentPages).then((_) {
              if (mounted) setState(() => _syncInProgress = false);
            });
          });
        }
      }
    }

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
    final juzReadToday = progress?.juzRead ?? 0;
    final dailyJuzGoal = state.settings.dailyJuzGoal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStreakCard(state, primary, isDark),
        const SizedBox(height: 16),

        if (isJuzMode) ...[
          _buildJuzProgressCard(state, primary, isDark, allCompletedJuz, juzReadToday, dailyJuzGoal, isCompleted),
          const SizedBox(height: 16),
          if (isCompleted)
            _buildCompletedBanner(primary, isDark)
          else ...[
            _buildJuzActions(context, state, primary),
            const SizedBox(height: 16),
          ],
          _buildJuzGrid(context, allCompletedJuz, primary, isDark),
        ] else ...[
          _buildProgressCard(context, state, primary, isDark, pagesRead, goal, isCompleted, progressRatio),
          const SizedBox(height: 16),
          if (isCompleted)
            _buildCompletedBanner(primary, isDark)
          else ...[
            _buildActionButtons(context, state, primary, progress),
            const SizedBox(height: 16),
          ],
        ],

        const SizedBox(height: 16),
        _buildStatsRow(state, primary, isDark, isJuzMode, allCompletedJuz),
        const SizedBox(height: 16),
        _buildSettingsSection(context, state, primary, isDark),
      ],
    );
  }

  // ── Completed Banner ──────────────────────────────────────────────────────

  Widget _buildCompletedBanner(Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'wird_completed_today'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
            ),
          ),
          if (_showUndo)
            TextButton(
              onPressed: () {
                ref.read(wirdStateProvider.notifier).undoComplete();
                setState(() => _showUndo = false);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('wird_undo'.tr()),
            ),
        ],
      ),
    );
  }

  // ── Juz Progress Card ─────────────────────────────────────────────────────

  Widget _buildJuzProgressCard(
    WirdState state, Color primary, bool isDark,
    List<int> allCompleted, int juzToday, int dailyGoal, bool isCompleted,
  ) {
    final total = 30;
    final done = allCompleted.length;
    final remaining = total - done;
    final ratio = done / total;
    final daysEst = dailyGoal > 0 && remaining > 0
        ? (remaining / dailyGoal).ceil()
        : 0;
    final secondaryColor = isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('wird_khatm_progress'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: done == total ? 1.0 : ratio.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    backgroundColor: secondaryColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(done == total ? Colors.green : primary),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${NumberFormatter.withArabicNumeralsByLanguage(done.toString(), widget.lang)}/30',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'wird_unit_juz'.tr(),
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (done == total)
              Text('wird_khatm_done'.tr(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            else
              Text(
                '${NumberFormatter.withArabicNumeralsByLanguage(remaining.toString(), widget.lang)} ${'wird_juz_remaining'.tr()} · ~${NumberFormatter.withArabicNumeralsByLanguage(daysEst.toString(), widget.lang)} ${'wird_days_to_finish'.tr()}',
                style: TextStyle(fontSize: 13, color: secondaryColor),
                textAlign: TextAlign.center,
              ),
            if (juzToday > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${NumberFormatter.withArabicNumeralsByLanguage(juzToday.toString(), widget.lang)}/${'${NumberFormatter.withArabicNumeralsByLanguage(dailyGoal.toString(), widget.lang)}'} ${'wird_juz_today'.tr()}',
                style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Juz Actions Row ───────────────────────────────────────────────────────

  Widget _buildJuzActions(BuildContext context, WirdState state, Color primary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(wirdStateProvider.notifier).markComplete();
                  setState(() => _showUndo = true);
                },
                icon: const Icon(Icons.check),
                label: Text('wird_mark_complete'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showBookmarkPagesSheetJuz(context, state),
            icon: const Icon(Icons.bookmark_outline),
            label: Text('wird_add_from_bookmarks'.tr()),
          ),
        ),
      ],
    );
  }

  // ── Bookmark Pages Sheet (Juz mode) ───────────────────────────────────────

  void _showBookmarkPagesSheetJuz(BuildContext context, WirdState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BookmarkPagesSheet(
        lang: widget.lang,
        onUseAll: (pageCount, lastPage, colorName, allPages) async {
          final juzList = ref.read(juzListProvider).valueOrNull ?? [];
          if (juzList.isEmpty) {
            Navigator.pop(context);
            return;
          }
          final maxJuz = allPages.map((page) {
            return juzList.lastWhere((j) => j.startPage <= page, orElse: () => juzList.first).juzNo;
          }).reduce((a, b) => a > b ? a : b);
          final toMark = Set<int>.from(List.generate(maxJuz, (i) => i + 1));
          Navigator.pop(context);
          final added = await ref.read(wirdStateProvider.notifier).markJuzFromBookmarks(toMark, allPages);
          if (!mounted) return;
          final msg = added > 0
              ? 'wird_bookmark_juz_marked'.tr().replaceAll('%d', added.toString())
              : 'wird_bookmark_no_new_juz'.tr();
          final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
            ),
          );
          Future.delayed(const Duration(seconds: 2), snackCtrl.close);
        },
        onChooseOne: (color, colorBookmarks) {
          Navigator.pop(context);
          _showBookmarkListSheet(context, color, colorBookmarks, isJuzMode: true);
        },
      ),
    );
  }

  // ── Bookmark List Sheet (individual bookmark selection) ───────────────────

  void _showBookmarkListSheet(
    BuildContext context,
    BookmarkColor color,
    List<QuranBookmark> bookmarks, {
    required bool isJuzMode,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BookmarkListSheet(
        lang: widget.lang,
        color: color,
        bookmarks: bookmarks,
        onSelect: (bm) async {
          Navigator.pop(context);
          final pages = {bm.page};
          if (isJuzMode) {
            final juzList = ref.read(juzListProvider).valueOrNull ?? [];
            if (juzList.isEmpty) return;
            final juzNo = juzList.lastWhere((j) => j.startPage <= bm.page, orElse: () => juzList.first).juzNo;
            final toMark = Set<int>.from(List.generate(juzNo, (i) => i + 1));
            final added = await ref.read(wirdStateProvider.notifier).markJuzFromBookmarks(toMark, pages);
            if (!mounted) return;
            final msg = added > 0
                ? 'wird_bookmark_juz_marked'.tr().replaceAll('%d', added.toString())
                : 'wird_bookmark_no_new_juz'.tr();
            final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
              ),
            );
            Future.delayed(const Duration(seconds: 2), snackCtrl.close);
          } else {
            ref.read(wirdStateProvider.notifier).recordPagesRead(1, bm.page);
            ref.read(wirdStateProvider.notifier).setLinkedBookmarkColor(color.name, pages);
            final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('wird_bookmark_added'.tr().replaceAll('%d', '1')),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
              ),
            );
            Future.delayed(const Duration(seconds: 2), snackCtrl.close);
          }
        },
      ),
    );
  }

  // ── Juz Grid ──────────────────────────────────────────────────────────────

  Widget _buildJuzGrid(BuildContext context, List<int> allCompleted, Color primary, bool isDark) {
    final secondaryColor = isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('wird_juz_grid'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.85,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                final juzNo = index + 1;
                final done = allCompleted.contains(juzNo);
                return GestureDetector(
                  onTap: () => ref.read(wirdStateProvider.notifier).toggleJuzCompleted(juzNo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: done ? primary.withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
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
                          Icon(Icons.check_circle, color: primary, size: 18)
                        else
                          Text(
                            NumberFormatter.withArabicNumeralsByLanguage(juzNo.toString(), widget.lang),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'wird_unit_juz'.tr(),
                          style: TextStyle(fontSize: 9, color: secondaryColor),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Streak Card ───────────────────────────────────────────────────────────

  Widget _buildStreakCard(WirdState state, Color primary, bool isDark) {
    final streak = state.streakCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          Text(streak > 0 ? '🔥' : '📚', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'wird_streak'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      NumberFormatter.withArabicNumeralsByLanguage(streak.toString(), widget.lang),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'wird_streak_days'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('wird_today_progress'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: isCompleted ? 1.0 : progressRatio.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    backgroundColor: (isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary).withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : primary),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${NumberFormatter.withArabicNumeralsByLanguage(pagesRead.toString(), widget.lang)}'
                          ' ${'wird_of'.tr()} '
                          '${NumberFormatter.withArabicNumeralsByLanguage(goal.toString(), widget.lang)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'page'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompleted && pagesRead < goal) ...[
              const SizedBox(height: 8),
              Text(
                '${NumberFormatter.withArabicNumeralsByLanguage((goal - pagesRead).toString(), widget.lang)} ${'wird_pages_remaining'.tr()}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context, WirdState state, Color primary, WirdProgress? progress) {
    final goal = state.settings.dailyPageGoal;
    final startPage = progress?.startPage ?? 1;
    final currentPage = progress?.currentPage ?? startPage;
    final endPage = (startPage + goal - 1).clamp(1, 604);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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
                style: TextStyle(fontSize: 14, color: primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuranReaderScreen(suraNo: 1, initialPage: currentPage),
                    ),
                  );
                },
                icon: Icon(progress == null ? Icons.play_arrow : Icons.arrow_forward),
                label: Text(progress == null ? 'wird_start_reading'.tr() : 'wird_continue_reading'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRecordPagesDialog(context, currentPage),
                icon: const Icon(Icons.edit_note),
                label: Text('wird_record_pages'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(wirdStateProvider.notifier).markComplete();
                  setState(() => _showUndo = true);
                },
                icon: const Icon(Icons.check),
                label: Text('wird_mark_complete'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showBookmarkPagesSheet(context),
            icon: const Icon(Icons.bookmark_outline),
            label: Text('wird_add_from_bookmarks'.tr()),
          ),
        ),
      ],
    );
  }

  // ── Bookmark Pages Sheet ──────────────────────────────────────────────────

  void _showBookmarkPagesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BookmarkPagesSheet(
        lang: widget.lang,
        onUseAll: (pageCount, lastPage, colorName, allPages) {
          ref.read(wirdStateProvider.notifier).recordPagesRead(pageCount, lastPage);
          ref.read(wirdStateProvider.notifier).setLinkedBookmarkColor(colorName, allPages);
          Navigator.pop(context);
          final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('wird_bookmark_added'.tr().replaceAll('%d', pageCount.toString())),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
            ),
          );
          Future.delayed(const Duration(seconds: 2), snackCtrl.close);
        },
        onChooseOne: (color, colorBookmarks) {
          Navigator.pop(context);
          _showBookmarkListSheet(context, color, colorBookmarks, isJuzMode: false);
        },
      ),
    );
  }

  // ── Record Pages Dialog (two modes) ───────────────────────────────────────

  void _showRecordPagesDialog(BuildContext context, int currentPage) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('wird_record_pages'.tr()),
              content: _RecordPagesContent(
                lang: widget.lang,
                currentPage: currentPage,
                onConfirm: (additionalPages, newPage) {
                  ref.read(wirdStateProvider.notifier).recordPagesRead(additionalPages, newPage);
                  Navigator.pop(ctx);
                },
              ),
            );
          },
        );
      },
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(WirdState state, Color primary, bool isDark, bool isJuzMode, List<int> allCompletedJuz) {
    final secondary = isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary;
    return Row(
      children: [
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    isJuzMode
                        ? '${NumberFormatter.withArabicNumeralsByLanguage(allCompletedJuz.length.toString(), widget.lang)}/30'
                        : NumberFormatter.withArabicNumeralsByLanguage(state.totalPagesRead.toString(), widget.lang),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary),
                  ),
                  Text(
                    isJuzMode ? 'wird_total_juz_done'.tr() : 'wird_total_pages'.tr(),
                    style: TextStyle(fontSize: 11, color: secondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.totalDaysCompleted.toString(), widget.lang),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary),
                  ),
                  Text(
                    'wird_total_days'.tr(),
                    style: TextStyle(fontSize: 11, color: secondary),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ── Tracking Mode Toggle ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.tune, color: primary, size: 20),
                const SizedBox(width: 12),
                Text('wird_tracking_mode'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                SegmentedButton<WirdUnit>(
                  segments: [
                    ButtonSegment(value: WirdUnit.page, label: Text('wird_unit_page'.tr())),
                    ButtonSegment(value: WirdUnit.juz, label: Text('wird_unit_juz'.tr())),
                  ],
                  selected: {state.settings.wirdUnit},
                  onSelectionChanged: (sel) =>
                      ref.read(wirdStateProvider.notifier).setWirdUnit(sel.first),
                  style: ButtonStyle(
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
              leading: Icon(Icons.menu_book, color: primary),
              title: Text('wird_daily_goal'.tr()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyPageGoal;
                      if (current > 1) ref.read(wirdStateProvider.notifier).setDailyPageGoal(current - 1);
                    },
                    icon: const Icon(Icons.remove, size: 20),
                  ),
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.settings.dailyPageGoal.toString(), widget.lang),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyPageGoal;
                      if (current < 604) ref.read(wirdStateProvider.notifier).setDailyPageGoal(current + 1);
                    },
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            )
          else
            ListTile(
              leading: Icon(Icons.layers, color: primary),
              title: Text('wird_daily_juz_goal'.tr()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyJuzGoal;
                      if (current > 1) ref.read(wirdStateProvider.notifier).setDailyJuzGoal(current - 1);
                    },
                    icon: const Icon(Icons.remove, size: 20),
                  ),
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.settings.dailyJuzGoal.toString(), widget.lang),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {
                      final current = state.settings.dailyJuzGoal;
                      if (current < 30) ref.read(wirdStateProvider.notifier).setDailyJuzGoal(current + 1);
                    },
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active, color: primary),
            title: Text('wird_reminder_enabled'.tr()),
            subtitle: Text('wird_reminder_subtitle'.tr()),
            value: state.settings.remindersEnabled,
            onChanged: (v) => ref.read(wirdStateProvider.notifier).setRemindersEnabled(v),
          ),
          if (state.settings.remindersEnabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('wird_reminders'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            ...state.settings.reminderTimes.asMap().entries.map((entry) {
              final idx = entry.key;
              final time = entry.value;
              final parts = time.split(':');
              final timeOfDay = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

              return ListTile(
                dense: true,
                leading: const Icon(Icons.access_time, size: 20),
                title: Text(timeOfDay.format(context), style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ],
      ),
    );
  }
}

// ── Bookmark Pages Bottom Sheet ─────────────────────────────────────────────

class _BookmarkPagesSheet extends ConsumerWidget {
  final String lang;
  final void Function(int pageCount, int lastPage, String colorName, Set<int> allPages) onUseAll;
  final void Function(BookmarkColor color, List<QuranBookmark> colorBookmarks) onChooseOne;

  const _BookmarkPagesSheet({
    required this.lang,
    required this.onUseAll,
    required this.onChooseOne,
  });

  static const _bookmarkColors = {
    BookmarkColor.red: Color(0xFFE53935),
    BookmarkColor.orange: Color(0xFFFB8C00),
    BookmarkColor.green: Color(0xFF43A047),
  };

  static const _colorNameKeys = {
    BookmarkColor.red: 'wird_bookmark_color_red',
    BookmarkColor.orange: 'wird_bookmark_color_orange',
    BookmarkColor.green: 'wird_bookmark_color_green',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(quranBookmarksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void showModeDialog(BookmarkColor color, Set<int> uniquePages, List<QuranBookmark> allBookmarks) {
      final displayColor = _bookmarkColors[color]!;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(_colorNameKeys[color]!.tr()),
            ],
          ),
          content: Text('wird_bookmark_mode_desc'.tr()),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final maxPage = uniquePages.reduce((a, b) => a > b ? a : b);
                onUseAll(uniquePages.length, maxPage, color.name, uniquePages);
              },
              child: Text('wird_bookmark_mode_new'.tr()),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final colorBookmarks = allBookmarks
                    .where((b) => b.color == color)
                    .toList()
                  ..sort((a, b) => b.page.compareTo(a.page));
                onChooseOne(color, colorBookmarks);
              },
              child: Text('wird_bookmark_mode_update'.tr()),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white38 : Colors.black38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('wird_bookmark_pages_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          bookmarksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('wird_bookmark_no_bookmarks'.tr()),
            ),
            data: (bookmarks) {
              return Column(
                children: BookmarkColor.values.map((color) {
                  final uniquePages = bookmarks
                      .where((b) => b.color == color)
                      .map((b) => b.page)
                      .toSet();
                  final count = uniquePages.length;
                  final displayColor = _bookmarkColors[color]!;
                  final hasPages = count > 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Opacity(
                      opacity: hasPages ? 1.0 : 0.4,
                      child: InkWell(
                        onTap: hasPages ? () => showModeDialog(color, uniquePages, bookmarks) : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: displayColor.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: displayColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.bookmark, color: displayColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_colorNameKeys[color]!.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                                    Text(
                                      hasPages
                                          ? 'wird_bookmark_unique_pages'.tr().replaceAll('%d', count.toString())
                                          : 'wird_bookmark_no_bookmarks'.tr(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasPages)
                                Icon(Icons.chevron_right, color: displayColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Bookmark List Sheet ─────────────────────────────────────────────────────

class _BookmarkListSheet extends StatelessWidget {
  final String lang;
  final BookmarkColor color;
  final List<QuranBookmark> bookmarks;
  final void Function(QuranBookmark bookmark) onSelect;

  const _BookmarkListSheet({
    required this.lang,
    required this.color,
    required this.bookmarks,
    required this.onSelect,
  });

  static const _bookmarkColors = {
    BookmarkColor.red: Color(0xFFE53935),
    BookmarkColor.orange: Color(0xFFFB8C00),
    BookmarkColor.green: Color(0xFF43A047),
  };

  static const _colorNameKeys = {
    BookmarkColor.red: 'wird_bookmark_color_red',
    BookmarkColor.orange: 'wird_bookmark_color_orange',
    BookmarkColor.green: 'wird_bookmark_color_green',
  };

  @override
  Widget build(BuildContext context) {
    final displayColor = _bookmarkColors[color]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white38 : Colors.black38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _colorNameKeys[color]!.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'wird_bookmark_unique_pages'.tr().replaceAll('%d', bookmarks.length.toString()),
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: bookmarks.length,
              itemBuilder: (_, i) {
                final bm = bookmarks[i];
                final name = lang == 'ar' ? bm.suraNameAr : bm.suraNameEn;
                return ListTile(
                  leading: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        NumberFormatter.withArabicNumeralsByLanguage(bm.page.toString(), lang),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: displayColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${'ayah'.tr()} ${NumberFormatter.withArabicNumeralsByLanguage(bm.ayaNo.toString(), lang)}',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                  trailing: Icon(Icons.add_circle_outline, color: displayColor),
                  onTap: () => onSelect(bm),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Record Pages Dialog Content ─────────────────────────────────────────────

class _RecordPagesContent extends StatefulWidget {
  final String lang;
  final int currentPage;
  final void Function(int additionalPages, int newPage) onConfirm;

  const _RecordPagesContent({
    required this.lang,
    required this.currentPage,
    required this.onConfirm,
  });

  @override
  State<_RecordPagesContent> createState() => _RecordPagesContentState();
}

class _RecordPagesContentState extends State<_RecordPagesContent> {
  bool _isRangeMode = false;
  final _countController = TextEditingController(text: '1');
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _countController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isRangeMode) {
      final from = int.tryParse(_fromController.text);
      final to = int.tryParse(_toController.text);
      if (from == null || to == null || from < 1 || to > 604 || from > to) {
        setState(() => _error = 'wird_page_range_invalid'.tr());
        return;
      }
      final additionalPages = to - from + 1;
      widget.onConfirm(additionalPages, to);
    } else {
      final pages = int.tryParse(_countController.text) ?? 0;
      if (pages > 0) {
        widget.onConfirm(pages, widget.currentPage + pages);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode toggle
        Row(
          children: [
            ChoiceChip(
              label: Text('wird_record_mode_count'.tr()),
              selected: !_isRangeMode,
              onSelected: (_) => setState(() { _isRangeMode = false; _error = null; }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('wird_record_mode_range'.tr()),
              selected: _isRangeMode,
              onSelected: (_) => setState(() { _isRangeMode = true; _error = null; }),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isRangeMode) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fromController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'wird_page_from'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _toController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'wird_page_to'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'wird_pages_read'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 4),
        Text(
          'wird_page_range_hint'.tr(),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submit,
              child: Text('ok'.tr()),
            ),
          ],
        ),
      ],
    );
  }
}

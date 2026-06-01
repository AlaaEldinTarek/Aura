import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/theme/app_typography.dart';
import 'package:aura_app/core/theme/app_spacing.dart';
import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/services/quran_service.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/tutorial_overlay.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/services/shared_preferences_service.dart';
import 'quran_reader_screen.dart';
import 'quran_search_screen.dart';
import 'wird_tab.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = SharedPreferencesService.instance;
      if (!prefs.isTutorialQuranSeen()) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) _launchSurahsTutorial();
      }
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    final prefs = SharedPreferencesService.instance;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (idx == 1 && !prefs.isTutorialJuzSeen()) _launchTabTutorial(
        titleKey: 'tutorial_juz_title',
        bodyKey: 'tutorial_juz_body',
        onDone: () => prefs.setTutorialJuzSeen(),
      );
      if (idx == 2 && !prefs.isTutorialBookmarksSeen()) _launchTabTutorial(
        titleKey: 'tutorial_bookmarks_title',
        bodyKey: 'tutorial_bookmarks_body',
        onDone: () => prefs.setTutorialBookmarksSeen(),
      );
    });
  }

  void _launchTabTutorial({
    required String titleKey,
    required String bodyKey,
    required VoidCallback onDone,
  }) {
    if (!mounted || _tabBarKey.currentContext == null) return;
    showTutorial(
      context: context,
      steps: [
        TutorialStep(targetKey: _tabBarKey, titleKey: titleKey, bodyKey: bodyKey),
      ],
      onDone: onDone,
    );
  }

  void _launchSurahsTutorial() {
    if (!mounted) return;
    final steps = <TutorialStep>[
      if (_tabBarKey.currentContext != null)
        TutorialStep(
          targetKey: _tabBarKey,
          titleKey: 'tutorial_quran_tabs_title',
          bodyKey: 'tutorial_quran_tabs_body',
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
      onDone: () => SharedPreferencesService.instance.setTutorialQuranSeen(),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final tabH = MediaQuery.textScalerOf(context).scale(kTextTabBarHeight).clamp(kTextTabBarHeight, 80.0);

    return ScaffoldMessenger(
      child: Scaffold(
      appBar: AppBar(
        title: Text('quran'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuranSearchScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(tabH),
          child: SizedBox(
            height: tabH,
            key: _tabBarKey,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'surahs'.tr(), height: tabH),
                Tab(text: 'juz'.tr(), height: tabH),
                Tab(text: 'bookmarks'.tr(), height: tabH),
                Tab(text: 'wird'.tr(), height: tabH),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SurahListTab(lang: lang),
          _JuzTab(lang: lang),
          _BookmarksTab(lang: lang),
          WirdTab(lang: lang),
        ],
      ),
    ),
    );
  }
}

class _SurahListTab extends ConsumerWidget {
  final String lang;

  const _SurahListTab({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = MediaQuery.textScalerOf(context);
    final surahsAsync = ref.watch(surahListProvider);

    return surahsAsync.when(
      loading: () => ListView.builder(
        itemCount: 12,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(vertical: ts.scale(4.0), horizontal: ts.scale(8.0)),
          child: const ShimmerListTile(),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (surahs) {
        final progressAsync = ref.watch(quranReadingProgressProvider);
        final progress = progressAsync.valueOrNull;

        return ListView.builder(
          itemCount: surahs.length + (progress != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (progress != null && index == 0) {
              return _LastReadCard(progress: progress, lang: lang);
            }
            final surahIdx = progress != null ? index - 1 : index;
            final surah = surahs[surahIdx];
            return _SurahTile(surah: surah, lang: lang);
          },
        );
      },
    );
  }
}

class _LastReadCard extends ConsumerWidget {
  final QuranReadingProgress progress;
  final String lang;

  const _LastReadCard({required this.progress, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = MediaQuery.textScalerOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final meta = QuranService.getSurahMeta(progress.suraNo);
    if (meta == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(ts.scale(16.0), ts.scale(12.0), ts.scale(16.0), ts.scale(4.0)),
      child: Card(
        color: primary.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(Icons.auto_stories, color: primary),
          title: Text('last_read'.tr(), style: AppTypography.caption),
          subtitle: Text(
            lang == 'ar'
                ? '${meta.nameAr} - ${NumberFormatter.withArabicNumeralsByLanguage(progress.ayaNo.toString(), lang)}'
                : '${meta.nameEn} - ${progress.ayaNo}',
            style: AppTypography.label.copyWith(fontWeight: FontWeight.bold),
          ),
          trailing: Icon(Icons.arrow_forward, size: ts.scale(18.0)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuranReaderScreen(
                  suraNo: progress.suraNo,
                  scrollToAyaNo: progress.ayaNo,
                  initialPage: progress.page,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final Surah surah;
  final String lang;

  const _SurahTile({required this.surah, required this.lang});

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final meta = surah.meta;

    return ListTile(
      leading: CircleAvatar(
        radius: ts.scale(18.0),
        backgroundColor: primary.withValues(alpha: 0.15),
        child: Text(
          NumberFormatter.withArabicNumeralsByLanguage(meta.suraNo.toString(), lang),
          style: AppTypography.bodyS.copyWith(fontWeight: FontWeight.bold, color: primary),
        ),
      ),
      title: Text(
        lang == 'ar' ? meta.nameAr : meta.nameEn,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label,
      ),
      subtitle: Text(
        '${meta.revelationType == RevelationType.makki ? 'makki'.tr() : 'madani'.tr()} • ${NumberFormatter.withArabicNumeralsByLanguage(meta.ayahCount.toString(), lang)} ${'ayah_count'.tr()}',
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          color: AppConstants.textSecondary(isDark),
        ),
      ),
      // Decorative Uthmanic name on the trailing side; cap width+fontSize to prevent overflow
      trailing: Builder(builder: (ctx) {
        final ts = MediaQuery.textScalerOf(ctx);
        return Text(
          meta.nameAr,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: ts.scale(14.0).clamp(14.0, 16.0),
            color: AppConstants.textSecondary(isDark),
          ),
        );
      }),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuranReaderScreen(suraNo: meta.suraNo, initialPage: meta.startPage)),
        );
      },
    );
  }
}

class _JuzTab extends ConsumerWidget {
  final String lang;

  const _JuzTab({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = MediaQuery.textScalerOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final juzAsync = ref.watch(juzListProvider);

    return juzAsync.when(
      loading: () => ListView.builder(
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(vertical: ts.scale(4.0), horizontal: ts.scale(8.0)),
          child: const ShimmerListTile(),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (juzList) => ListView.builder(
        itemCount: juzList.length,
        itemBuilder: (context, index) {
          final juz = juzList[index];
          return ListTile(
            leading: CircleAvatar(
              radius: ts.scale(18.0),
              backgroundColor: primary.withValues(alpha: 0.15),
              child: Text(
                NumberFormatter.withArabicNumeralsByLanguage(juz.juzNo.toString(), lang),
                style: AppTypography.bodyS.copyWith(fontWeight: FontWeight.bold, color: primary),
              ),
            ),
            title: Text(lang == 'ar' ? juz.firstSurahNameAr : juz.firstSurahNameEn),
            subtitle: Text(
              '${'page'.tr()} ${NumberFormatter.withArabicNumeralsByLanguage(juz.startPage.toString(), lang)} - ${NumberFormatter.withArabicNumeralsByLanguage(juz.endPage.toString(), lang)}',
              style: AppTypography.caption.copyWith(
                color: AppConstants.textSecondary(isDark),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuranReaderScreen(suraNo: 1, initialJuz: juz.juzNo),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  final String lang;

  static const _bookmarkColors = {
    BookmarkColor.red: Color(0xFFE53935),
    BookmarkColor.orange: Color(0xFFFB8C00),
    BookmarkColor.green: Color(0xFF43A047),
  };

  const _BookmarksTab({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = MediaQuery.textScalerOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookmarksAsync = ref.watch(quranBookmarksProvider);

    return bookmarksAsync.when(
      loading: () => ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(vertical: ts.scale(4.0), horizontal: ts.scale(8.0)),
          child: const ShimmerListTile(),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return EmptyState(
            iconEmoji: '🔖',
            title: 'empty_bookmarks_title'.tr(),
            subtitle: 'empty_bookmarks_subtitle'.tr(),
          );
        }

        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bm = bookmarks[index];
            final dotColor = _bookmarkColors[bm.color] ?? const Color(0xFF43A047);
            return ListTile(
              leading: Container(
                width: ts.scale(32.0), height: ts.scale(32.0),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bookmark, color: dotColor, size: ts.scale(18.0)),
              ),
              title: Text(
                lang == 'ar' ? bm.suraNameAr : bm.suraNameEn,
                style: AppTypography.label,
              ),
              subtitle: Text(
                bm.ayaText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: ts.scale(14.0),
                  color: AppConstants.textSecondary(isDark),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${NumberFormatter.withArabicNumeralsByLanguage(bm.suraNo.toString(), lang)}:${NumberFormatter.withArabicNumeralsByLanguage(bm.ayaNo.toString(), lang)}',
                    style: AppTypography.bodyS.copyWith(
                      color: AppConstants.textSecondary(isDark),
                    ),
                  ),
                  SizedBox(width: ts.scale(4.0)),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: ts.scale(20.0), color: AppConstants.textSecondary(isDark)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('bookmark_delete_title'.tr()),
                          content: Text('bookmark_delete_message'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('cancel'.tr()),
                            ),
                            FilledButton(
                              onPressed: () {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(ctx);
                                ref.read(quranBookmarksProvider.notifier).removeBookmark(bm.id);
                                messenger.clearSnackBars();
                                final controller = messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('bookmark_deleted'.tr()),
                                    duration: const Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.only(bottom: ts.scale(82.0), left: ts.scale(16.0), right: ts.scale(16.0)),
                                    action: SnackBarAction(
                                      label: 'undo'.tr(),
                                      onPressed: () {
                                        ref.read(quranBookmarksProvider.notifier).addBookmark(bm);
                                      },
                                    ),
                                  ),
                                );
                                Future.delayed(const Duration(seconds: 3), controller.close);
                              },
                              child: Text('ok'.tr()),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuranReaderScreen(suraNo: bm.suraNo, scrollToAyaNo: bm.ayaNo, initialPage: bm.page),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

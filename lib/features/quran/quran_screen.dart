import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/services/quran_service.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import 'quran_reader_screen.dart';
import 'quran_search_screen.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'surahs'.tr()),
            Tab(text: 'juz'.tr()),
            Tab(text: 'bookmarks'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SurahListTab(lang: lang),
          _JuzTab(lang: lang),
          _BookmarksTab(lang: lang),
        ],
      ),
    );
  }
}

class _SurahListTab extends ConsumerWidget {
  final String lang;

  const _SurahListTab({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahsAsync = ref.watch(surahListProvider);

    return surahsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final meta = QuranService.getSurahMeta(progress.suraNo);
    if (meta == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        color: primary.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(Icons.auto_stories, color: primary),
          title: Text('last_read'.tr(), style: const TextStyle(fontSize: 12)),
          subtitle: Text(
            lang == 'ar'
                ? '${meta.nameAr} - ${NumberFormatter.withArabicNumeralsByLanguage(progress.ayaNo.toString(), lang)}'
                : '${meta.nameEn} - ${progress.ayaNo}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(Icons.arrow_forward, size: 18),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final meta = surah.meta;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: primary.withValues(alpha: 0.15),
        child: Text(
          NumberFormatter.withArabicNumeralsByLanguage(meta.suraNo.toString(), lang),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primary),
        ),
      ),
      title: Text(
        lang == 'ar' ? meta.nameAr : meta.nameEn,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${meta.revelationType == RevelationType.makki ? 'makki'.tr() : 'madani'.tr()} • ${NumberFormatter.withArabicNumeralsByLanguage(meta.ayahCount.toString(), lang)} ${'ayah_count'.tr()}',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
        ),
      ),
      trailing: Text(
        meta.nameAr,
        style: TextStyle(
          fontFamily: 'HafsSmart',
          fontSize: 18,
          color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final juzAsync = ref.watch(juzListProvider);

    return juzAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (juzList) => ListView.builder(
        itemCount: juzList.length,
        itemBuilder: (context, index) {
          final juz = juzList[index];
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: primary.withValues(alpha: 0.15),
              child: Text(
                NumberFormatter.withArabicNumeralsByLanguage(juz.juzNo.toString(), lang),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primary),
              ),
            ),
            title: Text(lang == 'ar' ? juz.firstSurahNameAr : juz.firstSurahNameEn),
            subtitle: Text(
              '${'page'.tr()} ${NumberFormatter.withArabicNumeralsByLanguage(juz.startPage.toString(), lang)} - ${NumberFormatter.withArabicNumeralsByLanguage(juz.endPage.toString(), lang)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
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

  const _BookmarksTab({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final bookmarksAsync = ref.watch(quranBookmarksProvider);

    return bookmarksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('no_bookmarks'.tr(), style: TextStyle(fontSize: 16, color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bm = bookmarks[index];
            return ListTile(
              leading: Icon(Icons.bookmark, color: primary),
              title: Text(
                lang == 'ar' ? bm.suraNameAr : bm.suraNameEn,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                bm.ayaText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'HafsSmart',
                  fontSize: 14,
                  color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                ),
              ),
              trailing: Text(
                '${NumberFormatter.withArabicNumeralsByLanguage(bm.suraNo.toString(), lang)}:${NumberFormatter.withArabicNumeralsByLanguage(bm.ayaNo.toString(), lang)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuranReaderScreen(suraNo: bm.suraNo, scrollToAyaNo: bm.ayaNo, initialPage: bm.page),
                  ),
                );
              },
              onLongPress: () {
                ref.read(quranBookmarksProvider.notifier).removeBookmark(bm.id);
              },
            );
          },
        );
      },
    );
  }
}

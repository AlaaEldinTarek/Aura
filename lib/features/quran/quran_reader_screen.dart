import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/services/quran_service.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

class QuranReaderScreen extends ConsumerStatefulWidget {
  final int suraNo;
  final int? scrollToAyaNo;
  final int? initialJuz;
  final int? initialPage;

  const QuranReaderScreen({
    super.key,
    required this.suraNo,
    this.scrollToAyaNo,
    this.initialJuz,
    this.initialPage,
  });

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  List<Ayah> _currentPageAyahs = [];
  bool _isLoading = true;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage ?? _getStartPage();
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadPage(_currentPage);
  }

  int _getStartPage() {
    if (widget.initialJuz != null) {
      final juzList = QuranService.getJuzListSync();
      if (juzList != null && widget.initialJuz! <= juzList.length) {
        return juzList[widget.initialJuz! - 1].startPage;
      }
    }
    final meta = QuranService.getSurahMeta(widget.suraNo);
    return meta?.startPage ?? 1;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int page) async {
    final ayahs = await QuranService.getAyahsByPage(page);
    setState(() {
      _currentPageAyahs = ayahs;
      _isLoading = false;
    });

    if (ayahs.isNotEmpty) {
      ref.read(quranReadingProgressProvider.notifier).saveProgress(
            ayahs.first.suraNo,
            ayahs.first.ayaNo,
            page,
          );
    }
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    _currentPage = page;
    _loadPage(page);
  }

  void _toggleBookmark(Ayah ayah) {
    final id = '${ayah.suraNo}_${ayah.ayaNo}';
    final bookmarks = ref.read(quranBookmarksProvider).valueOrNull ?? [];
    final exists = bookmarks.any((b) => b.id == id);

    if (exists) {
      ref.read(quranBookmarksProvider.notifier).removeBookmark(id);
    } else {
      ref.read(quranBookmarksProvider.notifier).addBookmark(QuranBookmark(
        id: id,
        suraNo: ayah.suraNo,
        ayaNo: ayah.ayaNo,
        page: ayah.page,
        suraNameAr: ayah.suraNameAr,
        suraNameEn: ayah.suraNameEn,
        ayaText: ayah.ayaTextEmlaey,
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final isArabic = lang == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final meta = _currentPageAyahs.isNotEmpty
        ? QuranService.getSurahMeta(_currentPageAyahs.first.suraNo)
        : null;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => setState(() => _showUI = !_showUI),
          child: Stack(
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                PageView.builder(
                  controller: _pageController,
                  itemCount: 604,
                  reverse: isArabic,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final page = index + 1;
                    return _MushafPage(
                      page: page,
                      lang: lang,
                      onAyahLongPress: _toggleBookmark,
                      bookmarks: ref.watch(quranBookmarksProvider).valueOrNull ?? [],
                    );
                  },
                ),

              if (_showUI)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _TopBar(
                    surahName: isArabic ? (meta?.nameAr ?? '') : (meta?.nameEn ?? ''),
                    pageNo: _currentPage,
                    lang: lang,
                    onClose: () => Navigator.pop(context),
                  ),
                ),

              if (_showUI)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _BottomBar(
                    currentPage: _currentPage,
                    totalPages: 604,
                    lang: lang,
                    onPrevious: _currentPage < 604 ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } : null,
                    onNext: _currentPage > 1 ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MushafPage extends StatelessWidget {
  final int page;
  final String lang;
  final void Function(Ayah) onAyahLongPress;
  final List<QuranBookmark> bookmarks;

  const _MushafPage({
    required this.page,
    required this.lang,
    required this.onAyahLongPress,
    required this.bookmarks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<Ayah>>(
      future: QuranService.getAyahsByPage(page),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final ayahs = snapshot.data!;

        final totalChars = ayahs.fold<int>(
            0, (sum, a) => sum + a.ayaText.length);
        // Scale up subtly for lighter pages, capped at 12% to prevent scroll
        final ratio = (totalChars / 2000).clamp(0.0, 1.0);
        final textScale = 1.0 + (1.0 - ratio) * 0.12;
        final fontSize = 28.0 * textScale;
        final lineHeight = 1.8 + (1.0 - ratio) * 0.10;

        final isCenterPage = page <= 2;

        return Container(
          color: theme.scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: isCenterPage
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        _PageHeader(ayahs: ayahs, lang: lang),
                        const SizedBox(height: 4),
                        ..._buildPageSections(ayahs, isDark, fontSize, lineHeight),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPageSections(List<Ayah> ayahs, bool isDark, double fontSize, double lineHeight) {
    final sections = <MapEntry<int, List<Ayah>>>[];
    for (final ayah in ayahs) {
      if (sections.isEmpty || sections.last.key != ayah.suraNo) {
        sections.add(MapEntry(ayah.suraNo, [ayah]));
      } else {
        sections.last.value.add(ayah);
      }
    }

    final primary = AppConstants.getPrimary(isDark);
    final widgets = <Widget>[];
    for (int i = 0; i < sections.length; i++) {
      final sectionAyahs = sections[i].value;
      final isFirstSection = i == 0;
      final isSurahStart = sectionAyahs.first.ayaNo == 1;

      // Show surah header for every new surah starting on this page
      if (isSurahStart || !isFirstSection) {
        final meta = QuranService.getSurahMeta(sections[i].key);
        if (meta != null) {
          if (!isFirstSection) {
            widgets.add(const SizedBox(height: 3));
          }
          widgets.add(_SurahHeader(meta: meta, isDark: isDark));
          widgets.add(const SizedBox(height: 5));
        }
      }

      final buffer = StringBuffer();
      for (int j = 0; j < sectionAyahs.length; j++) {
        buffer.write(sectionAyahs[j].ayaText);
        if (j < sectionAyahs.length - 1) {
          buffer.write(' ');
        }
      }

      final fullText = buffer.toString();
      widgets.add(
        Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Text(
            fullText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'HafsSmart',
              fontSize: fontSize,
              height: lineHeight,
              color: isDark ? AppConstants.darkTextPrimary : AppConstants.lightTextPrimary,
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _SurahHeader extends StatelessWidget {
  final SurahMetaData meta;
  final bool isDark;

  const _SurahHeader({required this.meta, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = AppConstants.getPrimary(isDark);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BoldOrnamentalDivider(color: primary),
          const SizedBox(height: 3),
          Text(
            meta.nameAr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'HafsSmart',
              fontSize: 26,
              height: 1.4,
              color: primary,
            ),
          ),
          const SizedBox(height: 3),
          _BoldOrnamentalDivider(color: primary),
          if (meta.suraNo != 9 && meta.suraNo != 1) ...[
            const SizedBox(height: 4),
            Text(
              'بسم الله الرحمن الرحيم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'HafsSmart',
                fontSize: 20,
                height: 1.4,
                color: primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoldOrnamentalDivider extends StatelessWidget {
  final Color color;
  const _BoldOrnamentalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(height: 1.5, color: color.withValues(alpha: 0.35)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('✦', style: TextStyle(color: color, fontSize: 14)),
        ),
        Expanded(
          child: Container(height: 1.5, color: color.withValues(alpha: 0.35)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('✦', style: TextStyle(color: color, fontSize: 14)),
        ),
        Expanded(
          child: Container(height: 1.5, color: color.withValues(alpha: 0.35)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('✦', style: TextStyle(color: color, fontSize: 14)),
        ),
        Expanded(
          child: Container(height: 1.5, color: color.withValues(alpha: 0.35)),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  final List<Ayah> ayahs;
  final String lang;

  const _PageHeader({required this.ayahs, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (ayahs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final firstAyah = ayahs.first;

    final surahsOnPage = <int>{};
    for (final a in ayahs) {
      surahsOnPage.add(a.suraNo);
    }
    final meta = QuranService.getSurahMeta(firstAyah.suraNo);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${'juz'.tr()} ${NumberFormatter.withArabicNumeralsByLanguage(firstAyah.jozz.toString(), lang)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary),
            ),
          ),
          if (surahsOnPage.length == 1 && meta != null)
            Text(
              lang == 'ar' ? meta.nameAr : meta.nameEn,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${'page'.tr()} ${NumberFormatter.withArabicNumeralsByLanguage(firstAyah.page.toString(), lang)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  final int page;
  final String lang;

  const _PageNumber({required this.page, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(
        NumberFormatter.withArabicNumeralsByLanguage(page.toString(), lang),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String surahName;
  final int pageNo;
  final String lang;
  final VoidCallback onClose;

  const _TopBar({
    required this.surahName,
    required this.pageNo,
    required this.lang,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppConstants.darkSurface : AppConstants.lightSurface).withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: theme.hintColor),
            onPressed: onClose,
            iconSize: 22,
          ),
          Expanded(
            child: Text(
              surahName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: theme.hintColor),
            onPressed: onClose,
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final String lang;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.lang,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppConstants.darkSurface : AppConstants.lightSurface).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: onNext,
              icon: Icon(
                lang == 'ar' ? Icons.arrow_forward : Icons.arrow_back,
                color: currentPage > 1 ? primary : Colors.grey,
              ),
            ),
            Expanded(
              child: Text(
                '${NumberFormatter.withArabicNumeralsByLanguage(currentPage.toString(), lang)} / ${NumberFormatter.withArabicNumeralsByLanguage(totalPages.toString(), lang)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                ),
              ),
            ),
            IconButton(
              onPressed: onPrevious,
              icon: Icon(
                lang == 'ar' ? Icons.arrow_back : Icons.arrow_forward,
                color: currentPage < totalPages ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/quran_provider.dart';
import '../../core/providers/task_provider.dart';
import '../../core/models/quran_models.dart';
import '../../core/services/quran_data_service.dart';
import '../../core/services/quran_reading_service.dart';
import '../../core/utils/number_formatter.dart';

class QuranReaderScreen extends ConsumerStatefulWidget {
  final int? initialSurah;
  final int initialPage;

  const QuranReaderScreen({super.key, this.initialSurah, this.initialPage = 1});

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  bool _isBookmarked = false;
  Timer? _readingTimer;
  bool _pageTracked = false;

  static const int _totalPages = 604;
  static const String _imageBaseUrl =
      'https://cdn.jsdelivr.net/gh/akram-seid/quran-hd-images@main/images';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    WakelockPlus.enable();
    _checkBookmark();
    _startReadingTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _readingTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startReadingTimer() {
    _pageTracked = false;
    _readingTimer?.cancel();
    _readingTimer = Timer(const Duration(seconds: 3), () {
      if (!_pageTracked && mounted) {
        _pageTracked = true;
        ref.read(quranReadingProgressProvider.notifier).markPageRead(_currentPage);
      }
    });
  }

  Future<void> _checkBookmark() async {
    final pageAyahs = await QuranDataService.instance.loadPage(_currentPage);
    if (pageAyahs.isEmpty) return;
    final firstAyah = pageAyahs.first;
    final userId = ref.read(currentUserIdProvider);
    final bookmarked = await QuranReadingService.instance.isBookmarked(
      userId, firstAyah.page, firstAyah.numberInSurah,
    );
    if (mounted) setState(() => _isBookmarked = bookmarked);
  }

  void _onPageChanged(int page) {
    final newPage = page + 1;
    if (newPage == _currentPage) return;
    setState(() {
      _currentPage = newPage;
      _isBookmarked = false;
    });
    _checkBookmark();
    _startReadingTimer();
  }

  String _pageImageUrl(int page) {
    final padded = page.toString().padLeft(3, '0');
    return '$_imageBaseUrl/$padded.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pageEntry = QuranDataService.instance.getPageEntry(_currentPage);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5ECD7),
      appBar: AppBar(
        title: Text(
          pageEntry != null
              ? '${'page'.tr()} ${isArabic ? NumberFormatter.withArabicNumerals('$_currentPage') : _currentPage} • ${'juz'.tr()} ${isArabic ? NumberFormatter.withArabicNumerals('${pageEntry.juz}') : pageEntry.juz}'
              : '${'page'.tr()} $_currentPage',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showJumpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: _onPageChanged,
              reverse: isArabic,
              itemBuilder: (context, index) {
                final pageNumber = index + 1;
                return _buildPageImage(pageNumber, isDark);
              },
            ),
          ),
          _buildBottomBar(isDark, isArabic),
        ],
      ),
    );
  }

  Widget _buildPageImage(int pageNumber, bool isDark) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Container(
        color: isDark ? Colors.black : const Color(0xFFF5ECD7),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: _pageImageUrl(pageNumber),
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) {
              debugPrint('❌ [QURAN] Image load failed for page $pageNumber: $error');
              return _buildTextFallback(pageNumber, isDark);
            },
          ),
        ),
      ),
    );
  }

  // Fallback to text if image fails to load
  Widget _buildTextFallback(int pageNumber, bool isDark) {
    final pageAsync = ref.watch(quranPageProvider(pageNumber));
    return pageAsync.when(
      data: (ayahs) {
        if (ayahs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text('error_loading'.tr()),
              ],
            ),
          );
        }
        // Group ayahs by surah
        final groups = _groupBySurah(ayahs);
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111317) : const Color(0xFFFFFBF0),
            border: Border.all(color: isDark ? const Color(0xFF3A3520) : const Color(0xFFD4A43A)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final group in groups) ...[
                  if (group.needsHeader) _buildSurahHeader(group, isDark),
                  _buildFlowingText(group.ayahs, isDark),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text('error_loading'.tr())),
    );
  }

  Widget _buildFlowingText(List<QuranAyah> ayahs, bool isDark) {
    final spans = <TextSpan>[];
    for (final ayah in ayahs) {
      spans.add(TextSpan(text: ayah.textAr));
      spans.add(TextSpan(
        text: ' ﴿${ayah.numberInSurah}﴾ ',
        style: TextStyle(
          color: isDark ? const Color(0xFFD4A43A) : const Color(0xFF7A5C00),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ));
    }
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: RichText(
        textAlign: TextAlign.justify,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: 24,
            color: isDark ? const Color(0xFFE8D5A8) : const Color(0xFF1A0F00),
            height: 2.4,
          ),
          children: spans,
        ),
      ),
    );
  }

  Widget _buildSurahHeader(_SurahGroup group, bool isDark) {
    final meta = group.surahMeta;
    if (meta == null) return const SizedBox.shrink();
    final goldColor = isDark ? const Color(0xFFD4A43A) : const Color(0xFF8B6914);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Column(
        children: [
          Text(meta.nameAr,
              style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 28, color: goldColor)),
          const SizedBox(height: 4),
          Text('${meta.numberOfAyahs} Ayahs • ${meta.revelationType}',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
          if (meta.number != 9 && meta.number != 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                  style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 22, color: isDark ? const Color(0xFFE8D5A8) : const Color(0xFF2A1800), height: 2.0)),
            ),
          Divider(color: goldColor.withOpacity(0.4)),
        ],
      ),
    );
  }

  List<_SurahGroup> _groupBySurah(List<QuranAyah> ayahs) {
    final groups = <_SurahGroup>[];
    _SurahGroup? current;
    for (final ayah in ayahs) {
      final meta = QuranDataService.instance.getSurahMetaForPage(ayah.page, ayah.numberInSurah);
      if (current == null || current.surahNumber != (meta?.number ?? 0)) {
        current = _SurahGroup(
          surahNumber: meta?.number ?? 0,
          surahMeta: meta,
          needsHeader: ayah.numberInSurah == 1,
          ayahs: [],
        );
        groups.add(current);
      }
      current.ayahs.add(ayah);
    }
    return groups;
  }

  // ─── Bottom Bar ────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isDark, bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 1
                  ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
            ),
            Expanded(
              child: Text(
                isArabic
                    ? '${NumberFormatter.withArabicNumerals('$_currentPage')} / ${NumberFormatter.withArabicNumerals('$_totalPages')}'
                    : '$_currentPage / $_totalPages',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppConstants.lightTextPrimary),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages
                  ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bookmark ──────────────────────────────────────────────────────

  Future<void> _toggleBookmark() async {
    final pageAyahs = await QuranDataService.instance.loadPage(_currentPage);
    if (pageAyahs.isEmpty) return;
    final firstAyah = pageAyahs.first;
    final userId = ref.read(currentUserIdProvider);

    if (_isBookmarked) {
      final bookmarks = await QuranReadingService.instance.getBookmarks(userId);
      final existing = bookmarks.where((b) => b.surahNumber == firstAyah.page && b.ayahNumber == firstAyah.numberInSurah);
      for (final b in existing) {
        await QuranReadingService.instance.removeBookmark(userId, b.id ?? '');
      }
    } else {
      await QuranReadingService.instance.addBookmark(
        userId,
        QuranBookmark(surahNumber: firstAyah.page, ayahNumber: firstAyah.numberInSurah, page: _currentPage, createdAt: DateTime.now()),
      );
    }
    setState(() => _isBookmarked = !_isBookmarked);
    ref.invalidate(quranBookmarksProvider);
  }

  // ─── Jump to Page ──────────────────────────────────────────────────

  void _showJumpDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('jump_to_page'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1 - 604',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= 604) {
                Navigator.pop(ctx);
                _pageController.animateToPage(page - 1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
            },
            child: Text('go'.tr()),
          ),
        ],
      ),
    );
  }
}

class _SurahGroup {
  final int surahNumber;
  final QuranSurahMeta? surahMeta;
  final bool needsHeader;
  final List<QuranAyah> ayahs;
  _SurahGroup({required this.surahNumber, this.surahMeta, required this.needsHeader, required this.ayahs});
}

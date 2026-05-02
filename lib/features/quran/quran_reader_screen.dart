import 'dart:io';
import 'dart:math' show min, max;
import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/services/quran_service.dart';
import 'package:aura_app/core/services/quran_svg_service.dart';
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
  bool _showUI = true;

  static const _juzStartPages = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage ?? _getStartPage();
    _pageController = PageController(initialPage: _currentPage - 1);
    _saveProgress(_currentPage);
    QuranSvgService.preload(_currentPage - 1);
    QuranSvgService.preload(_currentPage + 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getStartPage() {
    if (widget.initialJuz != null) {
      final juz = widget.initialJuz!;
      if (juz >= 1 && juz <= 30) return _juzStartPages[juz - 1];
    }
    final meta = QuranService.getSurahMeta(widget.suraNo);
    return meta?.startPage ?? 1;
  }

  SurahMetaData? _surahForPage(int page) {
    SurahMetaData? result;
    for (final meta in kSurahMetaData) {
      if (meta.startPage <= page) result = meta;
      if (meta.startPage > page) break;
    }
    return result;
  }

  void _saveProgress(int page) {
    final meta = _surahForPage(page);
    if (meta != null) {
      ref.read(quranReadingProgressProvider.notifier).saveProgress(
            meta.suraNo, 1, page,
          );
    }
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    setState(() => _currentPage = page);
    _saveProgress(page);
    QuranSvgService.preload(page - 1);
    QuranSvgService.preload(page + 1);
  }

  void _togglePageBookmark() {
    final meta = _surahForPage(_currentPage);
    if (meta == null) return;
    final id = 'page_$_currentPage';
    final bookmarks = ref.read(quranBookmarksProvider).valueOrNull ?? [];
    if (bookmarks.any((b) => b.id == id)) {
      ref.read(quranBookmarksProvider.notifier).removeBookmark(id);
    } else {
      ref.read(quranBookmarksProvider.notifier).addBookmark(QuranBookmark(
        id: id,
        suraNo: meta.suraNo,
        ayaNo: 1,
        page: _currentPage,
        suraNameAr: meta.nameAr,
        suraNameEn: meta.nameEn,
        ayaText: '',
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> _handleAyahTap(Ayah ayah) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final lang = context.locale.languageCode;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final bookmarks = ref.watch(quranBookmarksProvider).valueOrNull ?? [];
          final id = '${ayah.suraNo}_${ayah.ayaNo}';
          final existing = bookmarks.where((b) => b.id == id).firstOrNull;

          return _AyahSheet(
            ayah: ayah,
            lang: lang,
            isDark: isDark,
            primary: primary,
            existingBookmark: existing,
            onBookmark: (color) {
              if (existing != null) {
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
                  color: color,
                  createdAt: DateTime.now(),
                ));
              }
            },
            onRemove: () {
              ref.read(quranBookmarksProvider.notifier).removeBookmark(id);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final isArabic = lang == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final meta = _surahForPage(_currentPage);
    final bookmarks = ref.watch(quranBookmarksProvider).valueOrNull ?? [];
    final isBookmarked = bookmarks.any((b) => b.id == 'page_$_currentPage');

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: 604,
              reverse: isArabic,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _MushafPage(
                  key: ValueKey(index + 1),
                  page: index + 1,
                  onAyahTap: _handleAyahTap,
                  onEmptyTap: () => setState(() => _showUI = !_showUI),
                );
              },
            ),

            if (_showUI)
              Positioned(
                top: 0, left: 0, right: 0,
                child: _TopBar(
                  surahName: isArabic
                      ? (meta?.nameAr ?? '')
                      : (meta?.nameEn ?? ''),
                  pageNo: _currentPage,
                  lang: lang,
                  isBookmarked: isBookmarked,
                  primary: primary,
                  onBookmarkToggle: _togglePageBookmark,
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
                  onPrevious: _currentPage < 604
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  onNext: _currentPage > 1
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── SVG page ──────────────────────────────────────────────────────────────────

class _MushafPage extends ConsumerStatefulWidget {
  final int page;
  final Future<void> Function(Ayah) onAyahTap;
  final VoidCallback onEmptyTap;

  const _MushafPage({
    super.key,
    required this.page,
    required this.onAyahTap,
    required this.onEmptyTap,
  });

  @override
  ConsumerState<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends ConsumerState<_MushafPage> {
  late Future<(String, List<Ayah>)> _pageFuture;
  Ayah? _selectedAyah;

  // Pages 1–2 use a square viewBox; all other pages use a portrait viewBox.
  static const _vbSquare = Size(235, 235);
  static const _vbPortrait = Size(345, 550);

  // SVG y-coordinates where mushaf text begins and ends on each page type.
  static const _topSquare = 18.0;
  static const _bottomSquare = 215.0;
  static const _topPortrait = 5.75;
  static const _bottomPortrait = 545.0;

  Size get _viewBox => widget.page <= 2 ? _vbSquare : _vbPortrait;
  double get _contentTop => widget.page <= 2 ? _topSquare : _topPortrait;
  double get _contentBottom => widget.page <= 2 ? _bottomSquare : _bottomPortrait;

  @override
  void initState() {
    super.initState();
    _pageFuture = _load();
  }

  Future<(String, List<Ayah>)> _load() async {
    final results = await Future.wait<dynamic>([
      QuranSvgService.getPage(widget.page),
      QuranService.getAyahsByPage(widget.page),
    ]);
    final svgString = await (results[0] as File).readAsString();
    return (svgString, results[1] as List<Ayah>);
  }

  void _retry() => setState(() => _pageFuture = _load());

  // Converts a tap position in widget space to SVG coordinate space.
  Offset _toSvg(Offset tap, Size container) {
    final vb = _viewBox;
    final scale = min(container.width / vb.width, container.height / vb.height);
    final ox = (container.width - vb.width * scale) / 2;
    final oy = (container.height - vb.height * scale) / 2;
    return Offset((tap.dx - ox) / scale, (tap.dy - oy) / scale);
  }

  // Maps an SVG y-coordinate to the ayah on that line.
  Ayah? _findAyah(double svgY, List<Ayah> ayahs) {
    if (ayahs.isEmpty) return null;
    final ratio = ((svgY - _contentTop) / (_contentBottom - _contentTop)).clamp(0.0, 1.0);
    final minLine = ayahs.map((a) => a.lineStart).reduce(min);
    final maxLine = ayahs.map((a) => a.lineEnd).reduce(max);
    final line = (minLine + ratio * (maxLine - minLine)).round();

    for (final ayah in ayahs) {
      if (ayah.lineStart <= line && line <= ayah.lineEnd) return ayah;
    }
    // Closest fallback — always return something rather than null.
    return ayahs.reduce((a, b) {
      final am = (a.lineStart + a.lineEnd) / 2;
      final bm = (b.lineStart + b.lineEnd) / 2;
      return (am - line).abs() < (bm - line).abs() ? a : b;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppConstants.darkSurface : AppConstants.lightSurface;
    final bookmarks = ref.watch(quranBookmarksProvider).valueOrNull ?? [];

    return ColoredBox(
      color: bgColor,
      child: FutureBuilder<(String, List<Ayah>)>(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final isOffline = QuranSvgService.isNetworkError(snapshot.error!);
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isOffline ? 'error_network'.tr() : 'Failed to load page',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _retry, child: Text('retry'.tr())),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          final (svgRaw, ayahs) = snapshot.data!;

          // Map: marker index (sorted by y) → bookmark color.
          final sortedAyahs = List<Ayah>.from(ayahs)..sort((a, b) => a.ayaNo.compareTo(b.ayaNo));
          final colorMap = <int, BookmarkColor>{};
          for (int i = 0; i < sortedAyahs.length; i++) {
            final bm = bookmarks.where(
              (b) => b.suraNo == sortedAyahs[i].suraNo && b.ayaNo == sortedAyahs[i].ayaNo,
            ).firstOrNull;
            if (bm != null) colorMap[i] = bm.color;
          }
          final svgString = _AyahMarkerColorizer.colorize(svgRaw, colorMap, isDark);

          Widget svgWidget = SvgPicture.string(svgString, fit: BoxFit.contain);

          if (isDark) {
            svgWidget = ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                -1,  0,  0, 0, 255,
                 0, -1,  0, 0, 255,
                 0,  0, -1, 0, 255,
                 0,  0,  0, 1,   0,
              ]),
              child: svgWidget,
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final svgCoord = _toSvg(details.localPosition, constraints.biggest);
                  final vb = _viewBox;
                  if (svgCoord.dx < 0 || svgCoord.dx > vb.width ||
                      svgCoord.dy < _contentTop || svgCoord.dy > _contentBottom) {
                    widget.onEmptyTap();
                    return;
                  }
                  final ayah = _findAyah(svgCoord.dy, ayahs);
                  if (ayah != null) {
                    setState(() => _selectedAyah = ayah);
                    widget.onAyahTap(ayah).then((_) {
                      if (mounted) setState(() => _selectedAyah = null);
                    });
                  } else {
                    widget.onEmptyTap();
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    svgWidget,
                    if (_selectedAyah != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _AyahHighlightPainter(
                              ayah: _selectedAyah!,
                              allAyahs: ayahs,
                              viewBox: _viewBox,
                              contentTop: _contentTop,
                              contentBottom: _contentBottom,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Ayah bottom sheet ─────────────────────────────────────────────────────────

class _AyahSheet extends StatelessWidget {
  final Ayah ayah;
  final String lang;
  final bool isDark;
  final Color primary;
  final QuranBookmark? existingBookmark;
  final void Function(BookmarkColor color) onBookmark;
  final VoidCallback onRemove;

  static const _colorMap = {
    BookmarkColor.red: Color(0xFFE53935),
    BookmarkColor.orange: Color(0xFFFB8C00),
    BookmarkColor.green: Color(0xFF43A047),
  };

  const _AyahSheet({
    required this.ayah,
    required this.lang,
    required this.isDark,
    required this.primary,
    required this.existingBookmark,
    required this.onBookmark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final meta = QuranService.getSurahMeta(ayah.suraNo);
    final surface = isDark ? AppConstants.darkCard : AppConstants.lightCard;
    final hint = isDark ? Colors.white38 : Colors.black38;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: hint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Surah name + ayah reference
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == 'ar' ? (meta?.nameAr ?? '') : (meta?.nameEn ?? ''),
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${NumberFormatter.withArabicNumeralsByLanguage(ayah.suraNo.toString(), lang)}:${NumberFormatter.withArabicNumeralsByLanguage(ayah.ayaNo.toString(), lang)}',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ayah text
          Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Text(
              ayah.ayaTextEmlaey,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 18,
                height: 1.9,
                color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Color picker row
          Row(
            children: [
              for (final entry in _colorMap.entries) ...[
                _ColorButton(
                  color: entry.value,
                  selected: existingBookmark?.color == entry.key,
                  onTap: () => onBookmark(entry.key),
                ),
                const SizedBox(width: 12),
              ],
              const Spacer(),
              if (existingBookmark != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text('remove'.tr(), style: const TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 1.0 : 0.25),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: color, width: 3)
              : null,
        ),
        child: selected
            ? const Icon(Icons.bookmark, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

// ── Ayah marker colorizer ─────────────────────────────────────────────────────
// Rewrites fill color inside <g ayah:y="..."> elements so bookmarked ayah
// number ornaments render in gold.  In dark mode the SVG is later inverted by
// a ColorFilter, so we pre-invert the gold (#F5B301 → #0A4CFE) so it comes
// out gold after inversion.

class _AyahMarkerColorizer {
  // Light-mode hex colors for each bookmark color.
  static const _lightColors = {
    BookmarkColor.red: '#E53935',
    BookmarkColor.orange: '#FB8C00',
    BookmarkColor.green: '#43A047',
  };
  // Pre-inverted for dark mode (the ColorFilter inverts RGB).
  static const _darkColors = {
    BookmarkColor.red: '#1AC6CA',
    BookmarkColor.orange: '#0473FF',
    BookmarkColor.green: '#BC5FB8',
  };

  static String colorize(
    String svg,
    Map<int, BookmarkColor> colorMap,
    bool isDark,
  ) {
    if (colorMap.isEmpty) return svg;
    final palette = isDark ? _darkColors : _lightColors;

    // Collect all <g> elements that carry ayah:y= (= ayah number markers).
    // Each entry: (start, end, y value).
    final markers = <({int start, int end, double y})>[];
    int searchPos = 0;
    while (true) {
      final idx = svg.indexOf('ayah:y="', searchPos);
      if (idx == -1) break;

      final gStart = svg.lastIndexOf('<g', idx);
      if (gStart == -1) { searchPos = idx + 8; continue; }

      final gEnd = _groupEnd(svg, gStart);
      if (gEnd == -1) { searchPos = idx + 8; continue; }

      final slice = svg.substring(gStart, min(gStart + 300, svg.length));
      final yMatch = RegExp(r'ayah:y="([\d.]+)"').firstMatch(slice);
      final y = yMatch != null ? (double.tryParse(yMatch.group(1)!) ?? 0.0) : 0.0;

      markers.add((start: gStart, end: gEnd, y: y));
      searchPos = gEnd;
    }
    if (markers.isEmpty) return svg;

    // Sort by ayah:y ascending → top of page first (reading order).
    final sorted = List<({int start, int end, double y})>.from(markers)
      ..sort((a, b) => a.y.compareTo(b.y));

    // For each marker to color, also find the decorative shape group right before it.
    // The structure inside <g id="ayah_markers"> is:
    //   <g scale(0.011)>  ← decorative circle
    //   <g ayah:y="...">  ← digit
    // So the shape group ends exactly where the digit group starts.
    final edits = <({int start, int end, String fill})>[];
    for (final entry in colorMap.entries) {
      final i = entry.key;
      if (i >= sorted.length) continue;
      final digitGroup = sorted[i];
      final fillColor = palette[entry.value]!;

      // Recolor the digit group.
      edits.add((start: digitGroup.start, end: digitGroup.end, fill: fillColor));

      // Find the decorative shape group: the <g> sibling that ends right before digitGroup.start.
      final shapeEnd = digitGroup.start;
      final shapeStart = svg.lastIndexOf('</g>', shapeEnd - 1);
      if (shapeStart > 0) {
        final gTag = svg.lastIndexOf('<g', shapeStart);
        if (gTag >= 0) {
          final gEndPos = _groupEnd(svg, gTag);
          if (gEndPos == shapeEnd) {
            // This is the immediate predecessor — it's the decorative circle.
            edits.add((start: gTag, end: shapeEnd, fill: fillColor));
          }
        }
      }
    }

    // Sort descending by start so replacements don't shift indices.
    edits.sort((a, b) => b.start.compareTo(a.start));

    var result = svg;
    for (final e in edits) {
      final original = result.substring(e.start, e.end);
      final colored = original.replaceAll('fill="#231f20"', 'fill="${e.fill}"');
      if (identical(original, colored)) continue;
      result = result.replaceRange(e.start, e.end, colored);
    }
    return result;
  }

  static int _groupEnd(String s, int start) {
    int depth = 0, i = start;
    while (i < s.length) {
      if (s[i] == '<') {
        if (i + 1 < s.length && s[i + 1] == 'g' &&
            (i + 2 >= s.length || s[i + 2] == ' ' || s[i + 2] == '>' || s[i + 2] == '\n' || s[i + 2] == '\r')) {
          depth++; i += 2; continue;
        }
        if (i + 3 < s.length && s[i + 1] == '/' && s[i + 2] == 'g' && s[i + 3] == '>') {
          if (--depth == 0) return i + 4;
          i += 4; continue;
        }
      }
      i++;
    }
    return -1;
  }
}

// ── Ayah highlight painter ────────────────────────────────────────────────────

class _AyahHighlightPainter extends CustomPainter {
  final Ayah ayah;
  final List<Ayah> allAyahs;
  final Size viewBox;
  final double contentTop;
  final double contentBottom;

  const _AyahHighlightPainter({
    required this.ayah,
    required this.allAyahs,
    required this.viewBox,
    required this.contentTop,
    required this.contentBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (allAyahs.isEmpty) return;

    final scale = min(size.width / viewBox.width, size.height / viewBox.height);
    final ox = (size.width - viewBox.width * scale) / 2;
    final oy = (size.height - viewBox.height * scale) / 2;

    final minLine = allAyahs.map((a) => a.lineStart).reduce(min).toDouble();
    final maxLine = allAyahs.map((a) => a.lineEnd).reduce(max).toDouble();
    final lineSpan = maxLine - minLine;
    if (lineSpan == 0) return;

    final contentHeight = contentBottom - contentTop;

    // Map line numbers back to SVG y-coords with half-line padding.
    final topRatio = ((ayah.lineStart - minLine - 0.5) / lineSpan).clamp(0.0, 1.0);
    final bottomRatio = ((ayah.lineEnd - minLine + 0.5) / lineSpan).clamp(0.0, 1.0);
    final svgTop = contentTop + topRatio * contentHeight;
    final svgBottom = contentTop + bottomRatio * contentHeight;

    final left = ox;
    final right = ox + viewBox.width * scale;
    final top = svgTop * scale + oy;
    final bottom = svgBottom * scale + oy;

    final paint = Paint()..color = const Color(0xFFF5B301).withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AyahHighlightPainter old) =>
      old.ayah != ayah || old.allAyahs != allAyahs;
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String surahName;
  final int pageNo;
  final String lang;
  final bool isBookmarked;
  final Color primary;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onClose;

  const _TopBar({
    required this.surahName,
    required this.pageNo,
    required this.lang,
    required this.isBookmarked,
    required this.primary,
    required this.onBookmarkToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppConstants.darkSurface : AppConstants.lightSurface)
            .withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
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
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: isBookmarked ? primary : theme.hintColor,
            ),
            onPressed: onBookmarkToggle,
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

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
        color: (isDark ? AppConstants.darkSurface : AppConstants.lightSurface)
            .withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
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

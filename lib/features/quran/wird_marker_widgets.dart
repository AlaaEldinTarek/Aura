/// Widgets and small helpers for the Wird marker (spec: docs/designs/wird-marker.md,
/// item 9): the palette, the ribbon drawn in the reader, the color grid sheet,
/// the bookmark pick sheet, the undo and restart controls, and the one mapping
/// from an undo result to a message.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

/// The 12 colors a user can give the Wird marker. Each has contrast of at least
/// 3.0 on both page surfaces and is at least 25 CIE76 units away from the three
/// bookmark colors. `wird_marker_palette_test.dart` asserts the rules and this
/// exact list.
const List<Color> kWirdMarkerPalette = [
  Color(0xFF1E88E5),
  Color(0xFF00838F),
  Color(0xFF827717),
  Color(0xFFBA68C8),
  Color(0xFF964EDE),
  Color(0xFFD620D6),
  Color(0xFFDE378B),
  Color(0xFFA17448),
  Color(0xFF5F7A43),
  Color(0xFF4F80B0),
  Color(0xFF607D8B),
  Color(0xFF7272CF),
];

String _digits(int n, String lang) =>
    NumberFormatter.withArabicNumeralsByLanguage(n.toString(), lang);

// ── Ribbon ──────────────────────────────────────────────────────────────────

/// Page the Start/Continue Reading button opens: the marker page when one
/// exists, else the day's progress page, else the start page.
int wirdReadingPage(WirdState state, int? progressPage, int startPage) =>
    state.marker?.markerPage ?? progressPage ?? startPage;

/// First page of the day's range on the Wird tab: the page where today's
/// reading began, else the marker page, else 1.
int wirdRangeStart(WirdState state, int? progressStartPage) =>
    progressStartPage ?? state.marker?.markerPage ?? 1;

/// The ribbon shows only in page mode, on the page the marker is on.
bool shouldShowWirdRibbon({
  required WirdUnit unit,
  required int? markerPage,
  required int currentPage,
}) =>
    unit == WirdUnit.page && markerPage != null && currentPage == markerPage;

/// A small ribbon: outline from the app text color (so it shows in dark mode),
/// fill from the stored marker color.
class WirdMarkerRibbon extends StatelessWidget {
  static const double width = 14;
  static const double height = 30;

  final Color color;
  final int page;

  const WirdMarkerRibbon({super.key, required this.color, required this.page});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Localizations.localeOf(context).languageCode;
    return Semantics(
      label:
          'wird_marker_ribbon_label'.tr().replaceAll('%d', _digits(page, lang)),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _RibbonPainter(
            fill: color,
            outline: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final Color fill;
  final Color outline;

  const _RibbonPainter({required this.fill, required this.outline});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(w / 2, h - 7)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.fill != fill || old.outline != outline;
}

/// Place this as a child of a `Stack`. It draws nothing unless the ribbon
/// should show (see [shouldShowWirdRibbon]). [top] is the measured top bar
/// height while the bar is visible, else 0.
class WirdMarkerRibbonLayer extends StatelessWidget {
  final WirdState state;
  final int currentPage;
  final double top;

  const WirdMarkerRibbonLayer({
    super.key,
    required this.state,
    required this.currentPage,
    required this.top,
  });

  @override
  Widget build(BuildContext context) {
    final marker = state.marker;
    final page = marker?.markerPage;
    if (marker == null ||
        page == null ||
        !shouldShowWirdRibbon(
          unit: state.settings.wirdUnit,
          markerPage: page,
          currentPage: currentPage,
        )) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: top,
      right: 8,
      child: WirdMarkerRibbon(
        color: Color(marker.color ?? kWirdMarkerPalette.first.toARGB32()),
        page: page,
      ),
    );
  }
}

// ── Undo and restart controls ───────────────────────────────────────────────

/// "Undo last move": shown only in page mode while a valid undo record exists.
/// The label is "Connect to undo" while [offline] (signed in and no network).
/// A tap calls [onPressed] in both labels; the button is disabled only while
/// [busy].
class WirdUndoMoveButton extends StatelessWidget {
  final WirdState state;
  final bool offline;
  final bool busy;
  final VoidCallback onPressed;

  const WirdUndoMoveButton({
    super.key,
    required this.state,
    required this.offline,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    if (state.settings.wirdUnit != WirdUnit.page || state.undo == null) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: busy ? null : onPressed,
      icon: const Icon(Icons.undo, size: 18),
      label: Text((offline ? 'wird_undo_connect' : 'wird_undo_last_move').tr()),
    );
  }
}

/// "Restart Wird": shown only in page mode while a marker exists.
class WirdRestartTile extends StatelessWidget {
  final WirdState state;
  final VoidCallback onPressed;

  const WirdRestartTile(
      {super.key, required this.state, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (state.settings.wirdUnit != WirdUnit.page ||
        state.marker?.markerPage == null) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: const Icon(Icons.restart_alt),
      title: Text('wird_restart'.tr()),
      onTap: onPressed,
    );
  }
}

// ── Undo result message ─────────────────────────────────────────────────────

/// The one mapping from an undo result to a string key.
String undoOutcomeMessageKey(UndoOutcome outcome) => switch (outcome) {
      UndoDone() => 'wird_undo_done',
      UndoCloudNewer() => 'wird_undo_cloud_newer',
      UndoNeedsConnection() => 'wird_undo_connect',
      UndoFailed() => 'wird_undo_stale',
    };

/// "Wird marker moved" snackbar with an Undo action. A snackbar with an action
/// stays until dismissed unless `persist` is false, so it is set here. Any
/// earlier snackbar is cleared first, so moves never queue up stale Undo bars.
void showMarkerMovedSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      persist: false,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
    ));
}

/// Shows the message for [outcome]. Used by the reader snackbar action and by
/// both Wird-tab buttons.
void showUndoOutcome(BuildContext context, UndoOutcome outcome) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(undoOutcomeMessageKey(outcome).tr())),
  );
}

// ── Big-move confirmation ───────────────────────────────────────────────────

/// "Count N pages as read?" Returns true only on "Count them".
Future<bool> showBigMoveConfirm(BuildContext context, int pages) async {
  final lang = Localizations.localeOf(context).languageCode;
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('wird_marker_confirm_title'
          .tr()
          .replaceAll('%d', _digits(pages, lang))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('wird_marker_confirm_no'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('wird_marker_confirm_yes'.tr()),
        ),
      ],
    ),
  );
  return yes == true;
}

// ── Color grid sheet ────────────────────────────────────────────────────────

/// 12 swatches. Returns the chosen color, or null on cancel.
class WirdColorGridSheet extends StatelessWidget {
  final Color? selected;

  const WirdColorGridSheet({super.key, this.selected});

  static Future<Color?> show(BuildContext context, {Color? selected}) =>
      showModalBottomSheet<Color>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => WirdColorGridSheet(selected: selected),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('wird_marker_choose_color'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final c in kWirdMarkerPalette)
                  GestureDetector(
                    onTap: () => Navigator.pop(context, c),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected?.toARGB32() == c.toARGB32()
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected?.toARGB32() == c.toARGB32()
                            ? [
                                BoxShadow(
                                    color: c, blurRadius: 4, spreadRadius: 1)
                              ]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bookmark pick sheet ─────────────────────────────────────────────────────

/// One row per page. When several bookmarks share a page, the one with the
/// earliest `createdAt` is used. Rows are sorted by page, ascending.
List<QuranBookmark> bookmarkPickRows(List<QuranBookmark> bookmarks) {
  final byPage = <int, QuranBookmark>{};
  for (final b in bookmarks) {
    final existing = byPage[b.page];
    if (existing == null || b.createdAt.isBefore(existing.createdAt)) {
      byPage[b.page] = b;
    }
  }
  return byPage.values.toList()..sort((a, b) => a.page.compareTo(b.page));
}

/// Lists the user's bookmarks (all colors) so one can become the starting page.
/// Returns the chosen page, or null on cancel. With no bookmarks it shows an
/// empty state with an "Open reader" button that runs [onOpenReader].
class WirdBookmarkPickSheet extends ConsumerWidget {
  final VoidCallback onOpenReader;

  const WirdBookmarkPickSheet({super.key, required this.onOpenReader});

  static Future<int?> show(BuildContext context,
          {required VoidCallback onOpenReader}) =>
      showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => WirdBookmarkPickSheet(onOpenReader: onOpenReader),
      );

  static const _colors = {
    BookmarkColor.red: Color(0xFFE53935),
    BookmarkColor.orange: Color(0xFFFB8C00),
    BookmarkColor.green: Color(0xFF43A047),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode;
    final rows =
        bookmarkPickRows(ref.watch(quranBookmarksProvider).valueOrNull ?? []);
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('wird_marker_choose_start'.tr(),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (rows.isEmpty) ...[
                Text('wird_marker_no_bookmarks'.tr()),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenReader();
                  },
                  icon: const Icon(Icons.menu_book),
                  label: Text('wird_marker_open_reader'.tr()),
                ),
              ] else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final b in rows)
                        ListTile(
                          leading:
                              Icon(Icons.bookmark, color: _colors[b.color]),
                          title:
                              Text('${'page'.tr()} ${_digits(b.page, lang)}'),
                          subtitle:
                              Text(lang == 'ar' ? b.suraNameAr : b.suraNameEn),
                          onTap: () => Navigator.pop(context, b.page),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

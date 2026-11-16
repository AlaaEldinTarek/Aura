import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/wird.dart';
import '../../core/models/wird_marker.dart';
import '../../core/providers/wird_provider.dart';
import '../../core/services/quran_service.dart' show kJuzStartPages;
import '../../core/services/wird_marker_logic.dart'
    show suggestMarkerPageAfterJuz;
import '../../core/utils/number_formatter.dart';
import 'wird_marker_widgets.dart';

/// The warning shown before leaving Juz for Pages (docs/designs/mode-separation.md,
/// "Warning dialog texts"). True only when the user taps Switch.
Future<bool> showWirdModeSwitchDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('wird_mode_switch_title'.tr()),
      content: Text('wird_mode_switch_body'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('wird_mode_switch_confirm'.tr()),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The Page/Juz segment handler (decisions A, F, G).
///
/// * To Juz: switches at once. No dialog, nothing is emptied.
/// * To Pages: the dialog first. Cancel (or dismissing it) changes nothing.
///   Confirm calls [WirdNotifier.switchToPageMode] once, then, if the checked
///   cards give a suggested page and no marker exists, opens the existing
///   "Start your Wird from page N?" sheet. The page changes only through the
///   reader's "Choose another page" (the tab sheet has no such button).
Future<void> changeWirdUnit(
  BuildContext context,
  WidgetRef ref,
  WirdUnit target, {
  required String lang,
}) async {
  final notifier = ref.read(wirdStateProvider.notifier);
  final state = ref.read(wirdStateProvider).valueOrNull;
  if (state == null || state.settings.wirdUnit == target) return;

  if (target == WirdUnit.juz) {
    await notifier.setWirdUnit(WirdUnit.juz);
    return;
  }

  final checked = List<int>.of(state.allCompletedJuz);
  final confirmed = await showWirdModeSwitchDialog(context);
  if (!confirmed || !context.mounted) return;

  await notifier.switchToPageMode();
  if (!context.mounted) return;

  final fresh = ref.read(wirdStateProvider).valueOrNull;
  final page = suggestMarkerPageAfterJuz(
    checked,
    kJuzStartPages,
    existing: fresh?.marker,
  );
  if (page == null) return;

  final choice = await showWirdStartSheetRemembered(
    context,
    ref,
    page: page,
    readingMode: false,
  );
  if (choice is! StartHere || !context.mounted) return;
  final outcome = await notifier.placeMarker(page, choice.color.toARGB32());
  if (!context.mounted) return;
  switch (outcome) {
    case Placed():
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('wird_marker_placed'.tr().replaceAll(
              '%d',
              NumberFormatter.withArabicNumeralsByLanguage(
                  page.toString(), lang))),
          duration: const Duration(seconds: 3),
        ));
    case PlaceFailed(failure: final f):
      debugPrint('⚠️ [WIRD] Marker not placed: $f');
  }
}

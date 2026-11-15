import 'package:flutter/services.dart';

/// The Quran reader turns pages like a book that opens from the right: the
/// next page comes in from the left. Arabic (RTL) already does this through the
/// app's text direction. In English (LTR) the reader reverses its page order
/// to match. Arabic behavior is unchanged.
bool readerReversesPages(TextDirection direction) =>
    direction == TextDirection.ltr;

/// Desktop arrow keys: +1 next page, -1 previous page, null for other keys.
/// Not reversed (Arabic, unchanged): right = next. Reversed (English): left = next.
int? keyPageStep(LogicalKeyboardKey key, {required bool reversed}) {
  if (key == LogicalKeyboardKey.arrowRight) return reversed ? -1 : 1;
  if (key == LogicalKeyboardKey.arrowLeft) return reversed ? 1 : -1;
  return null;
}

/// Desktop mouse drag by [dx] pixels: +1 next page, -1 previous page, null when
/// there is no movement. Not reversed (Arabic, unchanged): drag left = next.
/// Reversed (English): drag right = next.
int? dragPageStep(double dx, {required bool reversed}) {
  if (dx == 0) return null;
  final next = reversed ? dx > 0 : dx < 0;
  return next ? 1 : -1;
}

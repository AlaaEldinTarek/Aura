import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window sizing from the monitor's work area (F63).

/// Today's (and the largest allowed) desktop window size.
const Size kMaxWindowSize = Size(900, 1400);

/// Window size for [workArea] (the monitor's area without the taskbar):
/// 90% of the work height (max 1400); width keeps the app's 900:1400 shape,
/// at least 500 when the work area allows it, at most 900 and 90% of the
/// work width. Unknown work area → [kMaxWindowSize].
Size adaptiveWindowSize(Rect? workArea) {
  if (workArea == null || workArea.isEmpty) return kMaxWindowSize;
  final maxW = workArea.width * 0.9;
  final height = math.min(kMaxWindowSize.height, workArea.height * 0.9);
  final shapeW = height * kMaxWindowSize.width / kMaxWindowSize.height;
  final floorW = math.min(500.0, maxW);
  final width = math.min(
    kMaxWindowSize.width,
    math.min(maxW, math.max(shapeW, floorW)),
  );
  return Size(width, height);
}

/// Desktop item/text scale for a window of [width] × [height] (F63 A-1).
/// The limiting side decides (vertical scroll layout), so a wide or
/// maximized window does not inflate everything: 900 × 1400 → 1.8 (the tuned
/// point, also the cap), 500 × 778 → 1.0, floor 0.9.
double desktopTextScale(double width, double height) =>
    math.min(width / 500.0, height / 778.0).clamp(0.9, 1.8).toDouble();

/// [desiredMin] capped to [window], so a minimum never exceeds the window.
Size fitMinimumSize(Size desiredMin, Size window) => Size(
      math.min(desiredMin.width, window.width),
      math.min(desiredMin.height, window.height),
    );

/// Work area of the monitor under the cursor (fallback: primary), via
/// window_manager's [calcWindowPosition]. Null if it cannot be read.
Future<Rect?> currentWorkArea() async {
  try {
    final topLeft = await calcWindowPosition(Size.zero, Alignment.topLeft);
    final bottomRight =
        await calcWindowPosition(Size.zero, Alignment.bottomRight);
    final rect = Rect.fromPoints(topLeft, bottomRight);
    return rect.isEmpty ? null : rect;
  } catch (e) {
    debugPrint('⚠️ [DESKTOP] Work area unavailable: $e');
    return null;
  }
}

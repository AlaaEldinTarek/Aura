import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/window_size.dart';

// F63: the desktop window is sized from the monitor's work area, never larger
// than 900 x 1400, never wider/taller than 90% of the work area.
void main() {
  Rect area(double w, double h) => Rect.fromLTWH(0, 0, w, h);

  void expectSize(Size actual, double w, double h) {
    expect(actual.width, closeTo(w, 0.1), reason: 'width');
    expect(actual.height, closeTo(h, 0.1), reason: 'height');
  }

  void expectWithinLimits(Size s, Rect a) {
    expect(s.width, lessThanOrEqualTo(900));
    expect(s.height, lessThanOrEqualTo(1400));
    expect(s.width, lessThanOrEqualTo(a.width * 0.9 + 1e-9));
    expect(s.height, lessThanOrEqualTo(a.height * 0.9 + 1e-9));
  }

  group('adaptiveWindowSize', () {
    test('unknown work area -> today\'s 900 x 1400', () {
      expectSize(adaptiveWindowSize(null), 900, 1400);
    });

    test('1080p at 150% (1280 x 672): 500 wide floor', () {
      final a = area(1280, 672);
      final s = adaptiveWindowSize(a);
      expectSize(s, 500, 604.8);
      expectWithinLimits(s, a);
    });

    test('1080p at 100% (1920 x 1032): app shape', () {
      final a = area(1920, 1032);
      final s = adaptiveWindowSize(a);
      expectSize(s, 928.8 * 900 / 1400, 928.8);
      expectWithinLimits(s, a);
    });

    test('1440p at 100% (2560 x 1392)', () {
      final a = area(2560, 1392);
      final s = adaptiveWindowSize(a);
      expectSize(s, 1252.8 * 900 / 1400, 1252.8);
      expectWithinLimits(s, a);
    });

    test('4K at 100% (3840 x 2112): capped at 900 x 1400', () {
      final a = area(3840, 2112);
      final s = adaptiveWindowSize(a);
      expectSize(s, 900, 1400);
      expectWithinLimits(s, a);
    });

    test('narrow work area (520 x 900): floor never exceeds the area', () {
      final a = area(520, 900);
      final s = adaptiveWindowSize(a);
      expectSize(s, 468, 810);
      expectWithinLimits(s, a);
    });

    test('work area offset (second monitor) does not change the size', () {
      expectSize(adaptiveWindowSize(const Rect.fromLTWH(1920, 0, 1280, 672)),
          500, 604.8);
    });
  });

  group('centeredIn', () {
    test('centers in the work area, including a monitor offset', () {
      void expectOffset(Offset o, double x, double y) {
        expect(o.dx, closeTo(x, 0.001));
        expect(o.dy, closeTo(y, 0.001));
      }

      expectOffset(
          centeredIn(
              const Rect.fromLTWH(0, 0, 1280, 672), const Size(500, 604.8)),
          390,
          33.6);
      expectOffset(
          centeredIn(
              const Rect.fromLTWH(1920, 40, 1280, 672), const Size(500, 604.8)),
          2310,
          73.6);
    });
  });

  group('fitMinimumSize', () {
    test('minimum smaller than the window is kept', () {
      expectSize(fitMinimumSize(const Size(400, 600), const Size(500, 604.8)),
          400, 600);
    });

    test('minimum is capped to the window', () {
      expectSize(
          fitMinimumSize(const Size(400, 600), const Size(468, 540)), 400, 540);
    });
  });
}

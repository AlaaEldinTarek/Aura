// Spec: docs/designs/wird-marker.md item 19 and "Color palette".
import 'dart:math' as math;

import 'package:aura_app/features/quran/wird_marker_widgets.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _lightSurface = Color(0xFFFFF8EB);
const _darkSurface = Color(0xFF1E1E1E);
const _references = [
  Color(0xFFE53935), // red
  Color(0xFFFB8C00), // orange
  Color(0xFF43A047), // green
];

/// The 12 values fixed in the spec. Changing one means changing this test and
/// the spec paragraph in the same commit.
const _expected = [
  0xFF1E88E5,
  0xFF00838F,
  0xFF827717,
  0xFFBA68C8,
  0xFF964EDE,
  0xFFD620D6,
  0xFFDE378B,
  0xFFA17448,
  0xFF5F7A43,
  0xFF4F80B0,
  0xFF607D8B,
  0xFF7272CF,
];

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// sRGB -> CIE L*a*b* (D65), then CIE76 distance.
List<double> _lab(Color c) {
  final r = _lin(c.r), g = _lin(c.g), b = _lin(c.b);
  final x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
  final y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b) / 1.0;
  final z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
  double f(double t) => t > 216 / 24389
      ? math.pow(t, 1 / 3).toDouble()
      : (24389 / 27 * t + 16) / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

double _distance(Color a, Color b) {
  final la = _lab(a), lb = _lab(b);
  return math.sqrt(math.pow(la[0] - lb[0], 2) +
      math.pow(la[1] - lb[1], 2) +
      math.pow(la[2] - lb[2], 2));
}

void main() {
  test('there are 12 colors', () {
    expect(kWirdMarkerPalette.length, 12);
  });

  test('no duplicate values', () {
    final values = kWirdMarkerPalette.map((c) => c.toARGB32()).toSet();
    expect(values.length, kWirdMarkerPalette.length);
  });

  test('every color is fully opaque', () {
    for (final c in kWirdMarkerPalette) {
      expect(c.a, 1.0);
    }
  });

  test('every color has contrast >= 3.0 on the light and the dark surface', () {
    for (final c in kWirdMarkerPalette) {
      expect(_contrast(c, _lightSurface), greaterThanOrEqualTo(3.0),
          reason: '${c.toARGB32().toRadixString(16)} on light');
      expect(_contrast(c, _darkSurface), greaterThanOrEqualTo(3.0),
          reason: '${c.toARGB32().toRadixString(16)} on dark');
    }
  });

  test('every color is >= 25 CIE76 units from red, orange and green', () {
    for (final c in kWirdMarkerPalette) {
      for (final ref in _references) {
        expect(_distance(c, ref), greaterThanOrEqualTo(25.0),
            reason:
                '${c.toARGB32().toRadixString(16)} vs ${ref.toARGB32().toRadixString(16)}');
      }
    }
  });

  test('the list equals the 12 values fixed in the spec, in order', () {
    expect(kWirdMarkerPalette.map((c) => c.toARGB32()).toList(), _expected);
  });
}

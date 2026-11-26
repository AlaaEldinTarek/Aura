import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  final src = File('lib/features/onboarding/preference_screen.dart')
      .readAsStringSync();

  test('T1: _Slide and _Feature use key fields, not raw En/Ar fields', () {
    expect(src.contains('titleEn'), isFalse,
        reason: '_Slide should not have titleEn');
    expect(src.contains('titleAr'), isFalse,
        reason: '_Slide should not have titleAr');
    expect(src.contains('subtitleEn'), isFalse,
        reason: '_Slide should not have subtitleEn');
    expect(src.contains('subtitleAr'), isFalse,
        reason: '_Slide should not have subtitleAr');
    expect(src.contains('textEn'), isFalse,
        reason: '_Feature should not have textEn');
    expect(src.contains('textAr'), isFalse,
        reason: '_Feature should not have textAr');
  });

  test('T2: _SlideView does not use inline isAr ternary for slide/feature text', () {
    expect(src.contains('isAr ? slide.'), isFalse,
        reason: 'slide text should go through .tr(), not isAr ternary');
    expect(src.contains('isAr ? f.'), isFalse,
        reason: 'feature text should go through .tr(), not isAr ternary');
  });
}

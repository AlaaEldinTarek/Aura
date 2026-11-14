// In English the Quran reader turns pages like Arabic (next page = swipe
// left to right). Arabic behavior is unchanged.
import 'package:aura_app/features/quran/quran_page_direction.dart';
import 'package:aura_app/features/quran/quran_reader_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpBar(
  WidgetTester t, {
  required TextDirection dir,
  required bool reverseNav,
  required VoidCallback onPrev,
  required VoidCallback onNext,
}) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: dir,
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: QuranReaderBottomBar(
            currentPage: 10,
            totalPages: 604,
            lang: dir == TextDirection.rtl ? 'ar' : 'en',
            reverseNav: reverseNav,
            onGoToPrevious: onPrev,
            onGoToNext: onNext,
          ),
        ),
      ),
    ),
  ));
  await t.pump();
}

void main() {
  group('readerReversesPages', () {
    test('English (LTR) reverses, Arabic (RTL) does not', () {
      expect(readerReversesPages(TextDirection.ltr), isTrue);
      expect(readerReversesPages(TextDirection.rtl), isFalse);
    });
  });

  group('keyPageStep', () {
    test('Arabic (not reversed) keeps right = next, left = previous', () {
      expect(keyPageStep(LogicalKeyboardKey.arrowRight, reversed: false), 1);
      expect(keyPageStep(LogicalKeyboardKey.arrowLeft, reversed: false), -1);
    });
    test('English (reversed): left = next, right = previous', () {
      expect(keyPageStep(LogicalKeyboardKey.arrowLeft, reversed: true), 1);
      expect(keyPageStep(LogicalKeyboardKey.arrowRight, reversed: true), -1);
    });
    test('other keys do nothing', () {
      expect(keyPageStep(LogicalKeyboardKey.arrowUp, reversed: true), isNull);
      expect(keyPageStep(LogicalKeyboardKey.keyA, reversed: false), isNull);
    });
  });

  group('dragPageStep', () {
    test('Arabic (not reversed) keeps drag left = next, drag right = previous', () {
      expect(dragPageStep(-120, reversed: false), 1);
      expect(dragPageStep(120, reversed: false), -1);
    });
    test('English (reversed): drag right = next, drag left = previous', () {
      expect(dragPageStep(120, reversed: true), 1);
      expect(dragPageStep(-120, reversed: true), -1);
    });
    test('no movement does nothing', () {
      expect(dragPageStep(0, reversed: true), isNull);
      expect(dragPageStep(0, reversed: false), isNull);
    });
  });

  group('QuranReaderBottomBar reverseNav', () {
    testWidgets('English reversed: next on the left (back arrow), previous on the right',
        (t) async {
      var prev = 0, next = 0;
      await _pumpBar(t,
          dir: TextDirection.ltr,
          reverseNav: true,
          onPrev: () => prev++,
          onNext: () => next++);
      final left = t.getCenter(find.byIcon(Icons.arrow_back));
      final right = t.getCenter(find.byIcon(Icons.arrow_forward));
      expect(left.dx < right.dx, isTrue);
      await t.tap(find.byIcon(Icons.arrow_back));
      expect([prev, next], [0, 1]);
      await t.tap(find.byIcon(Icons.arrow_forward));
      expect([prev, next], [1, 1]);
    });

    testWidgets('English not reversed (default) keeps previous on the left',
        (t) async {
      var prev = 0, next = 0;
      await _pumpBar(t,
          dir: TextDirection.ltr,
          reverseNav: false,
          onPrev: () => prev++,
          onNext: () => next++);
      await t.tap(find.byIcon(Icons.arrow_back));
      expect([prev, next], [1, 0]);
      final left = t.getCenter(find.byIcon(Icons.arrow_back));
      final right = t.getCenter(find.byIcon(Icons.arrow_forward));
      expect(left.dx < right.dx, isTrue);
    });

    testWidgets('Arabic (RTL, not reversed) is unchanged: previous on the right',
        (t) async {
      var prev = 0, next = 0;
      await _pumpBar(t,
          dir: TextDirection.rtl,
          reverseNav: false,
          onPrev: () => prev++,
          onNext: () => next++);
      final prevPos = t.getCenter(find.byIcon(Icons.arrow_back));
      final nextPos = t.getCenter(find.byIcon(Icons.arrow_forward));
      expect(prevPos.dx > nextPos.dx, isTrue);
      await t.tap(find.byIcon(Icons.arrow_back));
      expect([prev, next], [1, 0]);
    });

    testWidgets('English reversed matches the Arabic layout: next left, previous right',
        (t) async {
      await _pumpBar(t,
          dir: TextDirection.ltr, reverseNav: true, onPrev: () {}, onNext: () {});
      final enNextLeft = t.getCenter(find.byIcon(Icons.arrow_back)).dx;
      await _pumpBar(t,
          dir: TextDirection.rtl, reverseNav: false, onPrev: () {}, onNext: () {});
      final arNextX = t.getCenter(find.byIcon(Icons.arrow_forward)).dx;
      // In Arabic the next button (forward icon) sits on the left half.
      expect(arNextX < 200, isTrue);
      expect(enNextLeft < 200, isTrue);
    });
  });
}

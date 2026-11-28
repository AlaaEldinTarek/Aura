import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text test for F34f (docs/designs/fix-f34f.md).
/// Pins the "sheet already open" guard so the untracked-prayers sheet cannot
/// stack when the cold-start check and a resume check both run.
void main() {
  String src() =>
      File('lib/features/main/main_wrapper_screen.dart').readAsStringSync();

  // Body of a method: from its signature to the next top-level `  void ` /
  // `  Future<` member, good enough for source-order assertions.
  String body(String s, String signature) {
    final start = s.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature must exist');
    final next = RegExp(r'\n  (void|Future<[^>]*>|bool|Widget) \w+')
        .firstMatch(s.substring(start + signature.length));
    final end = next == null ? s.length : start + signature.length + next.start;
    return s.substring(start, end);
  }

  test('T1: _untrackedSheetOpen field is declared', () {
    expect(src(), contains('bool _untrackedSheetOpen = false;'));
  });

  test(
    'T2: _checkUntrackedPrayers guards on _untrackedSheetOpen at entry and '
    'again before showing the sheet',
    () {
      final b = body(src(),
          'Future<void> _checkUntrackedPrayers(List<PrayerTime> prayerTimes)');
      const guard = 'if (_untrackedSheetOpen) return;';
      final first = b.indexOf(guard);
      final second = b.indexOf(guard, first + 1);
      final show = b.indexOf('_showUntrackedPrayersSheet(');
      final inProgressSet = b.indexOf('_untrackedCheckInProgress = true;');
      expect(first, isNot(-1), reason: 'entry guard missing');
      expect(first, lessThan(inProgressSet),
          reason: 'entry guard must run before the in-progress flag is set '
              'so the early return needs no finally reset');
      expect(second, isNot(-1), reason: 'pre-show guard missing');
      expect(second, lessThan(show),
          reason: 'second guard must precede the sheet call');
      expect(b.indexOf('getPrayersForDate('), lessThan(second),
          reason: 'second guard must come after the awaited Firestore read');
    },
  );

  test(
    'T3: _showUntrackedPrayersSheet sets the flag before showModalBottomSheet '
    'and clears it in whenComplete',
    () {
      final b = body(src(),
          'void _showUntrackedPrayersSheet(List<PrayerTime> untrackedPrayers)');
      final set = b.indexOf('_untrackedSheetOpen = true;');
      final show = b.indexOf('showModalBottomSheet(');
      expect(set, isNot(-1), reason: 'flag must be set');
      expect(set, lessThan(show), reason: 'flag must be set before showing');
      expect(b, contains('.whenComplete(() {'));
      expect(b, contains('_untrackedSheetOpen = false;'),
          reason: 'flag must be cleared when the sheet closes');
    },
  );
}

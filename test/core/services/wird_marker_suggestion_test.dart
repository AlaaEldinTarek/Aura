// Spec: docs/designs/mode-separation.md, "Marker suggestion on the way to page
// mode" (rule b, decision G). Pure function, no prefs, no Firebase.
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/services/wird_marker_logic.dart';
import 'package:flutter_test/flutter_test.dart';

// The reader's table (quran_reader_screen.dart `_juzStartPages`).
const _starts = [
  1,
  22,
  42,
  62,
  82,
  102,
  122,
  142,
  162,
  182,
  202,
  222,
  242,
  262,
  282,
  302,
  322,
  342,
  362,
  382,
  402,
  422,
  442,
  462,
  482,
  502,
  522,
  542,
  562,
  582,
];

WirdMarkerRecord _marker({int? markerPage}) => WirdMarkerRecord(
      markerPage: markerPage,
      startPage: 31,
      runningTotal: 0,
      khatmaCount: 0,
      khatmaDates: const [],
      cycle: 0,
      version: 1,
      ownerId: null,
      color: 0xFF1E88E5,
    );

void main() {
  test('no checked cards: no suggestion', () {
    expect(suggestMarkerPageAfterJuz(const [], _starts), isNull);
  });

  test('cards 1 to 3: page 62 (start of juz 4)', () {
    expect(suggestMarkerPageAfterJuz(const [1, 2, 3], _starts), 62);
  });

  test('cards 1 to 4: page 82, the spec example', () {
    expect(suggestMarkerPageAfterJuz(const [1, 2, 3, 4], _starts), 82);
  });

  test('a gap stops the run: 1, 2, 4 gives N = 2, page 42', () {
    expect(suggestMarkerPageAfterJuz(const [1, 2, 4], _starts), 42);
  });

  test('cards 1, 2, 3 and 5: N = 3, page 62', () {
    expect(suggestMarkerPageAfterJuz(const [1, 2, 3, 5], _starts), 62);
  });

  test('juz 1 unchecked: N = 0, no suggestion even with later cards', () {
    expect(suggestMarkerPageAfterJuz(const [2, 3, 4], _starts), isNull);
  });

  test('input order and duplicates do not matter', () {
    expect(suggestMarkerPageAfterJuz(const [3, 1, 2, 2, 1], _starts), 62);
  });

  test('29 checked: page 582 (start of juz 30)', () {
    final c = List<int>.generate(29, (i) => i + 1);
    expect(suggestMarkerPageAfterJuz(c, _starts), 582);
  });

  test('all 30 checked: no suggestion (the khatma path resets the cards)', () {
    final c = List<int>.generate(30, (i) => i + 1);
    expect(suggestMarkerPageAfterJuz(c, _starts), isNull);
  });

  test('a marker already exists: no suggestion (decision G)', () {
    expect(
        suggestMarkerPageAfterJuz(const [1, 2, 3], _starts,
            existing: _marker(markerPage: 200)),
        isNull);
  });

  test('a record with no marker page (after Restart) still suggests', () {
    expect(
        suggestMarkerPageAfterJuz(const [1, 2, 3], _starts,
            existing: _marker(markerPage: null)),
        62);
  });

  test('the suggestion does not change the record it was given', () {
    final r = _marker(markerPage: null);
    suggestMarkerPageAfterJuz(const [1, 2], _starts, existing: r);
    expect(r.markerPage, isNull);
    expect(r.version, 1);
  });

  test('a table that is not 30 long gives no suggestion instead of throwing',
      () {
    expect(suggestMarkerPageAfterJuz(const [1, 2, 3], const [1, 22]), isNull);
  });

  test('out-of-range card numbers are ignored', () {
    expect(suggestMarkerPageAfterJuz(const [0, 1, 2, 31, 99], _starts), 42);
  });
}

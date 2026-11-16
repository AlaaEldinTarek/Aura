// Spec: docs/designs/mode-separation.md, M3 (d): the reader's private juz start
// table is exposed as kJuzStartPages, a pure move. It must equal the page
// table of QuranService.getJuzList (the two tables were never compared before).
import 'package:aura_app/core/services/quran_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kJuzStartPages has 30 entries, ascending, starting at page 1', () {
    expect(kJuzStartPages.length, 30);
    expect(kJuzStartPages.first, 1);
    for (var i = 1; i < 30; i++) {
      expect(kJuzStartPages[i], greaterThan(kJuzStartPages[i - 1]));
    }
  });

  test('kJuzStartPages equals the start pages of QuranService.getJuzList',
      () async {
    final juz = await QuranService.getJuzList();
    expect(juz.map((j) => j.startPage).toList(), kJuzStartPages);
  });
}

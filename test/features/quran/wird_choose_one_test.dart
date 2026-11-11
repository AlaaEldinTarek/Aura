import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:aura_app/features/quran/wird_tab.dart';

void main() {
  const colorPages = {10, 50, 100, 200, 300};

  group('countedPagesAfterChooseOne', () {
    test('1. not linked: baselines every page of the color', () {
      final r = countedPagesAfterChooseOne(
        linkedColor: null,
        existingCounted: {},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: colorPages,
      );
      expect(r.counted, colorPages);
      expect(r.alreadyCounted, isFalse);
    });

    test('2. linked to a different color: replaces the link', () {
      final r = countedPagesAfterChooseOne(
        linkedColor: 'green',
        existingCounted: {7, 8},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: colorPages,
      );
      expect(r.counted, colorPages);
      expect(r.alreadyCounted, isFalse);
    });

    test('3. same color linked: existing plus chosen page', () {
      final r = countedPagesAfterChooseOne(
        linkedColor: 'red',
        existingCounted: {10, 50},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: {10, 50, 100},
      );
      expect(r.counted, {10, 50, 100});
      expect(r.alreadyCounted, isFalse);
    });

    test('4. same color linked, page already counted: guard fires', () {
      final r = countedPagesAfterChooseOne(
        linkedColor: 'red',
        existingCounted: {10, 50, 100},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: {10, 50, 100},
      );
      expect(r.counted, {10, 50, 100});
      expect(r.alreadyCounted, isTrue);
    });

    test('5. already linked: other unsynced bookmarks stay uncounted', () {
      const pages = {10, 50, 100, 200};
      final r = countedPagesAfterChooseOne(
        linkedColor: 'red',
        existingCounted: {10, 50},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: pages,
      );
      expect(r.counted, {10, 50, 100});
      expect(pages.difference(r.counted), {200});
    });

    test('6. not linked, empty color pages: only the chosen page', () {
      final r = countedPagesAfterChooseOne(
        linkedColor: null,
        existingCounted: {},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: {},
      );
      expect(r.counted, {100});
      expect(r.alreadyCounted, isFalse);
    });

    test(
        '7. stale counted set (known limit, pins Risks (a)/(b)): '
        'guard misses and 100 is dropped', () {
      // The stored set already holds 100 and 200, but the helper only sees
      // the stale input {10, 50}. Update this expectation when the stale-set
      // path is fixed.
      final r = countedPagesAfterChooseOne(
        linkedColor: 'red',
        existingCounted: {10, 50},
        chosenColor: 'red',
        chosenPage: 200,
        colorPages: {10, 50, 100, 200},
      );
      expect(r.counted, {10, 50, 200});
      expect(r.alreadyCounted, isFalse);
    });
  });

  group('auto-sync set difference (invariants)', () {
    test('after a first link nothing is left for the auto-sync', () {
      final r = countedPagesAfterChooseOne(
        linkedColor: null,
        existingCounted: {},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: colorPages,
      );
      expect(colorPages.difference(r.counted), isEmpty);
    });

    test('a bookmark added later is the only page left for the auto-sync', () {
      final r = countedPagesAfterChooseOne(
        linkedColor: null,
        existingCounted: {},
        chosenColor: 'red',
        chosenPage: 100,
        colorPages: colorPages,
      );
      expect({...colorPages, 400}.difference(r.counted), {400});
    });

    test('negative control: the OLD rule left four pages for the auto-sync',
        () {
      // Pins the old behavior (counted = {chosen page} only). Not the helper.
      const oldCounted = {100};
      expect(colorPages.difference(oldCounted).length, 4);
    });
  });

  group('WirdService (best effort)', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    Future<int?> pagesRead() async =>
        (await WirdService.instance.getFullState()).todayProgress?.pagesRead;

    test('link with the full set: sync adds only later bookmarks', () async {
      final service = WirdService.instance;
      await service.recordPagesRead(1, 100);
      await service.setLinkedBookmarkColor('red', {10, 50, 100, 200, 300});
      expect(await service.syncBookmarkPages({10, 50, 100, 200, 300}), 0);
      expect(await pagesRead(), 1);
      expect(
        await service.syncBookmarkPages({10, 50, 100, 200, 300, 400}),
        1,
      );
      expect(await pagesRead(), 2);
    });

    test('old behavior control: linking with one page re-counts four',
        () async {
      final service = WirdService.instance;
      await service.recordPagesRead(1, 100);
      await service.setLinkedBookmarkColor('red', {100});
      expect(await service.syncBookmarkPages({10, 50, 100, 200, 300}), 4);
      expect(await pagesRead(), 5);
    });
  });
}

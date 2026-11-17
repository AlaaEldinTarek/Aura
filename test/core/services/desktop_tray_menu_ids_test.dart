import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/desktop_tray_service.dart';
import 'package:tray_manager/tray_manager.dart' show Menu;

/// A tray menu click is matched to an item by id only, and a menu already on
/// screen keeps the ids it was built with. So a rebuild must not change the
/// ids. Spec: docs/designs/tray-quit-fix.md ("T3 result and T2b").
void main() {
  final service = DesktopTrayService.instance;

  Map<String, int> idsByKey(Menu menu) => {
        for (final item in menu.items!)
          if (item.key != null) item.key!: item.id,
      };

  List<String?> keys(Menu menu) => [for (final i in menu.items!) i.key];

  group('DesktopTrayService.buildMenu', () {
    test('two rebuilds keep the same ids for the clickable items', () {
      final first = idsByKey(service.buildMenu(
        nextLabel: 'Next: Asr at 3:16 PM',
        adhanPlaying: false,
      ));
      final second = idsByKey(service.buildMenu(
        nextLabel: 'Next: Maghrib at 5:40 PM',
        adhanPlaying: false,
      ));

      for (final key in ['open', 'test_notif', 'quit']) {
        expect(second[key], first[key], reason: key);
      }
      expect(second['next_prayer'], first['next_prayer']);
    });

    test('ids stay the same when Stop Adhan appears and disappears', () {
      final before =
          idsByKey(service.buildMenu(nextLabel: null, adhanPlaying: false));
      final playing =
          idsByKey(service.buildMenu(nextLabel: null, adhanPlaying: true));
      final after =
          idsByKey(service.buildMenu(nextLabel: null, adhanPlaying: false));
      final playingAgain =
          idsByKey(service.buildMenu(nextLabel: null, adhanPlaying: true));

      for (final key in ['open', 'test_notif', 'quit']) {
        expect(playing[key], before[key], reason: key);
        expect(after[key], before[key], reason: key);
      }
      expect(before.containsKey('stop_adhan'), isFalse);
      expect(playingAgain['stop_adhan'], playing['stop_adhan']);
    });

    test('every item in one menu has its own id, separators included', () {
      final menu = service.buildMenu(nextLabel: null, adhanPlaying: true);
      final ids = [for (final item in menu.items!) item.id];
      expect(ids.toSet().length, ids.length);
    });

    test('items, labels and order are unchanged', () {
      final idle = service.buildMenu(
        nextLabel: 'Next: Asr at 3:16 PM',
        adhanPlaying: false,
      );
      expect(keys(idle), [
        'next_prayer',
        null,
        'open',
        null,
        'test_notif',
        null,
        'quit',
      ]);
      expect([
        for (final i in idle.items!)
          if (i.key != null) i.label
      ], [
        'Next: Asr at 3:16 PM',
        'Open Aura',
        '🔔 Test Notification',
        'Quit',
      ]);
      expect(idle.items!.first.disabled, isTrue);

      final playing = service.buildMenu(nextLabel: null, adhanPlaying: true);
      expect(keys(playing), [
        'next_prayer',
        null,
        'stop_adhan',
        null,
        'open',
        null,
        'test_notif',
        null,
        'quit',
      ]);
      expect(playing.items!.first.label, 'Loading prayer times…');
      expect(playing.items![2].label, '🔇 Stop Adhan');
    });
  });

  group(
      'DesktopTrayService.buildMenu, release build (Test Notification hidden)',
      () {
    test('release-mode menu: exact keys and labels, and no test_notif', () {
      final idle = service.buildMenu(
        nextLabel: 'Next: Asr at 3:16 PM',
        adhanPlaying: false,
        includeTestItem: false,
      );
      expect(keys(idle), [
        'next_prayer',
        null,
        'open',
        null,
        'quit',
      ]);
      expect([
        for (final i in idle.items!)
          if (i.key != null) i.label
      ], [
        'Next: Asr at 3:16 PM',
        'Open Aura',
        'Quit',
      ]);
      expect(keys(idle).contains('test_notif'), isFalse);

      final playing = service.buildMenu(
        nextLabel: null,
        adhanPlaying: true,
        includeTestItem: false,
      );
      expect(keys(playing), [
        'next_prayer',
        null,
        'stop_adhan',
        null,
        'open',
        null,
        'quit',
      ]);
      expect(playing.items![2].label, '🔇 Stop Adhan');
      expect(keys(playing).contains('test_notif'), isFalse);
    });

    test('default: no includeTestItem gives the same keys as kDebugMode', () {
      expect(
        keys(service.buildMenu(nextLabel: null, adhanPlaying: false)),
        keys(service.buildMenu(
          nextLabel: null,
          adhanPlaying: false,
          includeTestItem: kDebugMode,
        )),
      );
    });
  });
}

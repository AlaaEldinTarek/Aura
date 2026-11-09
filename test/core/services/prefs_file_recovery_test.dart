import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/prefs_file_recovery.dart';

// F62: an unreadable Windows prefs file is moved aside before start-up reads
// prefs; anything the plugin can read is left alone.
void main() {
  late Directory dir;
  late File prefs;
  final now = DateTime(2026, 11, 9, 9, 50, 0);
  const backupName = 'shared_preferences.json.unreadable-20261109-095000.bak';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('f62_');
    prefs = File('${dir.path}${Platform.pathSeparator}shared_preferences.json');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  List<String> names() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('healthy file with data is left byte-for-byte unchanged', () async {
    prefs.writeAsStringSync(jsonEncode({
      'flutter.language': 'ar',
      'flutter.first_launch': false,
      'flutter.iqama_minutes': 15,
      'flutter.list': ['a', 'b'],
    }));
    final before = prefs.readAsBytesSync();
    final modified = prefs.lastModifiedSync();

    expect(await backUpUnreadablePrefsFile(dir, now: now), isNull);

    expect(prefs.readAsBytesSync(), before);
    expect(prefs.lastModifiedSync(), modified);
    expect(names(), ['shared_preferences.json']);
  });

  test('1867 zero bytes (device case) is backed up with same bytes', () async {
    final zeros = List<int>.filled(1867, 0);
    prefs.writeAsBytesSync(zeros);

    final backup = await backUpUnreadablePrefsFile(dir, now: now);

    expect(backup, endsWith(backupName));
    expect(prefs.existsSync(), isFalse);
    expect(File(backup!).readAsBytesSync(), zeros);
  });

  test('invalid UTF-8 is backed up', () async {
    prefs.writeAsBytesSync([0xC3, 0x28, 0xFF, 0xFE]);
    expect(
        await backUpUnreadablePrefsFile(dir, now: now), endsWith(backupName));
    expect(prefs.existsSync(), isFalse);
  });

  test('empty file is left alone', () async {
    prefs.writeAsStringSync('');
    expect(await backUpUnreadablePrefsFile(dir, now: now), isNull);
    expect(names(), ['shared_preferences.json']);
  });

  test('valid JSON that is not an object is left alone', () async {
    prefs.writeAsStringSync('[]');
    expect(await backUpUnreadablePrefsFile(dir, now: now), isNull);
    expect(prefs.readAsStringSync(), '[]');
  });

  test('no file: nothing happens', () async {
    expect(await backUpUnreadablePrefsFile(dir, now: now), isNull);
    expect(names(), isEmpty);
  });

  test('existing backup name is not overwritten', () async {
    final old = File('${dir.path}${Platform.pathSeparator}$backupName')
      ..writeAsStringSync('older backup');
    prefs.writeAsStringSync('{not json');

    final backup = await backUpUnreadablePrefsFile(dir, now: now);

    expect(backup,
        endsWith('shared_preferences.json.unreadable-20261109-095000-1.bak'));
    expect(old.readAsStringSync(), 'older backup');
    expect(File(backup!).readAsStringSync(), '{not json');
  });
}

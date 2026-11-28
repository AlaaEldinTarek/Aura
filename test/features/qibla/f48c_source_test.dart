// Source-text test for F48c — no endless spinner without a compass
//
// T1: _initializeCompass returns early (with an error message) on platforms
//     that have no flutter_compass native side, before the location request.
// T2: the compass listener has an onError that shows the same message.
// T3: the new translation key exists in both files, non-empty.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;
  setUpAll(() {
    src = File('lib/features/qibla/qibla_screen.dart').readAsStringSync();
  });

  test('T1: platform guard sits before the location request', () {
    final start = src.indexOf('Future<void> _initializeCompass()');
    expect(start, isNot(-1), reason: '_initializeCompass not found');

    final guard = src.indexOf(
        'if (kIsWeb || !(Platform.isAndroid || Platform.isIOS))', start);
    final location = src.indexOf('getBestLocation()', start);
    expect(guard, isNot(-1), reason: 'platform guard missing');
    expect(location, isNot(-1));
    expect(guard, lessThan(location),
        reason: 'guard must run before the location request');

    final guardBody = src.substring(guard, location);
    expect(guardBody, contains("'qibla_compass_unavailable'.tr()"));
    expect(guardBody, contains('_isLoading = false;'));
    expect(guardBody, contains('return;'));
  });

  test('T2: compass stream has an onError that stops the spinner', () {
    final listen = src.indexOf('FlutterCompass.events?.listen(');
    expect(listen, isNot(-1));
    final onError = src.indexOf('onError:', listen);
    expect(onError, isNot(-1), reason: 'onError missing on the compass listen');
    final tail = src.substring(onError, onError + 300);
    expect(tail, contains("'qibla_compass_unavailable'.tr()"));
    expect(tail, contains('_isLoading = false;'));
  });

  test('T3: translation key exists in en.json and ar.json', () {
    for (final f in ['en', 'ar']) {
      final json = jsonDecode(
              File('assets/translations/$f.json').readAsStringSync())
          as Map<String, dynamic>;
      final v = json['qibla_compass_unavailable'];
      expect(v, isA<String>(), reason: '$f.json missing the key');
      expect((v as String).trim(), isNotEmpty);
    }
  });
}

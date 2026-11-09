import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/app_language.dart';

// F61: EasyLocalization's locale must be set (and awaited) before the
// language provider changes MaterialApp.locale.
void main() {
  late List<String> calls;
  late bool mounted;

  Future<void> setLocale(Locale l) async =>
      calls.add('setLocale(${l.languageCode})');
  Future<void> setLanguage(String c) async => calls.add('setLanguage($c)');

  setUp(() {
    calls = [];
    mounted = true;
  });

  test('setLocale runs before setLanguage', () async {
    await applyAppLanguage('ar',
        setLocale: setLocale,
        setLanguage: setLanguage,
        isMounted: () => mounted);
    expect(calls, ['setLocale(ar)', 'setLanguage(ar)']);
  });

  test('setLanguage waits until setLocale completes', () async {
    final gate = Completer<void>();
    final future = applyAppLanguage(
      'ar',
      setLocale: (l) async {
        calls.add('setLocale(${l.languageCode})');
        await gate.future;
      },
      setLanguage: setLanguage,
      isMounted: () => mounted,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['setLocale(ar)']);

    gate.complete();
    await future;
    expect(calls, ['setLocale(ar)', 'setLanguage(ar)']);
  });

  test('not mounted after setLocale: setLanguage is skipped', () async {
    await applyAppLanguage(
      'ar',
      setLocale: (l) async {
        calls.add('setLocale(${l.languageCode})');
        mounted = false;
      },
      setLanguage: setLanguage,
      isMounted: () => mounted,
    );
    expect(calls, ['setLocale(ar)']);
  });

  test('two switches in a row keep the order', () async {
    await applyAppLanguage('ar',
        setLocale: setLocale,
        setLanguage: setLanguage,
        isMounted: () => mounted);
    await applyAppLanguage('en',
        setLocale: setLocale,
        setLanguage: setLanguage,
        isMounted: () => mounted);
    expect(calls, [
      'setLocale(ar)',
      'setLanguage(ar)',
      'setLocale(en)',
      'setLanguage(en)',
    ]);
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F42b+F42c source', () {
    final provider = File('lib/core/providers/azkar_provider.dart').readAsStringSync();
    final screen = File('lib/features/azkar/azkar_screen.dart').readAsStringSync();

    test('T1 — F42b: checkDate() present in provider', () {
      expect(provider, contains('void checkDate()'));
      expect(provider, contains('state.dateKey == today'));
    });

    test('T2 — F42b: WidgetsBindingObserver wired in screen', () {
      expect(screen, contains('WidgetsBindingObserver'));
      expect(screen, contains('addObserver(this)'));
    });

    test('T3 — F42c: azkar_title.tr() present, inline Arabic title absent', () {
      expect(screen, contains("'azkar_title'.tr()"));
      expect(screen, isNot(contains("'الأذكار'")));
    });
  });
}

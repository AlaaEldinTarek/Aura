import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F41b+F41c source', () {
    final login = File('lib/features/auth/login_screen.dart').readAsStringSync();
    final signup = File('lib/features/auth/signup_screen.dart').readAsStringSync();

    test('T1 — F41b login: Exception prefix stripped', () {
      expect(login, contains("startsWith('Exception: ')"));
    });

    test('T2 — F41b signup: Exception prefix stripped', () {
      expect(signup, contains("startsWith('Exception: ')"));
    });

    test('T3 — F41c: auth_reset_link_hint present, inline Arabic hint absent', () {
      expect(login, contains("'auth_reset_link_hint'.tr()"));
      expect(login, isNot(contains("'سنرسل لك رابط")));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/features/settings/adhan_downloads_screen.dart';

void main() {
  test('every reciter follows the Android file-name rule', () {
    final idPattern = RegExp(r'^[a-z0-9_]+$');
    for (final reciter in availableAdhans) {
      expect(idPattern.hasMatch(reciter.id), isTrue,
          reason: '${reciter.id} does not match [a-z0-9_]+');
      expect(reciter.fileName, 'adhan_${reciter.id}.mp3',
          reason: '${reciter.id} fileName mismatch');
    }
  });
}

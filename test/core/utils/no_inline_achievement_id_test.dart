import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F4 guard: the achievement notification id comes only from `achievementNotificationId`. No inline `7100 +`
/// formula, and the helper itself must not use `String.hashCode` (unstable across Dart SDKs).
void main() {
  test(
      'showAchievementNotification uses the helper, no 7100 formula or hashCode',
      () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run from the project root');
    final offenders = <String>[];
    var usesHelper = false;
    for (final e in libDir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final path = e.path.replaceAll(r'\', '/');
      final code = e
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (RegExp(r'7100\s*\+').hasMatch(code)) {
        offenders.add('$path: 7100 formula');
      }
      if (path.endsWith('achievement_notification_id.dart') &&
          code.contains('hashCode')) {
        offenders.add('$path: uses hashCode');
      }
      if (path.endsWith('notification_service.dart') &&
          code.contains('achievementNotificationId(')) {
        usesHelper = true;
      }
    }
    expect(usesHelper, isTrue,
        reason: 'notification_service must call the helper');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

import 'package:aura_app/core/utils/legacy_digest.dart';
import 'package:flutter_test/flutter_test.dart';

/// T4: the digest (id 4001) is now posted by the native receiver. An alarm that an older build armed through
/// flutter_local_notifications with the same id is cancelled once; nothing is cancelled otherwise, so a digest card that
/// is showing is not removed when the app opens and reschedules.
void main() {
  test('a pending flutter alarm with the digest id is a leftover to cancel', () {
    expect(hasLegacyDigestAlarm([1, 4001, 5100], 4001), isTrue);
  });

  test('no pending flutter alarm with that id: nothing to cancel (keeps the showing card)', () {
    expect(hasLegacyDigestAlarm([], 4001), isFalse);
    expect(hasLegacyDigestAlarm([5100, 5101, 3999], 4001), isFalse);
  });
}

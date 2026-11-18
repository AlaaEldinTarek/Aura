// Spec: docs/designs/fix-prayer-reminder.md (switch = only on/off, tile = lead time).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/providers/preferences_provider.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lead time defaults to 10 and bad stored values read as 10', () async {
    for (final stored in <Object?>[null, 0, -5, 7, 45]) {
      SharedPreferences.setMockInitialValues(
          stored == null ? {} : {'notification_reminder_minutes': stored});
      final c = ProviderContainer();
      c.read(reminderMinutesProvider);
      await _settle();
      expect(c.read(reminderMinutesProvider), 10, reason: '$stored');
      c.dispose();
    }
  });

  test('setMinutes stores one of 5/10/15/30; an unlisted value becomes 10',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    await c.read(reminderMinutesProvider.notifier).setMinutes(15);
    expect(c.read(reminderMinutesProvider), 15);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('notification_reminder_minutes'), 15);
    await c.read(reminderMinutesProvider.notifier).setMinutes(7);
    expect(c.read(reminderMinutesProvider), 10);
    c.dispose();
  });

  test('the switch defaults to on and the lead time is kept while it is off',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    c.read(reminderMasterProvider);
    await _settle();
    expect(c.read(reminderMasterProvider), isTrue);
    await c.read(reminderMinutesProvider.notifier).setMinutes(30);
    await c.read(reminderMasterProvider.notifier).setEnabled(false);
    expect(c.read(reminderMasterProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('prayer_notifications_enabled'), isFalse);
    expect(prefs.getInt('notification_reminder_minutes'), 30);
    expect(c.read(reminderMinutesProvider), 30);
    c.dispose();
  });
}

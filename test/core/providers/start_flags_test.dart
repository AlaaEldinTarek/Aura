import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/providers/preferences_provider.dart';
import 'package:aura_app/core/services/shared_preferences_service.dart';

// F50b: the start flags must report loading until the first prefs read ends,
// so Splash cannot route on a default value.
// One value set per file: SharedPreferencesService caches its instance.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'is_guest': true,
      'first_launch': false,
    });
    await SharedPreferencesService.getInstance();
  });

  test('guestModeProvider is loading, then data(stored value)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(guestModeProvider).isLoading, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(guestModeProvider), const AsyncValue.data(true));
  });

  test('firstLaunchProvider is loading, then data(stored value)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(firstLaunchProvider).isLoading, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(firstLaunchProvider), const AsyncValue.data(false));
  });
}

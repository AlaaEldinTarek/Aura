import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/utils/app_language.dart';

// F61: same wiring as main.dart — MaterialApp.locale follows the app's
// language value, `.tr()` follows EasyLocalization's controller.
class _App extends StatelessWidget {
  final ValueNotifier<String> language;
  const _App(this.language);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: language,
      builder: (context, lang, _) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: Locale(lang),
        home: const _Label(),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label();
  @override
  Widget build(BuildContext context) => Text('home'.tr());
}

Future<BuildContext> _pump(
    WidgetTester tester, ValueNotifier<String> lang) async {
  // Translation assets load with real I/O, outside the fake test clock.
  await tester.runAsync(() async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      useOnlyLangCode: true,
      saveLocale: false,
      child: _App(lang),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pumpAndSettle();
  expect(find.text('Home'), findsOneWidget);
  return tester.element(find.byType(_Label));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('old order (provider first) leaves .tr() one language behind',
      (tester) async {
    final lang = ValueNotifier('en');
    final ctx = await _pump(tester, lang);

    // Settings today: provider first (frames run while setLanguage awaits),
    // then setLocale.
    lang.value = 'ar';
    await tester.pumpAndSettle();
    await tester.runAsync(() => ctx.setLocale(const Locale('ar')));
    await tester.pumpAndSettle();

    // Documents the F61 bug with today's order.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('الرئيسية'), findsNothing);
  });

  testWidgets('applyAppLanguage switches at once, both ways, twice',
      (tester) async {
    final lang = ValueNotifier('en');
    final ctx = await _pump(tester, lang);

    Future<void> switchTo(String code) async {
      await tester.runAsync(() => applyAppLanguage(
            code,
            setLocale: ctx.setLocale,
            setLanguage: (c) async => lang.value = c,
            isMounted: () => ctx.mounted,
          ));
      await tester.pumpAndSettle();
    }

    await switchTo('ar');
    expect(find.text('الرئيسية'), findsOneWidget);
    await switchTo('en');
    expect(find.text('Home'), findsOneWidget);
    await switchTo('ar');
    expect(find.text('الرئيسية'), findsOneWidget);
    await switchTo('en');
    expect(find.text('Home'), findsOneWidget);
  });
}

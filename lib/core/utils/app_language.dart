import 'dart:ui';

/// Changes the app language in the order easy_localization needs (F61).
///
/// `MaterialApp.locale` follows the language provider, and easy_localization's
/// delegate installs whatever translations its controller holds when that
/// locale changes (it never reloads). So [setLocale] (the controller loads the
/// new translations) must finish before [setLanguage] (the provider) runs;
/// otherwise `.tr()` stays one language behind until a restart.
Future<void> applyAppLanguage(
  String code, {
  required Future<void> Function(Locale) setLocale,
  required Future<void> Function(String) setLanguage,
  required bool Function() isMounted,
}) async {
  await setLocale(Locale(code));
  if (!isMounted()) return;
  await setLanguage(code);
}

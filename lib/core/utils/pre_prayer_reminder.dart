import 'number_formatter.dart';

/// Pre-prayer reminder rules shared by the settings tile, the Prayer-screen
/// switch subtitle and the Windows toast. The Kotlin twin is `ReminderLogic`
/// (android/app/src/main/kotlin/com/aura/hala/ReminderLogic.kt); both are
/// tested against the same expected strings.
/// Spec: docs/designs/fix-prayer-reminder.md.
const String kReminderMinutesKey = 'notification_reminder_minutes';
const int kDefaultReminderMinutes = 10;
const List<int> kReminderMinuteOptions = [5, 10, 15, 30];

/// A stored 0, a negative number, an unlisted value or null reads as 10.
int normalizeReminderMinutes(int? value) =>
    value != null && kReminderMinuteOptions.contains(value)
        ? value
        : kDefaultReminderMinutes;

/// Arabic unit for [minutes], chosen by the number (never a single word):
/// 5 and 10 -> "دقائق" (plural), 15 and 30 -> "دقيقة".
String arabicMinuteUnit(int minutes) {
  final n = normalizeReminderMinutes(minutes);
  return n <= 10 ? 'دقائق' : 'دقيقة';
}

String reminderTitle({required bool isArabic}) =>
    isArabic ? 'تذكير بالصلاة' : 'Prayer reminder';

/// "{prayer} in {N} minutes" / "أذان {prayer} بعد {N} {unit}" (Eastern Arabic
/// numerals in Arabic).
String reminderBody({
  required String prayerName,
  required String prayerNameAr,
  required int minutes,
  required bool isArabic,
}) {
  final n = normalizeReminderMinutes(minutes);
  if (!isArabic) return '$prayerName in $n minutes';
  final number = NumberFormatter.withArabicNumerals('$n');
  return 'أذان $prayerNameAr بعد $number ${arabicMinuteUnit(n)}';
}

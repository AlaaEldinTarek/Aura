import 'package:easy_localization/easy_localization.dart';
import 'number_formatter.dart';
import 'pre_prayer_reminder.dart';

/// Tile option label: "10 min" / "١٠ دقائق" / "١٥ دقيقة" (unit chosen by N).
String reminderOptionLabel(int minutes, {required bool isArabic}) {
  final n = normalizeReminderMinutes(minutes);
  final key =
      n <= 10 ? 'pre_prayer_reminder_option' : 'pre_prayer_reminder_option_many';
  return key.tr(args: [isArabic ? NumberFormatter.withArabicNumerals('$n') : '$n']);
}

/// "Reminder Prayer" switch subtitle: "10 minutes before each prayer" /
/// "قبل كل صلاة بـ ١٠ دقائق" (unit chosen by N).
String reminderSwitchSubtitle(int minutes, {required bool isArabic}) {
  final n = normalizeReminderMinutes(minutes);
  final key = n <= 10
      ? 'pre_prayer_reminder_switch_subtitle'
      : 'pre_prayer_reminder_switch_subtitle_many';
  return key.tr(args: [isArabic ? NumberFormatter.withArabicNumerals('$n') : '$n']);
}

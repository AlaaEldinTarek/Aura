import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/services/shared_preferences_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/prayer_alarm_service.dart';
import '../../core/services/platform_channel_service.dart';
import '../../core/widgets/setting_tile.dart';
import '../../core/theme/app_typography.dart';
import 'prayer_calculation_settings_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _silentMode = true;
  int _silentDuration = 20;
  bool _trackingEnabled = true;
  String _dailySummaryTime = '21:00';
  String _calculationMethod = 'MuslimWorldLeague';
  String _asrMadhab = 'Shafi';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = SharedPreferencesService.instance;
    final silent = await prefs.isSilentModeEnabled();
    final duration = await prefs.getSilentModeDuration();
    final tracking = await prefs.isPrayerTrackingEnabled();
    final summaryTime = await prefs.getDailySummaryTime();
    final sp = await SharedPreferences.getInstance();
    final method = sp.getString(AppConstants.keyCalculationMethod) ?? 'MuslimWorldLeague';
    final madhab = sp.getString(AppConstants.keyAsrMadhab) ?? 'Shafi';
    if (mounted) {
      setState(() {
        _silentMode = silent;
        _silentDuration = duration;
        _trackingEnabled = tracking;
        _dailySummaryTime = summaryTime;
        _calculationMethod = method;
        _asrMadhab = madhab;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final notifEnabled = ref.watch(taskNotificationsEnabledProvider).valueOrNull ?? true;
    final reminderMins = ref.watch(taskReminderMinutesProvider).valueOrNull ?? 30;
    final jumuahEnabled = ref.watch(jumuahReminderEnabledProvider);
    final themeStr = ref.watch(themeModeProvider).value ?? 'system';
    final language = ref.watch(languageProvider).value ?? 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الإعدادات' : 'Settings'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Prayer ──────────────────────────────────────────────
                  SettingsSectionHeader(
                    icon: Icons.mosque_outlined,
                    title: isArabic ? 'الصلاة' : 'Prayer',
                  ),
                  SettingsCard(children: [
                    SettingTile(
                      icon: Icons.calculate_outlined,
                      title: isArabic ? 'طريقة الحساب والمذهب' : 'Calculation Method & Madhab',
                      subtitle: '$_calculationMethod · $_asrMadhab',
                      onTap: () => PrayerCalculationSettingsDialog.show(
                        context: context,
                        currentMethod: _calculationMethod,
                        currentMadhab: _asrMadhab,
                        onMethodChanged: (v) async {
                          setState(() => _calculationMethod = v);
                          final sp = await SharedPreferences.getInstance();
                          await sp.setString(AppConstants.keyCalculationMethod, v);
                          await _recalculatePrayerTimes();
                        },
                        onMadhabChanged: (v) async {
                          setState(() => _asrMadhab = v);
                          final sp = await SharedPreferences.getInstance();
                          await sp.setString(AppConstants.keyAsrMadhab, v);
                          await _recalculatePrayerTimes();
                        },
                      ),
                    ),
                    SettingTileSwitch(
                      icon: Icons.volume_off_outlined,
                      iconColor: Colors.purple,
                      title: isArabic ? 'الوضع الصامت عند الأذان' : 'Silent Mode at Adhan',
                      subtitle: isArabic ? 'يُفعّل الاهتزاز تلقائياً عند الأذان' : 'Auto-vibrate at prayer time',
                      value: _silentMode,
                      onChanged: (v) async {
                        setState(() => _silentMode = v);
                        await SharedPreferencesService.instance.setSilentModeEnabled(v);
                      },
                    ),
                    if (_silentMode)
                      SettingTile(
                        icon: Icons.timer_outlined,
                        iconColor: Colors.purple,
                        title: isArabic ? 'مدة الوضع الصامت' : 'Silent Mode Duration',
                        subtitle: isArabic
                            ? '$_silentDuration دقيقة'
                            : '$_silentDuration minutes',
                        onTap: () => _showDurationPicker(context, isArabic, isDark),
                      ),
                    SettingTile(
                      icon: Icons.alarm_outlined,
                      title: isArabic ? 'أوقات الإقامة' : 'Iqama Times',
                      onTap: () => Navigator.of(context).pushNamed('/iqama_settings'),
                    ),
                    SettingTile(
                      icon: Icons.download_outlined,
                      title: isArabic ? 'تنزيل الأذان' : 'Adhan Sounds',
                      onTap: () => Navigator.of(context).pushNamed('/adhan_downloads'),
                    ),
                  ]),

                  // ── Tasks ───────────────────────────────────────────────
                  SettingsSectionHeader(
                    icon: Icons.task_alt_outlined,
                    title: isArabic ? 'المهام' : 'Tasks',
                  ),
                  SettingsCard(children: [
                    SettingTileSwitch(
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.orange,
                      title: isArabic ? 'تذكير المهام' : 'Task Reminders',
                      subtitle: isArabic ? 'إشعار قبل موعد المهمة' : 'Notify before task due time',
                      value: notifEnabled,
                      onChanged: (v) => ref.read(taskNotificationsEnabledProvider.notifier).setEnabled(v),
                    ),
                    if (notifEnabled)
                      SettingTile(
                        icon: Icons.schedule_outlined,
                        iconColor: Colors.orange,
                        title: isArabic ? 'وقت التذكير' : 'Remind Me Before',
                        subtitle: isArabic ? '$reminderMins دقيقة' : '$reminderMins minutes',
                        onTap: () => _showReminderMinsPicker(context, isArabic, isDark, reminderMins),
                      ),
                  ]),

                  // ── Appearance ──────────────────────────────────────────
                  SettingsSectionHeader(
                    icon: Icons.palette_outlined,
                    title: isArabic ? 'المظهر' : 'Appearance',
                  ),
                  SettingsCard(children: [
                    SettingTile(
                      icon: Icons.language_outlined,
                      title: isArabic ? 'اللغة' : 'Language',
                      subtitle: language == 'ar' ? 'العربية' : 'English',
                      onTap: () => _showLanguageDialog(context, isArabic, isDark),
                    ),
                    SettingTile(
                      icon: Icons.dark_mode_outlined,
                      title: isArabic ? 'المظهر' : 'Theme',
                      subtitle: _themeName(themeStr, isArabic),
                      onTap: () => _showThemeDialog(context, isArabic, isDark),
                    ),
                  ]),

                  // ── Notifications ───────────────────────────────────────
                  SettingsSectionHeader(
                    icon: Icons.notifications_outlined,
                    title: isArabic ? 'الإشعارات' : 'Notifications',
                  ),
                  SettingsCard(children: [
                    SettingTile(
                      icon: Icons.mosque_outlined,
                      iconColor: const Color(0xFFD4A017),
                      title: isArabic ? 'تذكير صلاة الجمعة' : "Jumu'ah Reminder",
                      subtitle: isArabic ? 'إشعار قبل حلول وقت الجمعة' : 'Notify before Friday prayer',
                      showChevron: false,
                      trailing: Switch(
                        value: jumuahEnabled,
                        activeColor: AppConstants.getPrimary(isDark),
                        onChanged: (v) async {
                          await ref.read(jumuahReminderEnabledProvider.notifier).setEnabled(v);
                          if (v) {
                            await NotificationService.instance.scheduleJumuahReminder();
                          } else {
                            await NotificationService.instance.cancelJumuahReminder();
                          }
                        },
                      ),
                    ),
                    SettingTileSwitch(
                      icon: Icons.track_changes_outlined,
                      iconColor: Colors.green,
                      title: isArabic ? 'تتبع الصلوات' : 'Prayer Tracking',
                      subtitle: isArabic ? 'سؤال تلقائي بعد كل صلاة' : 'Auto-ask after each prayer',
                      value: _trackingEnabled,
                      onChanged: (v) async {
                        setState(() => _trackingEnabled = v);
                        await SharedPreferencesService.instance.setPrayerTrackingEnabled(v);
                      },
                    ),
                    if (_trackingEnabled)
                      SettingTile(
                        icon: Icons.summarize_outlined,
                        iconColor: Colors.green,
                        title: isArabic ? 'ملخص يومي' : 'Daily Summary',
                        subtitle: _dailySummaryTime,
                        onTap: () => _showTimePicker(context, isArabic),
                      ),
                  ]),

                  // ── Background & Battery ────────────────────────────────
                  if (!kIsWeb && Platform.isAndroid) ...[
                    SettingsSectionHeader(
                      icon: Icons.battery_charging_full_outlined,
                      title: isArabic ? 'الخلفية والبطارية' : 'Background & Battery',
                    ),
                    SettingsCard(children: [
                      SettingTile(
                        icon: Icons.alarm_on_outlined,
                        iconColor: Colors.red,
                        title: isArabic ? 'التنبيهات الدقيقة' : 'Exact Alarms',
                        subtitle: isArabic ? 'مطلوب للأذان في الوقت المحدد' : 'Required for on-time adhan',
                        onTap: () => PlatformChannelService.openExactAlarmSettings(),
                      ),
                      SettingTile(
                        icon: Icons.battery_alert_outlined,
                        iconColor: Colors.orange,
                        title: isArabic ? 'تحسين البطارية' : 'Battery Optimization',
                        subtitle: isArabic ? 'تعطيل لضمان الإشعارات في الخلفية' : 'Disable for reliable background alerts',
                        onTap: () => PlatformChannelService.openBatteryOptimizationSettings(),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
    );
  }

  /// Recalculate prayer times after method/madhab change so the change
  /// takes effect immediately (provider re-reads the saved prefs).
  Future<void> _recalculatePrayerTimes() async {
    try {
      await ref.read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now());
    } catch (e) {
      debugPrint('Settings: prayer recalc failed — $e');
    }
  }

  String _themeName(String mode, bool isArabic) {
    switch (mode) {
      case 'dark':   return isArabic ? 'داكن' : 'Dark';
      case 'light':  return isArabic ? 'فاتح' : 'Light';
      default:       return isArabic ? 'تلقائي' : 'System';
    }
  }

  void _showDurationPicker(BuildContext context, bool isArabic, bool isDark) {
    final options = [10, 15, 20, 30, 45, 60];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'مدة الوضع الصامت' : 'Silent Mode Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((mins) => RadioListTile<int>(
            value: mins,
            groupValue: _silentDuration,
            title: Text(isArabic ? '$mins دقيقة' : '$mins minutes'),
            activeColor: AppConstants.getPrimary(isDark),
            onChanged: (v) async {
              if (v != null) {
                setState(() => _silentDuration = v);
                await SharedPreferencesService.instance.setSilentModeDuration(v);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showReminderMinsPicker(BuildContext context, bool isArabic, bool isDark, int current) {
    final options = [5, 10, 15, 30, 45, 60];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'وقت التذكير' : 'Remind Me Before'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((mins) => RadioListTile<int>(
            value: mins,
            groupValue: current,
            title: Text(isArabic ? '$mins دقيقة' : '$mins minutes'),
            activeColor: AppConstants.getPrimary(isDark),
            onChanged: (v) async {
              if (v != null) {
                await ref.read(taskReminderMinutesProvider.notifier).setMinutes(v);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, bool isArabic, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'اللغة' : 'Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'en',
              groupValue: ref.read(languageProvider).value ?? 'en',
              title: const Text('English'),
              activeColor: AppConstants.getPrimary(isDark),
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(languageProvider.notifier).setLanguage(v);
                  if (ctx.mounted) { Navigator.pop(ctx); ctx.setLocale(const Locale('en')); }
                }
              },
            ),
            RadioListTile<String>(
              value: 'ar',
              groupValue: ref.read(languageProvider).value ?? 'en',
              title: const Text('العربية'),
              activeColor: AppConstants.getPrimary(isDark),
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(languageProvider.notifier).setLanguage(v);
                  if (ctx.mounted) { Navigator.pop(ctx); ctx.setLocale(const Locale('ar')); }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, bool isArabic, bool isDark) {
    final options = [
      ('system', isArabic ? 'تلقائي' : 'System'),
      ('light',  isArabic ? 'فاتح' : 'Light'),
      ('dark',   isArabic ? 'داكن' : 'Dark'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'المظهر' : 'Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) => RadioListTile<String>(
            value: opt.$1,
            groupValue: ref.read(themeModeProvider).value ?? 'system',
            title: Text(opt.$2),
            activeColor: AppConstants.getPrimary(isDark),
            onChanged: (v) async {
              if (v != null) {
                await ref.read(themeModeProvider.notifier).setThemeMode(v);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _showTimePicker(BuildContext context, bool isArabic) async {
    final parts = _dailySummaryTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 21,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => _dailySummaryTime = timeStr);
      await SharedPreferencesService.instance.setDailySummaryTime(timeStr);
      await PrayerAlarmService.instance.scheduleDailySummary(timeStr);
    }
  }
}

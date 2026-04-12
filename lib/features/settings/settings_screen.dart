import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/widgets/setting_tile.dart';
import '../../core/utils/haptic_feedback.dart';
import '../../core/providers/background_service_provider.dart';
import '../../core/services/background_service_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _notificationMinutes = 10;

  @override
  void initState() {
    super.initState();
    _loadNotificationMinutes();
  }

  Future<void> _loadNotificationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationMinutes = prefs.getInt(AppConstants.keyNotificationReminderMinutes) ?? 10;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الإعدادات' : 'Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppConstants.paddingMedium),

            // Background Service Section
            SettingsSectionHeader(
              icon: Icons.phone_android,
              title: isArabic ? 'العمل في الخلفية' : 'Background Service',
            ),
            SettingsCard(
              title: isArabic ? 'خدمة الخلفية' : 'Keep App Running',
              subtitle: isArabic
                  ? 'يحافظ التطبيق على العمل حتى عند إغلاقه للحصول على تنبيهات الصلاة'
                  : 'Keeps app running in background for prayer alerts',
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final isRunning = ref.watch(foregroundServiceRunningProvider);

                    return SettingTileSwitch(
                      icon: Icons.notifications_active,
                      title: isArabic ? 'تفعيل العمل في الخلفية' : 'Enable Background Service',
                      subtitle: isArabic
                          ? 'يظهر إشعارًا مستمرًا للحفاظ على التطبيق نشطًا'
                          : 'Shows persistent notification to keep app alive',
                      value: isRunning,
                      onChanged: (value) async {
                        await HapticFeedback.toggle();
                        if (value) {
                          await ref.read(backgroundServiceProvider).startForegroundService();
                          ref.read(foregroundServiceRunningProvider.notifier).state = true;
                        } else {
                          await ref.read(backgroundServiceProvider).stopForegroundService();
                          ref.read(foregroundServiceRunningProvider.notifier).state = false;
                        }
                      },
                      iconColor: AppConstants.primaryColor,
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            // Notifications Section
            SettingsSectionHeader(
              icon: Icons.notifications_outlined,
              title: isArabic ? 'الإشعارات' : 'Notifications',
            ),
            SettingsCard(
              children: [
                // Enable Notifications
                SettingTile(
                  icon: Icons.notification_important_outlined,
                  title: isArabic ? 'إشعارات الصلاة' : 'Prayer Notifications',
                  subtitle: isArabic ? 'تنبيه قبل موعد الصلاة' : 'Notify before prayer time',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      HapticFeedback.toggle();
                    },
                  ),
                ),
                // Notification Time
                SettingTile(
                  icon: Icons.schedule_outlined,
                  title: isArabic ? 'وقت التنبيه' : 'Notification Time',
                  subtitle: isArabic
                      ? '$_notificationMinutes دقائق قبل الصلاة'
                      : '$_notificationMinutes minutes before prayer',
                  trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                  onTap: () => _showNotificationTimeDialog(context, ref, isArabic),
                ),
              ],
            ),

            // Bottom padding for nav bar
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showNotificationTimeDialog(BuildContext context, WidgetRef ref, bool isArabic) {
    final times = ['5', '10', '15', '20'];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'وقت التنبيه' : 'Notification Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: times.map((time) => ListTile(
            title: Text(isArabic ? '$time دقائق' : '$time minutes'),
            trailing: '$_notificationMinutes' == time
                ? const Icon(Icons.check, color: AppConstants.primaryColor)
                : null,
            onTap: () async {
              HapticFeedback.toggle();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(AppConstants.keyNotificationReminderMinutes, int.parse(time));
              if (mounted) {
                setState(() {
                  _notificationMinutes = int.parse(time);
                });
              }
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, bool isArabic) {
    final themeModeAsync = ref.read(themeModeProvider);
    final currentTheme = themeModeAsync.value ?? 'system';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'المظهر' : 'Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text(isArabic ? 'وضع فاتح' : 'Light Mode'),
              trailing: currentTheme == 'light'
                  ? const Icon(Icons.check, color: AppConstants.primaryColor)
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode('light');
                HapticFeedback.toggle();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(isArabic ? 'وضع داكن' : 'Dark Mode'),
              trailing: currentTheme == 'dark'
                  ? const Icon(Icons.check, color: AppConstants.primaryColor)
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode('dark');
                HapticFeedback.toggle();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text(isArabic ? 'النظام' : 'System'),
              trailing: currentTheme == 'system'
                  ? const Icon(Icons.check, color: AppConstants.primaryColor)
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode('system');
                HapticFeedback.toggle();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, bool isArabic) {
    final languageAsync = ref.read(languageProvider);
    final currentLanguage = languageAsync.value ?? 'en';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'اللغة' : 'Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 32)),
              title: const Text('English'),
              trailing: currentLanguage == 'en'
                  ? const Icon(Icons.check, color: AppConstants.primaryColor)
                  : null,
              onTap: () {
                ref.read(languageProvider.notifier).setLanguage('en');
                HapticFeedback.toggle();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Text('🇸🇦', style: TextStyle(fontSize: 32)),
              title: const Text('العربية'),
              trailing: currentLanguage == 'ar'
                  ? const Icon(Icons.check, color: AppConstants.primaryColor)
                  : null,
              onTap: () {
                ref.read(languageProvider.notifier).setLanguage('ar');
                HapticFeedback.toggle();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

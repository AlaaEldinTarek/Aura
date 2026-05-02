import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/utils/haptic_feedback.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/models/achievement.dart';
import '../../core/models/prayer_record.dart';
import '../../core/providers/task_provider.dart';

import '../../core/widgets/setting_tile.dart';
import '../../core/services/notification_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return _buildLoginPrompt(context, isDark, isArabic);
        }
        return _buildProfileContent(context, ref, user, isDark, isArabic);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text('profile'.tr()),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(
          title: Text('profile'.tr()),
        ),
        body: Center(
          child: Text('error_loading_profile'.tr()),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context, bool isDark, bool isArabic) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الملف الشخصي' : 'Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 100,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              'login_required'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'login_required_desc'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppConstants.darkTextSecondary
                        : AppConstants.lightTextSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingXLarge),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: const Icon(Icons.login),
              label: Text('login'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.getPrimary(isDark),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingXLarge,
                  vertical: AppConstants.paddingMedium,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    User user,
    bool isDark,
    bool isArabic,
  ) {
    final themeModeAsync = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الملف الشخصي' : 'Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppConstants.paddingMedium),

            // Profile Header Card
            _buildProfileHeader(context, user, isDark, isArabic)
                .animate().fadeIn(duration: 400.ms),

            const SizedBox(height: AppConstants.paddingMedium),

            // Prayer Stats Summary
            _buildPrayerStatsSummary(context, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingMedium),

            // Task Stats Summary
            _buildTaskStatsSummary(context, ref, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingMedium),

            // Account Section
            SettingsSectionHeader(
              icon: Icons.person_outline,
              title: isArabic ? 'الحساب' : 'Account',
            ),
            SettingsCard(
              children: [
                SettingTile(
                  icon: Icons.email_outlined,
                  title: user.email ?? '',
                  subtitle: isArabic ? 'البريد الإلكتروني' : 'Email',
                ),
                SettingTile(
                  icon: Icons.person_outline,
                  title: user.displayName ?? (isArabic ? 'اسم المستخدم' : 'Display Name'),
                  subtitle: isArabic ? 'الاسم المعروض' : 'Display Name',
                ),
                SettingTile(
                  icon: Icons.edit_outlined,
                  title: isArabic ? 'تعديل الاسم' : 'Edit Display Name',
                  subtitle: isArabic ? 'تغيير اسمك المعروض' : 'Change your display name',
                  trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                  onTap: () => _showEditNameDialog(context, ref, user, isArabic),
                ),
                SettingTile(
                  icon: Icons.password,
                  title: isArabic ? 'تغيير كلمة المرور' : 'Change Password',
                  subtitle: isArabic ? 'تحديث كلمة المرور' : 'Update your password',
                  trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                  onTap: () => _showChangePasswordDialog(context, ref, isArabic),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // App Mode Section
            SettingsSectionHeader(
              icon: Icons.tune,
              title: isArabic ? 'وضع التطبيق' : 'App Mode',
            ),
            SettingsCard(
              children: [
                _AppModeTiles(isDark: isDark, isArabic: isArabic),
              ],
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            // Achievements Section
            SettingsSectionHeader(
              icon: Icons.emoji_events,
              title: isArabic ? 'الإنجازات' : 'Achievements',
            ),
            _AchievementsBadgeGrid(isDark: isDark, isArabic: isArabic),
            const SizedBox(height: AppConstants.paddingLarge),

            // App Settings Section
            SettingsSectionHeader(
              icon: Icons.tune_outlined,
              title: isArabic ? 'إعدادات التطبيق' : 'App Settings',
            ),
            SettingsCard(
              children: [
                // Language Setting
                SettingTile(
                  icon: Icons.language_outlined,
                  title: isArabic ? 'اللغة' : 'Language',
                  subtitle: isArabic ? 'العربية' : 'English',
                  trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                  onTap: () => _showLanguageDialog(context, ref, isArabic),
                ),
                // Theme Setting
                SettingTile(
                  icon: Icons.dark_mode_outlined,
                  title: isArabic ? 'المظهر' : 'Theme',
                  subtitle: _getThemeModeText(themeModeAsync, isArabic),
                  trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                  onTap: () => _showThemeDialog(context, ref, isArabic),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // Prayer Notifications Section
            SettingsSectionHeader(
              icon: Icons.notifications_outlined,
              title: isArabic ? 'الإشعارات' : 'Notifications',
            ),
            SettingsCard(
              children: [
                _JumuahReminderTile(isDark: isDark, isArabic: isArabic),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // About Section
            SettingsSectionHeader(
              icon: Icons.info_outline,
              title: isArabic ? 'حول التطبيق' : 'About',
            ),
            SettingsCard(
              children: [
                SettingTile(
                  icon: Icons.info_outline,
                  title: isArabic ? 'الإصدار' : 'Version',
                  subtitle: '1.0.0',
                ),
                SettingTile(
                  icon: Icons.code,
                  title: isArabic ? 'المطور' : 'Developer',
                  subtitle: 'Aura Team',
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context, ref, isArabic),
                  icon: const Icon(Icons.logout),
                  label: Text('logout'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.error.withOpacity(0.1),
                    foregroundColor: AppConstants.error,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom padding for nav bar
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    User user,
    bool isDark,
    bool isArabic,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge, vertical: AppConstants.paddingXLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppConstants.getPrimary(isDark).withOpacity(0.15),
                  AppConstants.accentCyan.withOpacity(0.1),
                ]
              : [
                  AppConstants.getPrimary(isDark).withOpacity(0.05),
                  AppConstants.accentCyan.withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        border: Border.all(
          color: AppConstants.getPrimary(isDark).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.getPrimary(isDark),
                  AppConstants.accentCyan,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppConstants.getPrimary(isDark).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: user.photoURL != null
                  ? ClipOval(
                      child: Image.network(
                        user.photoURL!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            (user.displayName ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      (user.displayName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppConstants.paddingLarge),

          // Name and Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  user.displayName ?? (isArabic ? 'مستخدم' : 'User'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppConstants.getPrimary(isDark),
                      ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 4),

                // Email
                if (user.email != null)
                  Text(
                    user.email!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : AppConstants.lightTextSecondary,
                        ),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeText(AsyncValue<String> themeModeAsync, bool isArabic) {
    final themeMode = themeModeAsync.value ?? 'system';
    switch (themeMode) {
      case 'light':
        return isArabic ? 'فاتح' : 'Light';
      case 'dark':
        return isArabic ? 'داكن' : 'Dark';
      default:
        return isArabic ? 'النظام' : 'System';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  ? Icon(Icons.check, color: AppConstants.getPrimary(isDark))
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode('light');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(isArabic ? 'وضع داكن' : 'Dark Mode'),
              trailing: currentTheme == 'dark'
                  ? Icon(Icons.check, color: AppConstants.getPrimary(isDark))
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode('dark');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text(isArabic ? 'النظام' : 'System'),
              trailing: currentTheme == 'system'
                  ? Icon(Icons.check, color: AppConstants.getPrimary(isDark))
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode('system');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(isArabic ? 'أسود AMOLED' : 'AMOLED Black'),
              trailing: currentTheme == 'amoled'
                  ? Icon(Icons.check, color: AppConstants.getPrimary(isDark))
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode('amoled');
                Navigator.of(context).pop();
              },
            ),
            const Divider(),
            Consumer(builder: (context, ref, _) {
              final dynamicEnabled = ref.watch(dynamicColorProvider).valueOrNull ?? false;
              return SwitchListTile(
                secondary: const Icon(Icons.palette),
                title: Text(isArabic ? 'ألوان النظام (Material You)' : 'System Colors (Material You)'),
                subtitle: Text(
                  isArabic ? 'استخدام ألوان الخلفية' : 'Use wallpaper-based colors',
                  style: TextStyle(fontSize: 12, color: isArabic ? Colors.grey : Colors.grey[600]),
                ),
                value: dynamicEnabled,
                onChanged: (value) {
                  ref.read(dynamicColorProvider.notifier).setDynamicColor(value);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerStatsSummary(BuildContext context, bool isDark, bool isArabic) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadProfileStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final streak = snapshot.data?['streak'] ?? 0;
        final completionRate = snapshot.data?['completionRate'] ?? 0.0;
        final totalPrayers = snapshot.data?['totalPrayers'] ?? 0;
        final achievementCount = snapshot.data?['achievementCount'] ?? 0;

        // Show -- until user has at least 1 recorded prayer
        final completionValue = totalPrayers > 0
            ? '${(completionRate * 100).round()}%'
            : '--';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
          child: Row(
            children: [
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.local_fire_department,
                  value: NumberFormatter.withArabicNumeralsByLanguage('$streak', isArabic ? 'ar' : 'en'),
                  label: isArabic ? 'التتابع' : 'Streak',
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.mosque_outlined,
                  value: NumberFormatter.withArabicNumeralsByLanguage('$totalPrayers', isArabic ? 'ar' : 'en'),
                  label: isArabic ? 'الصلوات' : 'Prayers',
                  color: AppConstants.getPrimary(isDark),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.check_circle,
                  value: completionValue,
                  label: isArabic ? 'الإتمام' : 'Completion',
                  color: totalPrayers > 0 ? Colors.green : Colors.grey,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.emoji_events,
                  value: NumberFormatter.withArabicNumeralsByLanguage('$achievementCount', isArabic ? 'ar' : 'en'),
                  label: isArabic ? 'الأوسمة' : 'Badges',
                  color: Colors.purple,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskStatsSummary(BuildContext context, WidgetRef ref, bool isDark, bool isArabic) {
    final statsAsync = ref.watch(taskStatisticsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.total == 0) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
              child: Text(
                isArabic ? 'المهام' : 'Tasks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
              child: Row(
                children: [
                  Expanded(
                    child: _ProfileStatCard(
                      icon: Icons.today,
                      value: NumberFormatter.withArabicNumeralsByLanguage(
                          '${stats.dueToday}', isArabic ? 'ar' : 'en'),
                      label: isArabic ? 'اليوم' : 'Today',
                      color: AppConstants.getPrimary(isDark),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProfileStatCard(
                      icon: Icons.task_alt,
                      value: NumberFormatter.withArabicNumeralsByLanguage(
                          '${stats.completed}', isArabic ? 'ar' : 'en'),
                      label: isArabic ? 'مكتملة' : 'Done',
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProfileStatCard(
                      icon: Icons.pending_actions,
                      value: NumberFormatter.withArabicNumeralsByLanguage(
                          '${stats.pending}', isArabic ? 'ar' : 'en'),
                      label: isArabic ? 'معلقة' : 'Pending',
                      color: Colors.orange,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadProfileStats() async {
    try {
      final userId = getCurrentUserId();
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final stats = await PrayerTrackingService.instance.getStatistics(
        userId: userId,
        startDate: thirtyDaysAgo,
        endDate: now,
      );
      final streak = await PrayerTrackingService.instance.calculateCurrentStreak(userId: userId);
      final achievementCount = await AchievementService.instance.getEarnedCount(userId: userId);

      final totalPrayers = stats.completedOnTime + stats.completedLate;

      // True completion rate = recorded completed / expected total (30 days × 5 prayers).
      // Unrecorded prayers count as not completed so the % is honest.
      const expectedPerDay = 5;
      const days = 30;
      const expectedTotal = days * expectedPerDay;
      final trueRate = totalPrayers / expectedTotal;

      return {
        'streak': streak,
        'completionRate': trueRate.clamp(0.0, 1.0),
        'totalPrayers': totalPrayers,
        'achievementCount': achievementCount,
      };
    } catch (_) {
      return {'streak': 0, 'completionRate': 0.0, 'totalPrayers': 0, 'achievementCount': 0};
    }
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, User user, bool isArabic) {
    final controller = TextEditingController(text: user.displayName ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تعديل الاسم' : 'Edit Display Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isArabic ? 'أدخل اسمك' : 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await user.updateDisplayName(newName);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isArabic ? 'خطأ: $e' : 'Error: $e'), backgroundColor: AppConstants.error),
                    );
                  }
                }
              }
            },
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref, bool isArabic) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تغيير كلمة المرور' : 'Change Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isArabic ? 'كلمة المرور الجديدة' : 'New password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newPass = controller.text.trim();
              if (newPass.length >= 6) {
                try {
                  await FirebaseAuth.instance.currentUser?.updatePassword(newPass);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'تم تغيير كلمة المرور' : 'Password updated'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isArabic ? 'خطأ: $e' : 'Error: $e'), backgroundColor: AppConstants.error),
                    );
                  }
                }
              }
            },
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  ? Icon(Icons.check, color: AppConstants.getPrimary(isDark))
                  : null,
              onTap: () {
                ref.read(languageProvider.notifier).setLanguage('en');
                context.setLocale(const Locale('en'));
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Text('🇸🇦', style: TextStyle(fontSize: 32)),
              title: const Text('العربية'),
              trailing: currentLanguage == 'ar'
                  ? Icon(Icons.check, color: AppConstants.getPrimary(isDark))
                  : null,
              onTap: () {
                ref.read(languageProvider.notifier).setLanguage('ar');
                context.setLocale(const Locale('ar'));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref, bool isArabic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('logout'.tr()),
        content: Text('logout_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'logout'.tr(),
              style: const TextStyle(color: AppConstants.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
        await ref.read(authStateNotifierProvider.notifier).signOut();
    }
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _JumuahReminderTile extends ConsumerWidget {
  final bool isDark;
  final bool isArabic;
  const _JumuahReminderTile({required this.isDark, required this.isArabic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(jumuahReminderEnabledProvider);

    return SettingTile(
      icon: Icons.mosque_outlined,
      iconColor: const Color(0xFFD4A017),
      title: isArabic ? 'تذكير صلاة الجمعة' : "Jumu'ah Reminder",
      subtitle: isArabic ? 'إشعار قبل حلول وقت صلاة الجمعة' : 'Get notified before Friday prayer',
      showChevron: false,
      trailing: Switch(
        value: enabled,
        activeThumbColor: AppConstants.getPrimary(isDark),
        onChanged: (value) async {
          await ref.read(jumuahReminderEnabledProvider.notifier).setEnabled(value);
          if (value) {
            await NotificationService.instance.scheduleJumuahReminder();
          } else {
            await NotificationService.instance.cancelJumuahReminder();
          }
        },
      ),
    );
  }
}

class _AppModeTiles extends ConsumerWidget {
  final bool isDark;
  final bool isArabic;
  const _AppModeTiles({required this.isDark, required this.isArabic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeProvider);

    final modes = [
      (AppMode.both, Icons.apps, isArabic ? 'الكل' : 'Full App', isArabic ? 'الصلاة والمهام' : 'Prayer & Tasks'),
      (AppMode.prayerOnly, Icons.mosque, isArabic ? 'الصلاة فقط' : 'Prayer Only', isArabic ? 'أوقات الصلاة والأذان' : 'Prayer times & Adhan'),
      (AppMode.tasksOnly, Icons.task_alt, isArabic ? 'المهام فقط' : 'Tasks Only', isArabic ? 'إدارة المهام' : 'Task management'),
    ];

    return Column(
      children: modes.map((item) {
        final (mode, icon, label, subtitle) = item;
        final isSelected = currentMode == mode;
        return SettingTile(
          icon: icon,
          title: label,
          subtitle: subtitle,
          iconColor: isSelected ? AppConstants.getPrimary(isDark) : null,
          trailing: isSelected
              ? Icon(Icons.check_circle, color: AppConstants.getPrimary(isDark), size: 20)
              : null,
          showChevron: false,
          onTap: () => ref.read(appModeProvider.notifier).setMode(mode),
        );
      }).toList(),
    );
  }
}

class _AchievementsBadgeGrid extends StatefulWidget {
  final bool isDark;
  final bool isArabic;
  const _AchievementsBadgeGrid({required this.isDark, required this.isArabic});

  @override
  State<_AchievementsBadgeGrid> createState() => _AchievementsBadgeGridState();
}

class _AchievementsBadgeGridState extends State<_AchievementsBadgeGrid> {
  late Future<List<Achievement>> _future;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final userId = getCurrentUserId();
    _future = AchievementService.instance
        .checkAndAward(userId: userId)
        .then((_) => AchievementService.instance.getEarnedAchievements(userId: userId))
        .catchError((_) => AchievementService.instance.getEarnedAchievements(userId: userId));
  }

  Widget _buildBadge(Achievement achievement, bool isEarned, Color primary, bool isDark, bool isArabic) {
    final isTask = achievement.category == AchievementCategory.tasks;
    return Tooltip(
      message: isArabic ? achievement.nameAr : achievement.nameEn,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isEarned
              ? primary.withOpacity(isTask ? 0.15 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isEarned
                ? primary.withOpacity(isTask ? 0.6 : 0.35)
                : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
            width: isEarned && isTask ? 2 : 1,
          ),
        ),
        child: Center(
          child: Opacity(
            opacity: isEarned ? 1.0 : 0.25,
            child: Text(achievement.iconEmoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isArabic = widget.isArabic;
    final primary = AppConstants.getPrimary(isDark);
    final all = AchievementDefinitions.all;

    return FutureBuilder<List<Achievement>>(
      future: _future,
      builder: (context, snapshot) {
        final earned = snapshot.data ?? [];
        final earnedIds = earned.map((a) => a.id).toSet();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          ),
          child: Column(
            children: [
              // Badge grid — collapses to 2 rows
              LayoutBuilder(
                builder: (context, constraints) {
                  const itemSize = 52.0;
                  const spacing = 10.0;
                  final innerWidth = constraints.maxWidth - AppConstants.paddingMedium * 2;
                  final perRow = ((innerWidth + spacing) / (itemSize + spacing)).floor().clamp(1, 100);
                  final maxCollapsed = perRow * 2;
                  final hasMore = all.length > maxCollapsed;
                  final visibleItems = _isExpanded ? all : all.take(maxCollapsed).toList();

                  return Column(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Padding(
                          padding: const EdgeInsets.all(AppConstants.paddingMedium),
                          child: Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: visibleItems.map((a) => _buildBadge(a, earnedIds.contains(a.id), primary, isDark, isArabic)).toList(),
                          ),
                        ),
                      ),
                      if (hasMore)
                        InkWell(
                          onTap: () => setState(() => _isExpanded = !_isExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedRotation(
                                  turns: _isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  child: Icon(Icons.expand_more, size: 18, color: primary),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isExpanded
                                      ? (isArabic ? 'عرض أقل' : 'Show less')
                                      : (isArabic ? 'عرض الكل (${all.length - maxCollapsed}+)' : 'Show all (+${all.length - maxCollapsed})'),
                                  style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              // Footer — always navigates to full achievements screen
              InkWell(
                onTap: () => Navigator.of(context).pushNamed('/achievements'),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppConstants.radiusLarge)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppConstants.radiusLarge)),
                    border: Border(top: BorderSide(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isArabic
                            ? '${earned.length} من ${all.length} مكتمل'
                            : '${earned.length} of ${all.length} unlocked',
                        style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: 11, color: primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

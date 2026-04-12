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
import '../../core/models/prayer_record.dart';
import '../../core/widgets/setting_tile.dart';

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
                backgroundColor: AppConstants.primaryColor,
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
            _buildProfileHeader(context, user, isDark)
                .animate().fadeIn(duration: 400.ms),

            const SizedBox(height: AppConstants.paddingMedium),

            // Prayer Stats Summary
            _buildPrayerStatsSummary(context, isDark, isArabic),

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
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // Achievements Section
            SettingsSectionHeader(
              icon: Icons.emoji_events,
              title: isArabic ? 'الإنجازات' : 'Achievements',
            ),
            SettingsCard(
              children: [
                SettingTile(
                  icon: Icons.military_tech,
                  title: isArabic ? 'عرض الإنجازات' : 'View Achievements',
                  subtitle: isArabic ? 'الشارات والأوسمة' : 'Badges and milestones',
                  trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                  onTap: () => Navigator.of(context).pushNamed('/achievements'),
                ),
              ],
            ),
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

            // Account Management Section
            SettingsSectionHeader(
              icon: Icons.manage_accounts,
              title: isArabic ? 'إدارة الحساب' : 'Account Management',
            ),
            SettingsCard(
              children: [
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
                  AppConstants.primaryColor.withOpacity(0.15),
                  AppConstants.accentCyan.withOpacity(0.1),
                ]
              : [
                  AppConstants.primaryColor.withOpacity(0.05),
                  AppConstants.accentCyan.withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
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
                  AppConstants.primaryColor,
                  AppConstants.accentCyan,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primaryColor.withOpacity(0.3),
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
                  user.displayName ?? 'User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppConstants.primaryColor,
                      ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 4),

                // Email
                if (user.email != null)
                  Text(
                    user.email!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : AppConstants.lightTextSecondary,
                        ),
                    textAlign: TextAlign.left,
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
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(isArabic ? 'أسود AMOLED' : 'AMOLED Black'),
              trailing: currentTheme == 'amoled'
                  ? const Icon(Icons.check, color: AppConstants.primaryColor)
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

        final completionPct = (completionRate * 100).round();

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
                  icon: Icons.check_circle,
                  value: '${NumberFormatter.withArabicNumeralsByLanguage('$completionPct', isArabic ? 'ar' : 'en')}%',
                  label: isArabic ? 'الإتمام' : 'Completion',
                  color: Colors.green,
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

      return {
        'streak': streak,
        'completionRate': stats.completionRate,
        'totalPrayers': stats.completedOnTime + stats.completedLate,
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
                      SnackBar(content: Text('$e'), backgroundColor: AppConstants.error),
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
                      SnackBar(content: Text('$e'), backgroundColor: AppConstants.error),
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
        color: isDark ? AppConstants.darkCard : Colors.white,
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

import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aura_button.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/models/achievement.dart';
import '../../core/models/prayer_record.dart';
import '../../core/providers/task_provider.dart';
import '../../core/providers/guest_migration_provider.dart';

import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/widgets/setting_tile.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/share_card.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/shared_preferences_service.dart';
import '../../core/utils/share_util.dart';

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
        appBar: AppBar(title: Text('profile'.tr())),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: ShimmerLoading(
            child: Column(
              children: [
                // Header card skeleton (avatar + name + email)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  ),
                  child: Row(
                    children: [
                      const ShimmerBox(width: 64, height: 64, borderRadius: BorderRadius.all(Radius.circular(32))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: double.infinity, height: 16, borderRadius: BorderRadius.circular(8)),
                            const SizedBox(height: 8),
                            ShimmerBox(width: 160, height: 12, borderRadius: BorderRadius.circular(6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                // Stats row skeletons
                const ShimmerCard(height: 80),
                const SizedBox(height: AppConstants.paddingMedium),
                const ShimmerCard(height: 80),
                const SizedBox(height: AppConstants.paddingMedium),
                // Settings tile skeletons
                const ShimmerCard(height: 56),
                const SizedBox(height: 8),
                const ShimmerCard(height: 56),
                const SizedBox(height: 8),
                const ShimmerCard(height: 56),
              ],
            ),
          ),
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
      body: Builder(builder: (ctx) {
        final ts = MediaQuery.textScalerOf(ctx);
        return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: ts.scale(100.0),
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            SizedBox(height: ts.scale(AppConstants.paddingLarge)),
            Text(
              'login_required'.tr(),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            SizedBox(height: ts.scale(AppConstants.paddingMedium)),
            Text(
              'login_required_desc'.tr(),
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppConstants.darkTextSecondary
                        : AppConstants.lightTextSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ts.scale(AppConstants.paddingXLarge)),
            AuraButton(
              label: 'login'.tr(),
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pushReplacementNamed('/login'),
              icon: const Icon(Icons.login),
            ),
          ],
        ),
      );
      }),
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
    final appMode = ref.watch(appModeProvider);

    final ts = MediaQuery.textScalerOf(context);
    final gapM = ts.scale(AppConstants.paddingMedium).clamp(0.0, 20.0);
    final gapL = ts.scale(AppConstants.paddingLarge).clamp(0.0, 28.0);
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الملف الشخصي' : 'Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: gapM),

            // Profile Header Card
            _buildProfileHeader(context, user, isDark, isArabic)
                .animate().fadeIn(duration: 400.ms),

            SizedBox(height: gapM),

            // Prayer Stats Summary
            _buildPrayerStatsSummary(context, isDark, isArabic),

            SizedBox(height: gapM),

            // Task Stats Summary
            _buildTaskStatsSummary(context, ref, isDark, isArabic),

            SizedBox(height: gapM),

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
            SizedBox(height: gapL),

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

            SizedBox(height: gapL),

            // Achievements Section
            SettingsSectionHeader(
              icon: Icons.emoji_events,
              title: isArabic ? 'الإنجازات' : 'Achievements',
            ),
            _AchievementsBadgeGrid(isDark: isDark, isArabic: isArabic, appMode: appMode),
            SizedBox(height: gapL),

            // Settings & App Tour Section
            SettingsSectionHeader(
              icon: Icons.settings_outlined,
              title: isArabic ? 'الإعدادات' : 'Settings',
            ),
            SettingsCard(
              children: [
                SettingTile(
                  icon: Icons.settings_outlined,
                  title: isArabic ? 'جميع الإعدادات' : 'All Settings',
                  subtitle: isArabic ? 'الصلاة، المهام، الإشعارات، المظهر' : 'Prayer, tasks, notifications, appearance',
                  onTap: () => Navigator.of(context).pushNamed('/settings'),
                ),
                SettingTile(
                  icon: Icons.tour_outlined,
                  title: isArabic ? 'جولة التطبيق' : 'App Tour',
                  subtitle: isArabic ? 'أعد مشاهدة دليل التطبيق' : 'Replay the interactive walkthrough',
                  onTap: () async {
                    final prefs = SharedPreferencesService.instance;
                    await prefs.setTutorialCompleted(false);
                    await prefs.setTutorialPrayerSeen(false);
                    await prefs.setTutorialQuranSeen(false);
                    await prefs.setTutorialTasksSeen(false);
                    await prefs.setTutorialJuzSeen(false);
                    await prefs.setTutorialBookmarksSeen(false);
                    await prefs.setTutorialWirdSeen(false);
                    await prefs.setTutorialReaderSeen(false);
                    ref.read(tabNavigationProvider.notifier).state = 0;
                    ref.read(showTutorialProvider.notifier).state = true;
                  },
                ),
              ],
            ),
            SizedBox(height: gapL),

            // About Section
            SettingsSectionHeader(
              icon: Icons.info_outline,
              title: isArabic ? 'حول التطبيق' : 'About',
            ),
            SettingsCard(
              children: [
                Builder(builder: (ctx) {
                  if (!kIsWeb && Platform.isWindows) {
                    return SettingTile(
                      icon: Icons.info_outline,
                      title: isArabic ? 'الإصدار' : 'Version',
                      subtitle: AppConstants.desktopVersion,
                    );
                  }
                  return FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snap) {
                      final version = snap.hasData
                          ? '${snap.data!.version}+${snap.data!.buildNumber}'
                          : '—';
                      return SettingTile(
                        icon: Icons.info_outline,
                        title: isArabic ? 'الإصدار' : 'Version',
                        subtitle: version,
                      );
                    },
                  );
                }),
                SettingTile(
                  icon: Icons.code,
                  title: isArabic ? 'المطور' : 'Developer',
                  subtitle: 'Aura Team',
                ),
              ],
            ),
            SizedBox(height: gapL),

            // Guest data sync card (shown when local tasks are pending migration)
            Builder(builder: (ctx) {
              final migration = ref.watch(guestMigrationProvider);
              if (!migration.isPending) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.paddingMedium,
                  0,
                  AppConstants.paddingMedium,
                  AppConstants.paddingMedium,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppConstants.getPrimary(isDark).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    border: Border.all(
                      color: AppConstants.getPrimary(isDark).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              color: AppConstants.getPrimary(isDark), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'guest_sync_profile_title'.tr(),
                            style: AppTypography.label.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppConstants.getPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'guest_sync_profile_subtitle'
                            .tr()
                            .replaceAll('%d', '${migration.taskCount}'),
                        style: AppTypography.bodyS.copyWith(
                          color: AppConstants.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AuraButton(
                        label: 'guest_sync_profile_btn'.tr(),
                        onPressed: () async {
                          await ref.read(guestMigrationProvider.notifier).migrate();
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('guest_sync_success'.tr())),
                          );
                        },
                        expanded: true,
                        verticalPadding: 10,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Logout Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ts.scale(AppConstants.paddingMedium)),
              child: SizedBox(
                width: double.infinity,
                height: ts.scale(54.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context, ref, isArabic),
                  icon: Icon(Icons.logout, size: ts.scale(20.0)),
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
            SizedBox(height: ts.scale(100.0)),
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
          Builder(builder: (ctx) {
            final ats = MediaQuery.textScalerOf(ctx);
            final avatarSz = ats.scale(80.0);
            final avatarFontSz = ats.scale(32.0);
            return Container(
            width: avatarSz,
            height: avatarSz,
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
                        width: avatarSz,
                        height: avatarSz,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            (user.displayName ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: avatarFontSz,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      (user.displayName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: avatarFontSz,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          );
          }),
          SizedBox(width: MediaQuery.textScalerOf(context).scale(AppConstants.paddingLarge)),

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
                SizedBox(height: MediaQuery.textScalerOf(context).scale(4.0)),

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
                  style: AppTypography.caption.copyWith(color: isArabic ? Colors.grey : Colors.grey[600]),
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

        final ts = MediaQuery.textScalerOf(context);
        final gap = SizedBox(width: ts.scale(8.0));
        return Column(
          children: [
          if (streak > 0)
            Padding(
              padding: EdgeInsets.only(right: ts.scale(AppConstants.paddingMedium), bottom: ts.scale(4.0)),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => _showShareDialog(context, isArabic, ShareCardType.prayerStreak, streak),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: Text(isArabic ? 'مشاركة' : 'Share', style: AppTypography.caption),
                  style: TextButton.styleFrom(foregroundColor: AppConstants.getPrimary(isDark)),
                ),
              ),
            ),
          Padding(
          padding: EdgeInsets.symmetric(horizontal: ts.scale(AppConstants.paddingMedium)),
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
              gap,
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.mosque_outlined,
                  value: NumberFormatter.withArabicNumeralsByLanguage('$totalPrayers', isArabic ? 'ar' : 'en'),
                  label: isArabic ? 'الصلوات' : 'Prayers',
                  color: AppConstants.getPrimary(isDark),
                  isDark: isDark,
                ),
              ),
              gap,
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.check_circle,
                  value: completionValue,
                  label: isArabic ? 'الإتمام' : 'Completion',
                  color: totalPrayers > 0 ? Colors.green : Colors.grey,
                  isDark: isDark,
                ),
              ),
              gap,
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
          ),
          ],
        );
      },
    );
  }

  void _showShareDialog(BuildContext context, bool isArabic, ShareCardType type, int count) {
    final lang = isArabic ? 'ar' : 'en';
    final cardKey = GlobalKey();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShareCard(repaintKey: cardKey, type: type, count: count, lang: lang),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await captureAndShare(cardKey, 'aura_share.png');
                  },
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: Text(isArabic ? 'مشاركة' : 'Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskStatsSummary(BuildContext context, WidgetRef ref, bool isDark, bool isArabic) {
    final statsAsync = ref.watch(taskStatisticsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.total == 0) return const SizedBox.shrink();
        final ts = MediaQuery.textScalerOf(context);
        final gap = SizedBox(width: ts.scale(8.0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ts.scale(AppConstants.paddingMedium)),
              child: Text(
                isArabic ? 'المهام' : 'Tasks',
                style: AppTypography.bodyS.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textMuted(isDark),
                ),
              ),
            ),
            SizedBox(height: ts.scale(8.0)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ts.scale(AppConstants.paddingMedium)),
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
                  gap,
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
                  gap,
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
                    final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isArabic ? 'خطأ: $e' : 'Error: $e'), backgroundColor: AppConstants.error, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16)),
                    );
                    Future.delayed(const Duration(seconds: 3), snackCtrl.close);
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
                    final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'تم تغيير كلمة المرور' : 'Password updated'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
                      ),
                    );
                    Future.delayed(const Duration(seconds: 3), snackCtrl.close);
                  }
                } catch (e) {
                  if (context.mounted) {
                    final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isArabic ? 'خطأ: $e' : 'Error: $e'), backgroundColor: AppConstants.error, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16)),
                    );
                    Future.delayed(const Duration(seconds: 3), snackCtrl.close);
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
              style: AppTypography.label.copyWith(color: AppConstants.error),
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
    final ts = MediaQuery.textScalerOf(context);
    return Container(
      padding: EdgeInsets.all(ts.scale(12.0)),
      decoration: BoxDecoration(
        color: AppConstants.card(isDark),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: ts.scale(18.0)),
              SizedBox(width: ts.scale(8.0)),
              Text(value, style: AppTypography.headingS.copyWith(fontWeight: FontWeight.bold, color: AppConstants.textPrimary(isDark))),
            ],
          ),
          SizedBox(height: ts.scale(2.0)),
          Text(label, style: AppTypography.caption.copyWith(fontSize: ts.scale(10.0), color: AppConstants.textMuted(isDark)), textScaler: TextScaler.noScaling),
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
      (AppMode.both, Icons.apps, isArabic ? 'الكل' : 'Full App', isArabic ? 'الصلاة والقرآن والمهام' : 'Prayer, Quran & Tasks'),
      (AppMode.prayerOnly, Icons.mosque, isArabic ? 'الصلاة والقرآن' : 'Prayer & Quran', isArabic ? 'أوقات الصلاة والقرآن والأذان' : 'Prayer times, Quran & Adhan'),
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
  final AppMode appMode;
  const _AchievementsBadgeGrid({required this.isDark, required this.isArabic, required this.appMode});

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

  Widget _buildBadge(Achievement achievement, bool isEarned, Color primary, bool isDark, bool isArabic, {required double size}) {
    final isTask = achievement.category == AchievementCategory.tasks;
    return Tooltip(
      message: isArabic ? achievement.nameAr : achievement.nameEn,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEarned
              ? primary.withOpacity(isTask ? 0.15 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isEarned
                ? primary.withOpacity(isTask ? 0.6 : 0.35)
                : (AppConstants.border(isDark)),
            width: isEarned && isTask ? 2 : 1,
          ),
        ),
        child: Center(
          child: Opacity(
            opacity: isEarned ? 1.0 : 0.25,
            child: Text(
              achievement.iconEmoji,
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: size * 0.42),
            ),
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
    final all = AchievementDefinitions.all.where((a) {
      if (widget.appMode == AppMode.tasksOnly) return a.category == AchievementCategory.tasks;
      if (widget.appMode == AppMode.prayerOnly) return a.category != AchievementCategory.tasks;
      return true;
    }).toList();

    return FutureBuilder<List<Achievement>>(
      future: _future,
      builder: (context, snapshot) {
        final earned = snapshot.data ?? [];
        final earnedIds = earned.map((a) => a.id).toSet();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.card(isDark),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppConstants.border(isDark)),
          ),
          child: Column(
            children: [
              // Badge grid — collapses to 2 rows
              LayoutBuilder(
                builder: (context, constraints) {
                  final ts = MediaQuery.textScalerOf(context);
                  final itemSize = ts.scale(52.0);
                  final spacing = ts.scale(10.0);
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
                            children: visibleItems.map((a) => _buildBadge(a, earnedIds.contains(a.id), primary, isDark, isArabic, size: itemSize)).toList(),
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
                                  child: Icon(Icons.expand_more, size: ts.scale(18.0), color: primary),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isExpanded
                                      ? (isArabic ? 'عرض أقل' : 'Show less')
                                      : (isArabic ? 'عرض الكل (${NumberFormatter.withArabicNumerals('${all.length - maxCollapsed}')}+)' : 'Show all (+${all.length - maxCollapsed})'),
                                  style: AppTypography.caption.copyWith(color: primary, fontWeight: FontWeight.w600),
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
                    border: Border(top: BorderSide(color: AppConstants.border(isDark))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isArabic
                            ? '${NumberFormatter.withArabicNumerals('${earned.length}')} من ${NumberFormatter.withArabicNumerals('${all.length}')} مكتمل'
                            : '${earned.length} of ${all.length} unlocked',
                        style: AppTypography.caption.copyWith(color: primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: MediaQuery.textScalerOf(context).scale(11.0), color: primary),
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

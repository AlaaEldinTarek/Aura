import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currentMode = ref.watch(appModeProvider);

    final modes = [
      _ModeOption(
        mode: AppMode.both,
        icon: '🕌✅',
        title: isArabic ? 'الكل' : 'Full App',
        subtitle: isArabic
            ? 'أوقات الصلاة وإدارة المهام معاً'
            : 'Prayer times + Task management',
        color: AppConstants.getPrimary(isDark),
      ),
      _ModeOption(
        mode: AppMode.prayerOnly,
        icon: '🕌',
        title: isArabic ? 'الصلاة فقط' : 'Prayer Only',
        subtitle: isArabic
            ? 'أوقات الصلاة والأذان والتتبع'
            : 'Prayer times, adhan & tracking',
        color: Colors.green,
      ),
      _ModeOption(
        mode: AppMode.tasksOnly,
        icon: '✅',
        title: isArabic ? 'المهام فقط' : 'Tasks Only',
        subtitle: isArabic
            ? 'إدارة المهام والتركيز'
            : 'Task management & focus mode',
        color: Colors.orange,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                isArabic ? 'كيف تريد استخدام التطبيق؟' : 'How do you want to use the app?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isArabic ? 'يمكنك تغيير هذا لاحقاً من الملف الشخصي' : 'You can change this later from Profile',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ...modes.map((option) => _buildModeCard(
                context: context,
                option: option,
                isSelected: currentMode == option.mode,
                isDark: isDark,
                onTap: () => ref.read(appModeProvider.notifier).setMode(option.mode),
              )),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.getPrimary(isDark),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  ),
                ),
                child: Text(
                  isArabic ? 'ابدأ' : 'Get Started',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required _ModeOption option,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withOpacity(0.1)
              : (isDark ? AppConstants.darkCard : AppConstants.lightCard),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: isSelected ? option.color : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(option.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? option.color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: option.color),
          ],
        ),
      ),
    );
  }
}

class _ModeOption {
  final AppMode mode;
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  const _ModeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

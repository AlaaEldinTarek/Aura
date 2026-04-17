import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/notification_service.dart';

class PreferenceScreen extends ConsumerStatefulWidget {
  const PreferenceScreen({super.key});

  @override
  ConsumerState<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends ConsumerState<PreferenceScreen> {
  bool _isSaving = false;
  String _selectedLanguage = 'en';
  String _selectedTheme = 'system';
  int _currentStep = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final languageAsync = ref.read(languageProvider);
    final themeAsync = ref.read(themeModeProvider);

    final language = languageAsync.value ?? 'en';
    final theme = themeAsync.value ?? 'system';

    if (mounted) {
      setState(() {
        _selectedLanguage = language;
        _selectedTheme = theme;
      });
    }
  }

  bool get _isArabic => _selectedLanguage == 'ar';

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _requestLocationPermission() async {
    await Geolocator.requestPermission();
    _nextStep();
  }

  Future<void> _requestNotificationPermission() async {
    await NotificationService.instance.requestPermissions();
    _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);

    try {
      await ref.read(languageProvider.notifier).setLanguage(_selectedLanguage);
      context.setLocale(Locale(_selectedLanguage));
      await ref.read(themeModeProvider.notifier).setThemeMode(_selectedTheme);
      await ref.read(firstLaunchProvider.notifier).setFirstLaunch(false);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_unknown'.tr()),
            backgroundColor: AppConstants.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppConstants.darkBackground, AppConstants.darkSurface]
                : [AppConstants.primaryColor.withOpacity(0.08), AppConstants.lightBackground],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Step indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge, vertical: AppConstants.paddingMedium),
                child: Row(
                  children: List.generate(4, (index) {
                    final isActive = index <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: isActive ? AppConstants.primaryColor : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(context, isDark),
                    _buildPreferencesStep(context, isDark),
                    _buildLocationStep(context, isDark),
                    _buildNotificationStep(context, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step 1: Welcome
  Widget _buildWelcomeStep(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppConstants.paddingXLarge),

            // Logo
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppConstants.primaryColor.withOpacity(0.2),
                      AppConstants.accentCyan.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🕌', style: TextStyle(fontSize: 72)),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(duration: 500.ms, curve: Curves.elasticOut),

            const SizedBox(height: AppConstants.paddingXLarge),

            Text(
              _isArabic ? 'مرحباً بك في هالة' : 'Welcome to Aura',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

            const SizedBox(height: AppConstants.paddingMedium),

            Text(
              _isArabic
                  ? 'تطبيقك الشامل للصلاة والإنتاجية. دعنا نساعدك في الإعداد.'
                  : 'Your all-in-one prayer and productivity app. Let\'s get you set up.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

            const SizedBox(height: AppConstants.paddingXLarge * 2),

            // Quick feature highlights
            _buildFeatureHighlight(context, isDark, Icons.mosque, _isArabic ? 'أوقات الصلاة' : 'Prayer Times', _isArabic ? 'مع 9 طرق حسابية' : 'With 9 calculation methods'),
            const SizedBox(height: 8),
            _buildFeatureHighlight(context, isDark, Icons.track_changes, _isArabic ? 'تتبع الصلاة' : 'Prayer Tracking', _isArabic ? 'سجل صلواتك اليومية' : 'Track your daily prayers'),
            const SizedBox(height: 8),
            _buildFeatureHighlight(context, isDark, Icons.explore, _isArabic ? 'القبلة' : 'Qibla', _isArabic ? 'بوصلة دقيقة للكعبة' : 'Accurate compass to Kaaba'),
            const SizedBox(height: 8),
            _buildFeatureHighlight(context, isDark, Icons.pan_tool, _isArabic ? 'تسبيح' : 'Zikr', _isArabic ? 'عداد أذكار رقمي' : 'Digital zikr counter'),

            const SizedBox(height: AppConstants.paddingXLarge * 2),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  ),
                ),
                child: Text(
                  _isArabic ? 'لنبدأ' : 'Let\'s Get Started',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureHighlight(BuildContext context, bool isDark, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard.withOpacity(0.5) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 28),
          const SizedBox(width: AppConstants.paddingMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // Step 2: Language + Theme
  Widget _buildPreferencesStep(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppConstants.paddingLarge),

            Text(
              _isArabic ? 'تخصيص' : 'Customize',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppConstants.paddingXLarge),

            // Language Selection
            _buildLanguageSelector(context, isDark),

            const SizedBox(height: AppConstants.paddingMedium),

            // Theme Selection
            _buildThemeSelector(context, isDark),

            const SizedBox(height: AppConstants.paddingXLarge * 2),

            // Continue Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  ),
                ),
                child: Text(
                  _isArabic ? 'التالي' : 'Next',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: () => _finishOnboarding(),
              child: Text(
                _isArabic ? 'تخطي الإعداد' : 'Skip Setup',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Location Permission
  Widget _buildLocationStep(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppConstants.paddingXLarge * 2),

            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppConstants.accentCyan.withOpacity(0.2), AppConstants.primaryColor.withOpacity(0.1)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.location_on, size: 64, color: AppConstants.primaryColor),
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingXLarge),

            Text(
              _isArabic ? 'الوصول إلى الموقع' : 'Location Access',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            Text(
              _isArabic
                  ? 'نحتاج موقعك لحساب أوقات الصلاة بدقة وعرض اتجاه القبلة.'
                  : 'We need your location to calculate accurate prayer times and show Qibla direction.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            _buildPermissionReason(context, isDark, Icons.access_time, _isArabic ? 'أوقات صلاة دقيقة' : 'Accurate prayer times'),
            const SizedBox(height: 8),
            _buildPermissionReason(context, isDark, Icons.explore, _isArabic ? 'اتجاه القبلة' : 'Qibla direction'),
            const SizedBox(height: 8),
            _buildPermissionReason(context, isDark, Icons.notifications_active, _isArabic ? 'إشعارات الصلاة' : 'Prayer notifications'),

            const SizedBox(height: AppConstants.paddingXLarge * 2),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _requestLocationPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  ),
                ),
                child: Text(
                  _isArabic ? 'السماح بالوصول' : 'Allow Location',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _nextStep,
              child: Text(
                _isArabic ? 'تخطي - سأضبطه لاحقاً' : 'Skip — I\'ll set it up later',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 4: Notification Permission
  Widget _buildNotificationStep(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppConstants.paddingXLarge * 2),

            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppConstants.primaryColor.withOpacity(0.2), AppConstants.accentOrange.withOpacity(0.1)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.notifications_active, size: 64, color: AppConstants.primaryColor),
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingXLarge),

            Text(
              _isArabic ? 'الإشعارات' : 'Notifications',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            Text(
              _isArabic
                  ? 'اسمح بالإشعارات لتلقي تنبيهات أوقات الصلاة والأذان.'
                  : 'Allow notifications to receive prayer time alerts and Adhan reminders.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            _buildPermissionReason(context, isDark, Icons.alarm, _isArabic ? 'تنبيه قبل الصلاة' : 'Reminder before prayer'),
            const SizedBox(height: 8),
            _buildPermissionReason(context, isDark, Icons.record_voice_over, _isArabic ? 'تشغيل الأذان' : 'Azan playback'),
            const SizedBox(height: 8),
            _buildPermissionReason(context, isDark, Icons.phonelink_ring, _isArabic ? 'الوضع الصامت التلقائي' : 'Auto silent mode'),

            const SizedBox(height: AppConstants.paddingXLarge * 2),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _requestNotificationPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isArabic ? 'السماح بالإشعارات' : 'Allow Notifications',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _isSaving ? null : _finishOnboarding,
              child: Text(
                _isArabic ? 'تخطي - سأضبطه لاحقاً' : 'Skip — I\'ll set it up later',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionReason(BuildContext context, bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard.withOpacity(0.5) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 24),
          const SizedBox(width: AppConstants.paddingMedium),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language, color: AppConstants.primaryColor),
              const SizedBox(width: AppConstants.paddingSmall),
              Text(
                _isArabic ? 'اللغة' : 'Language',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              Expanded(
                child: _LanguageOption(
                  title: 'English',
                  isSelected: _selectedLanguage == 'en',
                  onTap: () => setState(() => _selectedLanguage = 'en'),
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: _LanguageOption(
                  title: 'العربية',
                  isSelected: _selectedLanguage == 'ar',
                  onTap: () => setState(() => _selectedLanguage = 'ar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: AppConstants.primaryColor),
              const SizedBox(width: AppConstants.paddingSmall),
              Text(
                _isArabic ? 'المظهر' : 'Theme',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  title: _isArabic ? 'فاتح' : 'Light',
                  icon: Icons.light_mode,
                  isSelected: _selectedTheme == 'light',
                  onTap: () => setState(() => _selectedTheme = 'light'),
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: _ThemeOption(
                  title: _isArabic ? 'داكن' : 'Dark',
                  icon: Icons.dark_mode,
                  isSelected: _selectedTheme == 'dark',
                  onTap: () => setState(() => _selectedTheme = 'dark'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  title: _isArabic ? 'النظام' : 'System',
                  icon: Icons.brightness_auto,
                  isSelected: _selectedTheme == 'system',
                  onTap: () => setState(() => _selectedTheme = 'system'),
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: _ThemeOption(
                  title: _isArabic ? 'أسود AMOLED' : 'AMOLED Black',
                  icon: Icons.dark_mode_outlined,
                  isSelected: _selectedTheme == 'amoled',
                  onTap: () => setState(() => _selectedTheme = 'amoled'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor : (isDark ? AppConstants.darkSurface : Colors.grey[100]),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({required this.title, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppConstants.primaryColor : (isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppConstants.primaryColor : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';

class PreferenceScreen extends ConsumerStatefulWidget {
  const PreferenceScreen({super.key});

  @override
  ConsumerState<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends ConsumerState<PreferenceScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  int _step = 0;               // 0-4
  int _carouselSlide = 0;      // 0-2 within step 3
  bool _saving = false;

  String _language = 'en';
  String _theme = 'system';
  AppMode _mode = AppMode.both;

  final _pageController    = PageController();
  final _carouselController = PageController();

  static const int _totalSteps = 5;

  bool get _isAr => _language == 'ar';

  // ── Carousel content per mode ─────────────────────────────────────────────
  List<_Slide> get _slides {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (_mode) {
      case AppMode.prayerOnly:
        return [
          _Slide(
            emoji: '🕌',
            color: const Color(0xFF1565C0),
            titleEn: 'Accurate Prayer Times',
            titleAr: 'أوقات صلاة دقيقة',
            subtitleEn: 'GPS-based calculation with 9 scholarly methods',
            subtitleAr: 'حساب بالموقع الجغرافي بـ 9 طرق علمية',
            features: [
              _Feature('⏰', 'All 5 daily prayers + Sunrise', 'جميع الصلوات الخمس + الشروق'),
              _Feature('📍', 'Auto-detects your city', 'يتعرف تلقائياً على مدينتك'),
              _Feature('🔔', 'Adhan alerts at prayer time', 'أذان عند دخول وقت الصلاة'),
            ],
          ),
          _Slide(
            emoji: '📿',
            color: const Color(0xFF00695C),
            titleEn: 'Spiritual Tools',
            titleAr: 'أدوات روحية',
            subtitleEn: 'Everything you need for your worship',
            subtitleAr: 'كل ما تحتاجه في عبادتك',
            features: [
              _Feature('🧭', 'Qibla compass to Kaaba', 'بوصلة القبلة نحو الكعبة'),
              _Feature('📿', 'Digital Dhikr counter', 'عداد أذكار رقمي'),
              _Feature('🌙', 'Daily Hadith & Quran', 'حديث وآية يومية'),
            ],
          ),
          _Slide(
            emoji: '📊',
            color: const Color(0xFF6A1B9A),
            titleEn: 'Track Your Journey',
            titleAr: 'تتبع رحلتك',
            subtitleEn: 'Build consistency with daily prayer tracking',
            subtitleAr: 'ابنِ المداومة بتتبع الصلوات اليومية',
            features: [
              _Feature('🔥', 'Prayer streaks & milestones', 'سلاسل الصلاة والإنجازات'),
              _Feature('📅', 'Monthly calendar view', 'عرض تقويمي شهري'),
              _Feature('🏆', 'Achievements & badges', 'أوسمة وشارات'),
            ],
          ),
        ];

      case AppMode.tasksOnly:
        return [
          _Slide(
            emoji: '✅',
            color: const Color(0xFF2E7D32),
            titleEn: 'Smart Task Management',
            titleAr: 'إدارة مهام ذكية',
            subtitleEn: 'Organize everything that matters to you',
            subtitleAr: 'نظّم كل ما يهمك',
            features: [
              _Feature('🎯', 'Priorities, categories & due dates', 'أولويات وتصنيفات ومواعيد'),
              _Feature('📋', 'Subtasks & recurring tasks', 'مهام فرعية ومتكررة'),
              _Feature('📌', 'Pin important tasks to top', 'تثبيت المهام المهمة'),
            ],
          ),
          _Slide(
            emoji: '🎯',
            color: const Color(0xFFE65100),
            titleEn: 'Stay Focused',
            titleAr: 'ابقَ مركزاً',
            subtitleEn: 'Lock in and get things done without distractions',
            subtitleAr: 'ركز وأنجز مهامك بلا تشتيت',
            features: [
              _Feature('🔒', 'Focus mode locks your screen', 'وضع التركيز يقفل شاشتك'),
              _Feature('🔕', 'Silences all notifications', 'يكتم جميع الإشعارات'),
              _Feature('⏱️', 'Countdown timer on screen', 'مؤقت عدّ تنازلي على الشاشة'),
            ],
          ),
          _Slide(
            emoji: '🏆',
            color: const Color(0xFF6A1B9A),
            titleEn: 'Build Good Habits',
            titleAr: 'ابنِ عادات جيدة',
            subtitleEn: 'Stay motivated with streaks and achievements',
            subtitleAr: 'حافظ على حماسك بالسلاسل والإنجازات',
            features: [
              _Feature('🔥', '7-day task streak tracking', 'تتبع سلسلة 7 أيام'),
              _Feature('🏅', 'Unlock achievement badges', 'افتح شارات الإنجازات'),
              _Feature('📈', 'Daily & weekly statistics', 'إحصاءات يومية وأسبوعية'),
            ],
          ),
        ];

      case AppMode.both:
        return [
          _Slide(
            emoji: '✨',
            color: AppConstants.getPrimary(isDark),
            titleEn: 'Your Complete Companion',
            titleAr: 'رفيقك الشامل',
            subtitleEn: 'Prayer times + Task management in one beautiful app',
            subtitleAr: 'أوقات الصلاة وإدارة المهام في تطبيق واحد',
            features: [
              _Feature('🕌', 'Full Islamic prayer system', 'نظام صلاة إسلامي متكامل'),
              _Feature('✅', 'Powerful task management', 'إدارة مهام قوية'),
              _Feature('🏆', 'Unified achievements', 'إنجازات موحدة للاثنين'),
            ],
          ),
          _Slide(
            emoji: '🌅',
            color: const Color(0xFFE65100),
            titleEn: 'Structure Your Day',
            titleAr: 'نظّم يومك',
            subtitleEn: 'Plan your tasks around your prayer schedule',
            subtitleAr: 'خطط مهامك حول أوقات صلاتك',
            features: [
              _Feature('⏰', 'Know when your prayers are', 'اعرف أوقات صلاتك'),
              _Feature('📋', 'Fill the gaps with tasks', 'املأ الفراغات بالمهام'),
              _Feature('🎯', 'Focus mode between prayers', 'وضع التركيز بين الصلوات'),
            ],
          ),
          _Slide(
            emoji: '📈',
            color: const Color(0xFF2E7D32),
            titleEn: 'Track Everything',
            titleAr: 'تتبع كل شيء',
            subtitleEn: 'Spiritual and productive growth in one view',
            subtitleAr: 'النمو الروحي والإنتاجي في مكان واحد',
            features: [
              _Feature('🔥', 'Prayer & task streaks', 'سلاسل الصلاة والمهام'),
              _Feature('📊', 'Combined statistics', 'إحصاءات مجمّعة'),
              _Feature('🏅', 'Earn badges for both', 'اكسب شارات لكلٍّ منهما'),
            ],
          ),
        ];
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next() {
    if (_step == 3) {
      // Within carousel
      if (_carouselSlide < 2) {
        _carouselController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        setState(() => _carouselSlide++);
        return;
      }
    }
    if (_step < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _step++;
        if (_step == 3) _carouselSlide = 0;
      });
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 3 && _carouselSlide > 0) {
      _carouselController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _carouselSlide--);
      return;
    }
    if (_step > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(languageProvider.notifier).setLanguage(_language);
      if (mounted) {
        final ctx = context;
        ctx.findAncestorStateOfType<State>(); // ensure context valid
        await ref.read(themeModeProvider.notifier).setThemeMode(_theme);
        await ref.read(appModeProvider.notifier).setMode(_mode);
        await ref.read(firstLaunchProvider.notifier).setFirstLaunch(false);
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Button label ──────────────────────────────────────────────────────────
  String get _btnLabel {
    if (_step == 4) return _isAr ? 'هيا بنا! 🚀' : "Let's Go! 🚀";
    if (_step == 3 && _carouselSlide < 2) return _isAr ? 'التالي' : 'Next';
    return _isAr ? 'متابعة' : 'Continue';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppConstants.darkBackground : AppConstants.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(_totalSteps, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active
                            ? AppConstants.getPrimary(isDark)
                            : (isDark ? Colors.white12 : Colors.black12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Page content ───────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _LanguageStep(
                    selected: _language,
                    onSelect: (v) => setState(() => _language = v),
                  ),
                  _ThemeStep(
                    selected: _theme,
                    isAr: _isAr,
                    onSelect: (v) => setState(() => _theme = v),
                  ),
                  _ModeStep(
                    selected: _mode,
                    isAr: _isAr,
                    isDark: isDark,
                    onSelect: (v) => setState(() => _mode = v),
                  ),
                  _CarouselStep(
                    slides: _slides,
                    currentSlide: _carouselSlide,
                    controller: _carouselController,
                    isAr: _isAr,
                    isDark: isDark,
                    onSlideChanged: (i) => setState(() => _carouselSlide = i),
                  ),
                  _AllSetStep(
                    isAr: _isAr,
                    isDark: isDark,
                    language: _language,
                    theme: _theme,
                    mode: _mode,
                  ),
                ],
              ),
            ),

            // ── Fixed bottom buttons ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.getPrimary(isDark),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _btnLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _back,
                      child: Text(
                        _isAr ? 'رجوع' : 'Back',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 0 — Language
// ═══════════════════════════════════════════════════════════════════════════
class _LanguageStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _LanguageStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.getPrimary(isDark).withValues(alpha: 0.15),
                  AppConstants.accentCyan.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🌐', style: TextStyle(fontSize: 48)),
            ),
          ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'Choose Your Language\nاختر لغتك',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            'You can change this later\nيمكنك تغييرها لاحقاً',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 40),
          _LangCard(
            flag: '🇬🇧',
            label: 'English',
            sub: 'Continue in English',
            isSelected: selected == 'en',
            onTap: () => onSelect('en'),
            isDark: isDark,
          ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.08),
          const SizedBox(height: 14),
          _LangCard(
            flag: '🇸🇦',
            label: 'العربية',
            sub: 'المتابعة بالعربية',
            isSelected: selected == 'ar',
            onTap: () => onSelect('ar'),
            isDark: isDark,
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.08),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String flag, label, sub;
  final bool isSelected, isDark;
  final VoidCallback onTap;
  const _LangCard({
    required this.flag,
    required this.label,
    required this.sub,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.getPrimary(isDark).withValues(alpha: 0.1)
              : (isDark ? AppConstants.darkCard : AppConstants.lightCard),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppConstants.getPrimary(isDark)
                : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppConstants.getPrimary(isDark).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppConstants.getPrimary(isDark) : null,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppConstants.getPrimary(isDark) : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppConstants.getPrimary(isDark)
                      : (isDark ? Colors.white30 : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 1 — Theme
// ═══════════════════════════════════════════════════════════════════════════
class _ThemeStep extends StatelessWidget {
  final String selected;
  final bool isAr;
  final ValueChanged<String> onSelect;
  const _ThemeStep({required this.selected, required this.isAr, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [
      _ThemeOpt('light', Icons.light_mode_rounded, isAr ? 'فاتح' : 'Light',
          isAr ? 'واجهة بيضاء ناصعة' : 'Bright white interface', Colors.orange),
      _ThemeOpt('dark', Icons.dark_mode_rounded, isAr ? 'داكن' : 'Dark',
          isAr ? 'راحة للعين في الليل' : 'Easy on the eyes at night', Colors.indigo),
      _ThemeOpt('system', Icons.brightness_auto_rounded, isAr ? 'تلقائي' : 'System',
          isAr ? 'يتبع إعداد هاتفك' : 'Follows your device setting', AppConstants.getPrimary(isDark)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withValues(alpha: 0.15),
                  Colors.indigo.withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎨', style: TextStyle(fontSize: 48)),
            ),
          ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            isAr ? 'اختر المظهر' : 'Choose Your Theme',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            isAr ? 'كيف تريد أن يبدو تطبيقك؟' : 'How do you want your app to look?',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 32),
          ...options.asMap().entries.map((e) {
            final i = e.key;
            final opt = e.value;
            final isSelected = selected == opt.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(opt.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.1)
                        : (isDark ? AppConstants.darkCard : AppConstants.lightCard),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? opt.color
                          : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: opt.color.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: opt.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(opt.icon, color: opt.color, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? opt.color : null,
                              ),
                            ),
                            Text(
                              opt.sub,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? opt.color : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? opt.color
                                : (isDark ? Colors.white30 : Colors.black26),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 80)).slideY(begin: 0.1),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ThemeOpt {
  final String key, label, sub;
  final IconData icon;
  final Color color;
  const _ThemeOpt(this.key, this.icon, this.label, this.sub, this.color);
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 2 — App Mode
// ═══════════════════════════════════════════════════════════════════════════
class _ModeStep extends StatelessWidget {
  final AppMode selected;
  final bool isAr, isDark;
  final ValueChanged<AppMode> onSelect;
  const _ModeStep({
    required this.selected,
    required this.isAr,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final modes = [
      _ModeOpt(
        mode: AppMode.both,
        emoji: '✨',
        color: AppConstants.getPrimary(isDark),
        labelEn: 'Full App',
        labelAr: 'التطبيق كاملاً',
        subEn: 'Prayer times + Task management',
        subAr: 'أوقات الصلاة وإدارة المهام',
        badgeEn: 'Recommended',
        badgeAr: 'موصى به',
      ),
      _ModeOpt(
        mode: AppMode.prayerOnly,
        emoji: '🕌',
        color: const Color(0xFF1565C0),
        labelEn: 'Prayer Only',
        labelAr: 'الصلاة فقط',
        subEn: 'Adhan, Qibla, tracking & Dhikr',
        subAr: 'الأذان والقبلة والتتبع والذكر',
      ),
      _ModeOpt(
        mode: AppMode.tasksOnly,
        emoji: '✅',
        color: const Color(0xFF2E7D32),
        labelEn: 'Tasks Only',
        labelAr: 'المهام فقط',
        subEn: 'Tasks, focus mode & achievements',
        subAr: 'المهام ووضع التركيز والإنجازات',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.getPrimary(isDark).withValues(alpha: 0.15),
                  AppConstants.accentCyan.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎯', style: TextStyle(fontSize: 48)),
            ),
          ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            isAr ? 'كيف تريد استخدام هالة؟' : 'How will you use Aura?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            isAr ? 'يمكنك تغيير هذا لاحقاً من الإعدادات' : 'You can change this anytime in Settings',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 32),
          ...modes.asMap().entries.map((e) {
            final i = e.key;
            final opt = e.value;
            final isSelected = selected == opt.mode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(opt.mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.1)
                        : (isDark ? AppConstants.darkCard : AppConstants.lightCard),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? opt.color
                          : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: opt.color.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(opt.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isAr ? opt.labelAr : opt.labelEn,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? opt.color : null,
                                  ),
                                ),
                                if (opt.badgeEn != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: opt.color,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isAr ? opt.badgeAr! : opt.badgeEn!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isAr ? opt.subAr : opt.subEn,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? opt.color : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? opt.color
                                : (isDark ? Colors.white30 : Colors.black26),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 80)).slideY(begin: 0.1),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ModeOpt {
  final AppMode mode;
  final String emoji, labelEn, labelAr, subEn, subAr;
  final String? badgeEn, badgeAr;
  final Color color;
  const _ModeOpt({
    required this.mode,
    required this.emoji,
    required this.color,
    required this.labelEn,
    required this.labelAr,
    required this.subEn,
    required this.subAr,
    this.badgeEn,
    this.badgeAr,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 3 — Feature Carousel
// ═══════════════════════════════════════════════════════════════════════════
class _CarouselStep extends StatelessWidget {
  final List<_Slide> slides;
  final int currentSlide;
  final PageController controller;
  final bool isAr, isDark;
  final ValueChanged<int> onSlideChanged;

  const _CarouselStep({
    required this.slides,
    required this.currentSlide,
    required this.controller,
    required this.isAr,
    required this.isDark,
    required this.onSlideChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slides.length,
            onPageChanged: onSlideChanged,
            itemBuilder: (_, i) => _SlideView(
              slide: slides[i],
              isAr: isAr,
              isDark: isDark,
            ),
          ),
        ),
        // Carousel dots
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == currentSlide;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active
                      ? slides[currentSlide].color
                      : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool isAr, isDark;
  const _SlideView({required this.slide, required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Big emoji in colored circle
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  slide.color.withValues(alpha: 0.18),
                  slide.color.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(slide.emoji, style: const TextStyle(fontSize: 54)),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(curve: Curves.elasticOut),

          const SizedBox(height: 20),

          Text(
            isAr ? slide.titleAr : slide.titleEn,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: slide.color,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 8),

          Text(
            isAr ? slide.subtitleAr : slide.subtitleEn,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 28),

          // Feature list
          ...slide.features.asMap().entries.map((e) {
            final i = e.key;
            final f = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? slide.color.withValues(alpha: 0.08)
                      : slide.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: slide.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Text(f.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isAr ? f.textAr : f.textEn,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 80)).slideX(begin: 0.06),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Slide {
  final String emoji, titleEn, titleAr, subtitleEn, subtitleAr;
  final Color color;
  final List<_Feature> features;
  const _Slide({
    required this.emoji,
    required this.color,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.features,
  });
}

class _Feature {
  final String emoji, textEn, textAr;
  const _Feature(this.emoji, this.textEn, this.textAr);
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 4 — You're All Set
// ═══════════════════════════════════════════════════════════════════════════
class _AllSetStep extends StatelessWidget {
  final bool isAr, isDark;
  final String language, theme;
  final AppMode mode;

  const _AllSetStep({
    required this.isAr,
    required this.isDark,
    required this.language,
    required this.theme,
    required this.mode,
  });

  String get _modeLabel {
    switch (mode) {
      case AppMode.both:
        return isAr ? '✨ التطبيق كاملاً' : '✨ Full App';
      case AppMode.prayerOnly:
        return isAr ? '🕌 الصلاة فقط' : '🕌 Prayer Only';
      case AppMode.tasksOnly:
        return isAr ? '✅ المهام فقط' : '✅ Tasks Only';
    }
  }

  String get _themeLabel {
    switch (theme) {
      case 'light':
        return isAr ? '☀️ فاتح' : '☀️ Light';
      case 'dark':
        return isAr ? '🌙 داكن' : '🌙 Dark';
      default:
        return isAr ? '⚡ تلقائي' : '⚡ System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryItems = [
      _SummaryItem(
        isAr ? 'اللغة' : 'Language',
        language == 'ar' ? '🇸🇦 العربية' : '🇬🇧 English',
      ),
      _SummaryItem(isAr ? 'المظهر' : 'Theme', _themeLabel),
      _SummaryItem(isAr ? 'وضع التطبيق' : 'App Mode', _modeLabel),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppConstants.getPrimary(isDark), AppConstants.accentCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppConstants.getPrimary(isDark).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.check_rounded, size: 56, color: Colors.white),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),

          const SizedBox(height: 24),

          Text(
            isAr ? 'أنت مستعد! 🎉' : "You're All Set! 🎉",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 8),

          Text(
            isAr
                ? 'هالة جاهزة لتبدأ رحلتك.\nإليك ما اخترته:'
                : 'Aura is ready for your journey.\nHere\'s what you chose:',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: 28),

          // Summary cards
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
              ),
            ),
            child: Column(
              children: summaryItems.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          Text(
                            item.value,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < summaryItems.length - 1)
                      Divider(
                        height: 1,
                        color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                      ),
                  ],
                );
              }).toList(),
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          Text(
            isAr
                ? 'يمكنك تغيير أي من هذه الإعدادات لاحقاً من الملف الشخصي'
                : 'You can change any of these settings later from Profile',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String label, value;
  const _SummaryItem(this.label, this.value);
}

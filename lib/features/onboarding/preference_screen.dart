import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aura_button.dart';
import '../../core/services/rating_service.dart';
import '../../core/utils/app_language.dart';
import 'package:easy_localization/easy_localization.dart';

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
  bool _navigating = false;

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
            titleKey: 'onboarding_slide_prayer_1_title',
            subtitleKey: 'onboarding_slide_prayer_1_sub',
            features: [
              _Feature('⏰', 'onboarding_slide_prayer_1_f1'),
              _Feature('📍', 'onboarding_slide_prayer_1_f2'),
              _Feature('🔔', 'onboarding_slide_prayer_1_f3'),
            ],
          ),
          _Slide(
            emoji: '📿',
            color: const Color(0xFF00695C),
            titleKey: 'onboarding_slide_prayer_2_title',
            subtitleKey: 'onboarding_slide_prayer_2_sub',
            features: [
              _Feature('🧭', 'onboarding_slide_prayer_2_f1'),
              _Feature('📿', 'onboarding_slide_prayer_2_f2'),
              _Feature('🌙', 'onboarding_slide_prayer_2_f3'),
            ],
          ),
          _Slide(
            emoji: '📊',
            color: const Color(0xFF6A1B9A),
            titleKey: 'onboarding_slide_prayer_3_title',
            subtitleKey: 'onboarding_slide_prayer_3_sub',
            features: [
              _Feature('🔥', 'onboarding_slide_prayer_3_f1'),
              _Feature('📅', 'onboarding_slide_prayer_3_f2'),
              _Feature('🏆', 'onboarding_slide_prayer_3_f3'),
            ],
          ),
        ];

      case AppMode.tasksOnly:
        return [
          _Slide(
            emoji: '✅',
            color: const Color(0xFF2E7D32),
            titleKey: 'onboarding_slide_tasks_1_title',
            subtitleKey: 'onboarding_slide_tasks_1_sub',
            features: [
              _Feature('🎯', 'onboarding_slide_tasks_1_f1'),
              _Feature('📋', 'onboarding_slide_tasks_1_f2'),
              _Feature('📌', 'onboarding_slide_tasks_1_f3'),
            ],
          ),
          _Slide(
            emoji: '🎯',
            color: const Color(0xFFE65100),
            titleKey: 'onboarding_slide_tasks_2_title',
            subtitleKey: 'onboarding_slide_tasks_2_sub',
            features: [
              _Feature('🔒', 'onboarding_slide_tasks_2_f1'),
              _Feature('🔕', 'onboarding_slide_tasks_2_f2'),
              _Feature('⏱️', 'onboarding_slide_tasks_2_f3'),
            ],
          ),
          _Slide(
            emoji: '🏆',
            color: const Color(0xFF6A1B9A),
            titleKey: 'onboarding_slide_tasks_3_title',
            subtitleKey: 'onboarding_slide_tasks_3_sub',
            features: [
              _Feature('🔥', 'onboarding_slide_tasks_3_f1'),
              _Feature('🏅', 'onboarding_slide_tasks_3_f2'),
              _Feature('📈', 'onboarding_slide_tasks_3_f3'),
            ],
          ),
        ];

      case AppMode.both:
        return [
          _Slide(
            emoji: '✨',
            color: AppConstants.getPrimary(isDark),
            titleKey: 'onboarding_slide_full_1_title',
            subtitleKey: 'onboarding_slide_full_1_sub',
            features: [
              _Feature('🕌', 'onboarding_slide_full_1_f1'),
              _Feature('✅', 'onboarding_slide_full_1_f2'),
              _Feature('🏆', 'onboarding_slide_full_1_f3'),
            ],
          ),
          _Slide(
            emoji: '🌅',
            color: const Color(0xFFE65100),
            titleKey: 'onboarding_slide_full_2_title',
            subtitleKey: 'onboarding_slide_full_2_sub',
            features: [
              _Feature('⏰', 'onboarding_slide_full_2_f1'),
              _Feature('📋', 'onboarding_slide_full_2_f2'),
              _Feature('🎯', 'onboarding_slide_full_2_f3'),
            ],
          ),
          _Slide(
            emoji: '📈',
            color: const Color(0xFF2E7D32),
            titleKey: 'onboarding_slide_full_3_title',
            subtitleKey: 'onboarding_slide_full_3_sub',
            features: [
              _Feature('🔥', 'onboarding_slide_full_3_f1'),
              _Feature('📊', 'onboarding_slide_full_3_f2'),
              _Feature('🏅', 'onboarding_slide_full_3_f3'),
            ],
          ),
        ];
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next() {
    if (_navigating || _saving) return;
    if (_step == 3 && _carouselSlide < 2) {
      setState(() { _navigating = true; _carouselSlide++; });
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      Future.delayed(const Duration(milliseconds: 360), () {
        if (mounted) setState(() => _navigating = false);
      });
      return;
    }
    if (_step < _totalSteps - 1) {
      setState(() {
        _navigating = true;
        _step++;
        if (_step == 3) _carouselSlide = 0;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      Future.delayed(const Duration(milliseconds: 410), () {
        if (mounted) setState(() => _navigating = false);
      });
    } else {
      _finish();
    }
  }

  void _back() {
    if (_navigating || _saving) return;
    if (_step == 3 && _carouselSlide > 0) {
      setState(() { _navigating = true; _carouselSlide--; });
      _carouselController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      Future.delayed(const Duration(milliseconds: 360), () {
        if (mounted) setState(() => _navigating = false);
      });
      return;
    }
    if (_step > 0) {
      setState(() { _navigating = true; _step--; });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      Future.delayed(const Duration(milliseconds: 410), () {
        if (mounted) setState(() => _navigating = false);
      });
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      // Locale first, then the provider, so `.tr()` text follows (F61).
      await applyAppLanguage(
        _language,
        setLocale: context.setLocale,
        setLanguage: ref.read(languageProvider.notifier).setLanguage,
        isMounted: () => mounted,
      );
      if (mounted) {
        final ctx = context;
        ctx.findAncestorStateOfType<State>(); // ensure context valid
        await ref.read(themeModeProvider.notifier).setThemeMode(_theme);
        await ref.read(appModeProvider.notifier).setMode(_mode);
        await ref.read(firstLaunchProvider.notifier).setFirstLaunch(false);
        await RatingService.instance.recordInstallDateIfNeeded();
        // Request notification permission now — user has context after onboarding
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          await Permission.notification.request();
        }
        // result: true tells a waiting Login (guest flow) that onboarding
        // finished, so it keeps guest mode (F41a).
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home', result: true);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Button label ──────────────────────────────────────────────────────────
  String get _btnLabel {
    if (_step == 4) return 'onboarding_btn_lets_go'.tr();
    if (_step == 3 && _carouselSlide < 2) return 'onboarding_btn_next'.tr();
    return 'onboarding_btn_continue'.tr();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppConstants.background(isDark),
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
                            : (AppConstants.divider(isDark)),
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
                    onSelect: (v) {
                      setState(() => _language = v);
                      context.setLocale(Locale(v));
                    },
                  ),
                  _ThemeStep(
                    selected: _theme,
                    onSelect: (v) => setState(() => _theme = v),
                  ),
                  _ModeStep(
                    selected: _mode,
                    isDark: isDark,
                    onSelect: (v) => setState(() => _mode = v),
                  ),
                  _CarouselStep(
                    slides: _slides,
                    currentSlide: _carouselSlide,
                    controller: _carouselController,
                    isDark: isDark,
                    onSlideChanged: (i) => setState(() => _carouselSlide = i),
                  ),
                  _AllSetStep(
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
                  AuraButton(
                    label: _btnLabel,
                    onPressed: _next,
                    loading: _saving,
                    expanded: true,
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: 4),
                    AuraButton.ghost(
                      label: 'onboarding_btn_back'.tr(),
                      onPressed: _back,
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _saving ? null : _finish,
                      child: Text(
                        'onboarding_btn_skip'.tr(),
                        style: AppTypography.bodyM.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
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
            style: AppTypography.label.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
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
              : (AppConstants.card(isDark)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppConstants.getPrimary(isDark)
                : (AppConstants.border(isDark)),
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
                    style: AppTypography.headingS.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppConstants.getPrimary(isDark) : null,
                    ),
                  ),
                  Text(
                    sub,
                    style: AppTypography.bodyS.copyWith(
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
  final ValueChanged<String> onSelect;
  const _ThemeStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [
      _ThemeOpt('light', Icons.light_mode_rounded,
          'onboarding_theme_light_label'.tr(), 'onboarding_theme_light_sub'.tr(), Colors.orange),
      _ThemeOpt('dark', Icons.dark_mode_rounded,
          'onboarding_theme_dark_label'.tr(), 'onboarding_theme_dark_sub'.tr(), Colors.indigo),
      _ThemeOpt('system', Icons.brightness_auto_rounded,
          'onboarding_theme_system_label'.tr(), 'onboarding_theme_system_sub'.tr(), AppConstants.getPrimary(isDark)),
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
            'onboarding_theme_title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            'onboarding_theme_subtitle'.tr(),
            style: AppTypography.label.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
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
                        : (AppConstants.card(isDark)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? opt.color
                          : (AppConstants.border(isDark)),
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
                              style: AppTypography.bodyL.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? opt.color : null,
                              ),
                            ),
                            Text(
                              opt.sub,
                              style: AppTypography.caption.copyWith(
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
  final bool isDark;
  final ValueChanged<AppMode> onSelect;
  const _ModeStep({
    required this.selected,
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
        labelKey: 'onboarding_mode_full_label',
        subKey: 'onboarding_mode_full_sub',
        badgeKey: 'onboarding_mode_full_badge',
      ),
      _ModeOpt(
        mode: AppMode.prayerOnly,
        emoji: '🕌',
        color: const Color(0xFF1565C0),
        labelKey: 'onboarding_mode_prayer_label',
        subKey: 'onboarding_mode_prayer_sub',
      ),
      _ModeOpt(
        mode: AppMode.tasksOnly,
        emoji: '✅',
        color: const Color(0xFF2E7D32),
        labelKey: 'onboarding_mode_tasks_label',
        subKey: 'onboarding_mode_tasks_sub',
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
            'onboarding_mode_title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            'onboarding_mode_subtitle'.tr(),
            style: AppTypography.label.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
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
                        : (AppConstants.card(isDark)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? opt.color
                          : (AppConstants.border(isDark)),
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
                                  opt.labelKey.tr(),
                                  style: AppTypography.bodyL.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? opt.color : null,
                                  ),
                                ),
                                if (opt.badgeKey != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: opt.color,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      opt.badgeKey!.tr(),
                                      style: AppTypography.caption.copyWith(
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
                              opt.subKey.tr(),
                              style: AppTypography.caption.copyWith(
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
  final String emoji, labelKey, subKey;
  final String? badgeKey;
  final Color color;
  const _ModeOpt({
    required this.mode,
    required this.emoji,
    required this.color,
    required this.labelKey,
    required this.subKey,
    this.badgeKey,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 3 — Feature Carousel
// ═══════════════════════════════════════════════════════════════════════════
class _CarouselStep extends StatelessWidget {
  final List<_Slide> slides;
  final int currentSlide;
  final PageController controller;
  final bool isDark;
  final ValueChanged<int> onSlideChanged;

  const _CarouselStep({
    required this.slides,
    required this.currentSlide,
    required this.controller,
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
  final bool isDark;
  const _SlideView({required this.slide, required this.isDark});

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
            slide.titleKey.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: slide.color,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 8),

          Text(
            slide.subtitleKey.tr(),
            style: AppTypography.headingS.copyWith(
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
                        f.textKey.tr(),
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textPrimary(isDark),
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
  final String emoji, titleKey, subtitleKey;
  final Color color;
  final List<_Feature> features;
  const _Slide({
    required this.emoji,
    required this.color,
    required this.titleKey,
    required this.subtitleKey,
    required this.features,
  });
}

class _Feature {
  final String emoji, textKey;
  const _Feature(this.emoji, this.textKey);
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 4 — You're All Set
// ═══════════════════════════════════════════════════════════════════════════
class _AllSetStep extends StatelessWidget {
  final bool isDark;
  final String language, theme;
  final AppMode mode;

  const _AllSetStep({
    required this.isDark,
    required this.language,
    required this.theme,
    required this.mode,
  });

  String get _modeLabel {
    switch (mode) {
      case AppMode.both:        return 'onboarding_summary_mode_full'.tr();
      case AppMode.prayerOnly:  return 'onboarding_summary_mode_prayer'.tr();
      case AppMode.tasksOnly:   return 'onboarding_summary_mode_tasks'.tr();
    }
  }

  String get _themeLabel {
    switch (theme) {
      case 'light':   return 'onboarding_summary_theme_light'.tr();
      case 'dark':    return 'onboarding_summary_theme_dark'.tr();
      default:        return 'onboarding_summary_theme_system'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryItems = [
      _SummaryItem(
        'onboarding_summary_language_label'.tr(),
        language == 'ar' ? '🇸🇦 العربية' : '🇬🇧 English',
      ),
      _SummaryItem('onboarding_summary_theme_label'.tr(), _themeLabel),
      _SummaryItem('onboarding_summary_mode_label'.tr(), _modeLabel),
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
            'onboarding_allset_title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 8),

          Text(
            'onboarding_allset_subtitle'.tr(),
            style: AppTypography.headingS.copyWith(
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
              color: AppConstants.card(isDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppConstants.border(isDark),
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
                            style: AppTypography.label.copyWith(
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          Text(
                            item.value,
                            style: AppTypography.label.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < summaryItems.length - 1)
                      Divider(
                        height: 1,
                        color: AppConstants.border(isDark),
                      ),
                  ],
                );
              }).toList(),
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          Text(
            'onboarding_allset_footer'.tr(),
            style: AppTypography.caption.copyWith(
              color: AppConstants.textDisabled(isDark),
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

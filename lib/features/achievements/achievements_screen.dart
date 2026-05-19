import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/achievement.dart';
import '../../core/models/prayer_record.dart';
import '../../core/services/achievement_service.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_typography.dart';

/// Achievements Screen - Grid of badges (earned and locked)
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  final AchievementService _achievementService = AchievementService.instance;
  bool _isLoading = true;
  List<Achievement> _earnedAchievements = [];
  int _totalAchievements = 0;
  final Set<AchievementCategory> _collapsedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);

    try {
      final userId = getCurrentUserId();
      final earned = await _achievementService.getEarnedAchievements(userId: userId);

      if (mounted) {
        setState(() {
          _earnedAchievements = earned;
          _totalAchievements = AchievementDefinitions.all.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final earnedIds = _earnedAchievements.map((a) => a.id).toSet();
    final appMode = ref.watch(appModeProvider);
    final visibleCategories = AchievementCategory.values.where((c) {
      if (appMode == AppMode.tasksOnly) return c == AchievementCategory.tasks;
      if (appMode == AppMode.prayerOnly) return c != AchievementCategory.tasks;
      return true;
    }).toSet();
    final visibleTotal = AchievementDefinitions.all
        .where((a) => visibleCategories.contains(a.category))
        .length;
    final earnedCount = _earnedAchievements
        .where((a) => visibleCategories.contains(a.category))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الإنجازات' : 'Achievements'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAchievements,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Summary header
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(AppConstants.paddingMedium),
                      padding: const EdgeInsets.all(AppConstants.paddingLarge),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppConstants.getPrimary(isDark),
                            AppConstants.getPrimary(isDark).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic ? 'إنجازاتك' : 'Your Achievements',
                                  style: AppTypography.headingM.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isArabic
                                      ? '${NumberFormatter.withArabicNumerals('$earnedCount')} من ${NumberFormatter.withArabicNumerals('$visibleTotal')} مكتمل'
                                      : '$earnedCount of $visibleTotal unlocked',
                                  style: AppTypography.label.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${NumberFormatter.withArabicNumeralsByLanguage('$earnedCount', isArabic ? 'ar' : 'en')}/${NumberFormatter.withArabicNumeralsByLanguage('$visibleTotal', isArabic ? 'ar' : 'en')}',
                            style: AppTypography.displayM.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Group by category — filter based on app mode
                  ...AchievementCategory.values.map((category) {
                    if (!visibleCategories.contains(category)) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    final achievements = AchievementDefinitions.all
                        .where((a) => a.category == category)
                        .toList();

                    if (achievements.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                    final categoryNames = {
                      AchievementCategory.streaks: isArabic ? 'التتابعات' : 'Streaks',
                      AchievementCategory.consistency: isArabic ? 'الالتزام' : 'Consistency',
                      AchievementCategory.dhikr: isArabic ? 'الأذكار' : 'Zikr',
                      AchievementCategory.tasks: isArabic ? 'المهام' : 'Tasks',
                      AchievementCategory.quran: isArabic ? 'القرآن' : 'Quran',
                      AchievementCategory.special: isArabic ? 'خاص' : 'Special',
                    };

                    final isCollapsed = _collapsedCategories.contains(category);
                    final earnedInCategory = achievements.where((a) => earnedIds.contains(a.id)).length;

                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => setState(() {
                              if (isCollapsed) {
                                _collapsedCategories.remove(category);
                              } else {
                                _collapsedCategories.add(category);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.paddingMedium,
                                vertical: AppConstants.paddingSmall,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      categoryNames[category] ?? '',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isArabic
                                        ? '${NumberFormatter.withArabicNumerals('$earnedInCategory')}/${NumberFormatter.withArabicNumerals('${achievements.length}')}'
                                        : '$earnedInCategory/${achievements.length}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: isCollapsed ? 0 : 0.5,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.expand_more,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: isCollapsed
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: achievements.map((achievement) {
                                        final isEarned = earnedIds.contains(achievement.id);
                                        return _AchievementBadge(
                                          achievement: achievement,
                                          isEarned: isEarned,
                                          isArabic: isArabic,
                                          isDark: isDark,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: AppConstants.paddingMedium),
                        ],
                      ),
                    );
                  }),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool isEarned;
  final bool isArabic;
  final bool isDark;

  const _AchievementBadge({
    required this.achievement,
    required this.isEarned,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - AppConstants.paddingMedium * 2 - 8 * 2) / 3,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEarned
            ? AppConstants.getPrimary(isDark).withOpacity(0.1)
            : (AppConstants.card(isDark)),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isEarned
              ? AppConstants.getPrimary(isDark).withOpacity(0.5)
              : (AppConstants.border(isDark)),
        ),
      ),
      child: Column(
        children: [
          Text(
            achievement.iconEmoji,
            style: TextStyle(
              fontSize: 24,
              color: isEarned ? null : (AppConstants.divider(isDark)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.name(isArabic),
            style: AppTypography.labelS.copyWith(
              fontWeight: FontWeight.bold,
              color: isEarned
                  ? (AppConstants.textPrimary(isDark))
                  : (isDark ? Colors.white24 : Colors.black26),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description(isArabic),
            style: AppTypography.caption.copyWith(
              fontSize: 9,
              color: isEarned
                  ? (isDark ? Colors.white60 : Colors.black54)
                  : (AppConstants.divider(isDark)),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isEarned) ...[
            const SizedBox(height: 3),
            Icon(Icons.check_circle, color: AppConstants.getPrimary(isDark), size: 14),
          ],
        ],
      ),
    );
  }
}

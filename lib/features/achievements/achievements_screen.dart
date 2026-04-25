import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/achievement.dart';
import '../../core/models/prayer_record.dart';
import '../../core/services/achievement_service.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/providers/preferences_provider.dart';

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
    final earnedCount = _earnedAchievements.length;

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
                            AppConstants.primaryColor,
                            AppConstants.primaryColor.withOpacity(0.7),
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
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isArabic
                                      ? '${NumberFormatter.withArabicNumerals('$earnedCount')} من ${NumberFormatter.withArabicNumerals('$_totalAchievements')} مكتمل'
                                      : '$earnedCount of $_totalAchievements unlocked',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${NumberFormatter.withArabicNumeralsByLanguage('$earnedCount', isArabic ? 'ar' : 'en')}/${NumberFormatter.withArabicNumeralsByLanguage('$_totalAchievements', isArabic ? 'ar' : 'en')}',
                            style: const TextStyle(
                              fontSize: 32,
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
                    final appMode = ref.watch(appModeProvider);
                    final showPrayer = appMode != AppMode.tasksOnly;
                    final showTasks = appMode != AppMode.prayerOnly;

                    // Hide prayer categories in Tasks Only mode
                    if (!showPrayer && (category == AchievementCategory.streaks ||
                        category == AchievementCategory.consistency ||
                        category == AchievementCategory.dhikr ||
                        category == AchievementCategory.special)) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    // Hide task category in Prayer Only mode
                    if (!showTasks && category == AchievementCategory.tasks) {
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
                      AchievementCategory.special: isArabic ? 'خاص' : 'Special',
                    };

                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.paddingMedium,
                              vertical: AppConstants.paddingSmall,
                            ),
                            child: Text(
                              categoryNames[category] ?? '',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
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
      width: (MediaQuery.of(context).size.width - AppConstants.paddingMedium * 2 - 10) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEarned
            ? AppConstants.primaryColor.withOpacity(0.1)
            : (isDark ? AppConstants.darkCard : AppConstants.lightCard),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isEarned
              ? AppConstants.primaryColor.withOpacity(0.5)
              : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
        ),
      ),
      child: Column(
        children: [
          Text(
            achievement.iconEmoji,
            style: TextStyle(
              fontSize: 32,
              color: isEarned ? null : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.name(isArabic),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isEarned
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white24 : Colors.black26),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description(isArabic),
            style: TextStyle(
              fontSize: 10,
              color: isEarned
                  ? (isDark ? Colors.white60 : Colors.black54)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isEarned) ...[
            const SizedBox(height: 4),
            Icon(Icons.check_circle, color: AppConstants.primaryColor, size: 16),
          ],
        ],
      ),
    );
  }
}

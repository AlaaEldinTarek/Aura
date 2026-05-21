import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../providers/task_provider.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_typography.dart';

/// Custom bottom navigation bar for the app
class AuraBottomNavBar extends ConsumerWidget {
  static final navBarKey = GlobalKey();

  final int currentIndex;
  final ValueChanged<int> onTap;

  const AuraBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final appMode = ref.watch(appModeProvider);

    // Show overdue count as red badge on Tasks tab
    final overdueCount = ref.watch(allTasksProvider).whenOrNull(
          data: (tasks) =>
              tasks.where((t) => !t.isCompleted && t.isOverdue).length,
        ) ?? 0;

    // Build nav items based on mode
    final showPrayer = appMode != AppMode.tasksOnly;
    final showQuran = appMode == AppMode.both || appMode == AppMode.prayerOnly;
    final showTasks = appMode != AppMode.prayerOnly;

    final ts = MediaQuery.textScalerOf(context);
    return Container(
      key: navBarKey,
      decoration: BoxDecoration(
        color: AppConstants.surface(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: ts.scale(65.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.home_outlined,
                label: 'home'.tr(),
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              if (showPrayer)
                _buildNavItem(
                  context: context,
                  icon: Icons.mosque_outlined,
                  label: 'prayer_times_title'.tr(),
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              if (showQuran)
                _buildNavItem(
                  context: context,
                  icon: Icons.menu_book_outlined,
                  label: 'quran'.tr(),
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
              if (showTasks)
                _buildNavItem(
                  context: context,
                  icon: Icons.task_alt_outlined,
                  label: 'tasks_nav'.tr(),
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                  badge: overdueCount,
                ),
              _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                label: 'profile'.tr(),
                isSelected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isComingSoon = false,
    int badge = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        enabled: !isComingSoon,
        child: InkWell(
          onTap: isComingSoon
              ? null
              : () {
                  debugPrint('🔵 [NavBar] Nav item tapped: $label');
                  onTap();
                },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
          padding: EdgeInsets.symmetric(vertical: isComingSoon ? 6 : 8),
          child: Builder(builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          final ts = mq.textScaler;
          final cappedScale = ts.scale(1.0).clamp(0.9, 1.3);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(cappedScale)),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with optional badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: ts.scale(24.0),
                    color: isSelected
                        ? AppConstants.getPrimary(isDark)
                        : (AppConstants.textSecondary(isDark)),
                  ),
                  Positioned(
                    right: -8,
                    top: -4,
                    child: AnimatedScale(
                      scale: badge > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.elasticOut,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: ts.scale(4.0)),
                        constraints: BoxConstraints(minWidth: ts.scale(16.0), minHeight: ts.scale(16.0)),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              '$badge',
                              key: ValueKey(badge),
                              style: AppTypography.caption.copyWith(
                                fontSize: ts.scale(9.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textScaler: TextScaler.noScaling,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isComingSoon ? 1 : 2),
              Text(
                label,
                style: AppTypography.labelS.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppConstants.getPrimary(isDark)
                      : (AppConstants.textSecondary(isDark)),
                ),
              ),
              if (isComingSoon)
                Container(
                  margin: EdgeInsets.only(top: ts.scale(1.0)),
                  padding: EdgeInsets.symmetric(horizontal: ts.scale(4.0)),
                  decoration: BoxDecoration(
                    color: AppConstants.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'coming_soon'.tr(),
                    style: AppTypography.caption.copyWith(
                      fontSize: ts.scale(7.0),
                      fontWeight: FontWeight.bold,
                      color: AppConstants.warning,
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
            ],
          ),
          );
          }),
        ),
      ),
      ),
    );
  }
}

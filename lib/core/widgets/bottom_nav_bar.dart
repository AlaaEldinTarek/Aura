import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../providers/task_provider.dart';
import '../providers/preferences_provider.dart';

/// Custom bottom navigation bar for the app
class AuraBottomNavBar extends ConsumerWidget {
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
    final showQuran = appMode == AppMode.both;
    final showTasks = appMode != AppMode.prayerOnly;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
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
          height: 65,
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
                  label: 'task_management'.tr(),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with optional badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? AppConstants.getPrimary(isDark)
                        : (isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$badge',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppConstants.getPrimary(isDark)
                      : (isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary),
                ),
              ),
              if (isComingSoon)
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'coming_soon'.tr(),
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

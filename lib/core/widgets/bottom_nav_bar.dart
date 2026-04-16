import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
/// Custom bottom navigation bar for the app
/// Provides navigation between main sections
class AuraBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AuraBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : Colors.white,
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
              _buildNavItem(
                context: context,
                icon: Icons.mosque_outlined,
                label: 'prayer_times_title'.tr(),
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _buildNavItem(
                context: context,
                icon: Icons.task_alt_outlined,
                label: 'task_management'.tr(),
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                label: 'profile'.tr(),
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
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
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? AppConstants.primaryColor
                    : (isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary),
              ),
              SizedBox(height: isComingSoon ? 1 : 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppConstants.primaryColor
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

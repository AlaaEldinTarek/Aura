import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import 'adhan_calculation_method.dart';
import 'asr_madhab_selection.dart';

/// Prayer calculation settings dialog
/// Allows user to select prayer calculation method and Asr madhab
class PrayerCalculationSettingsDialog extends StatelessWidget {
  final String currentMethod;
  final String currentMadhab;
  final Function(String) onMethodChanged;
  final Function(String) onMadhabChanged;

  const PrayerCalculationSettingsDialog({
    super.key,
    required this.currentMethod,
    required this.currentMadhab,
    required this.onMethodChanged,
    required this.onMadhabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  color: AppConstants.getPrimary(isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isArabic ? 'حساب أوقات الصلاة' : 'Prayer Calculation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            // Calculation Method Section
            _buildSectionHeader(
              context,
              isArabic ? 'طريقة الحساب' : 'Calculation Method',
              Icons.settings_suggest,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            ...AdhanCalculationMethod.values.map((method) {
              final isSelected = currentMethod == method.value;
              return ListTile(
                leading: Radio<String>(
                  value: method.value,
                  groupValue: currentMethod,
                  activeColor: AppConstants.getPrimary(isDark),
                  onChanged: (value) {
                    if (value != null) {
                      onMethodChanged(value);
                    }
                  },
                ),
                title: Text(
                  method.getLocalizedName(isArabic),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: method.description.isNotEmpty
                    ? Text(
                        method.getLocalizedName(isArabic, showDescription: true),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      )
                    : null,
                onTap: () {
                  onMethodChanged(method.value);
                },
              );
            }).toList(),

            const SizedBox(height: AppConstants.paddingLarge),

            // Asr Madhab Section
            _buildSectionHeader(
              context,
              isArabic ? 'مذهب العصر' : 'Asr Madhab',
              Icons.mosque_outlined,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            ...AsrMadhab.values.map((madhab) {
              final isSelected = currentMadhab == madhab.value;
              return ListTile(
                leading: Radio<String>(
                  value: madhab.value,
                  groupValue: currentMadhab,
                  activeColor: AppConstants.getPrimary(isDark),
                  onChanged: (value) {
                    if (value != null) {
                      onMadhabChanged(value);
                    }
                  },
                ),
                title: Text(
                  madhab.getLocalizedName(isArabic),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: madhab.description.isNotEmpty
                    ? Text(
                        madhab.getLocalizedName(isArabic, showDescription: true),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      )
                    : null,
                onTap: () {
                  onMadhabChanged(madhab.value);
                },
              );
            }).toList(),

            const SizedBox(height: AppConstants.paddingLarge),

            // Apply Button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.getPrimary(isDark),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isArabic ? 'تم' : 'Done',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 20, color: AppConstants.getPrimary(isDark)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
        ),
      ],
    );
  }

  /// Show the dialog
  static Future<void> show({
    required BuildContext context,
    required String currentMethod,
    required String currentMadhab,
    required Function(String) onMethodChanged,
    required Function(String) onMadhabChanged,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => PrayerCalculationSettingsDialog(
        currentMethod: currentMethod,
        currentMadhab: currentMadhab,
        onMethodChanged: onMethodChanged,
        onMadhabChanged: onMadhabChanged,
      ),
    );
  }
}

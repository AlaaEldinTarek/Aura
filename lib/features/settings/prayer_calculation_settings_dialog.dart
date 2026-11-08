import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aura_button.dart';
import 'adhan_calculation_method.dart';
import 'asr_madhab_selection.dart';

/// Prayer calculation settings dialog
/// Allows user to select prayer calculation method and Asr madhab
class PrayerCalculationSettingsDialog extends StatefulWidget {
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
  State<PrayerCalculationSettingsDialog> createState() =>
      _PrayerCalculationSettingsDialogState();

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

class _PrayerCalculationSettingsDialogState
    extends State<PrayerCalculationSettingsDialog> {
  // The current selection, held locally so a tapped option shows as selected
  // right away (F49j).
  late String _method = widget.currentMethod;
  late String _madhab = widget.currentMadhab;

  void _selectMethod(String value) {
    setState(() => _method = value);
    widget.onMethodChanged(value);
  }

  void _selectMadhab(String value) {
    setState(() => _madhab = value);
    widget.onMadhabChanged(value);
  }

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

            // Method and madhab sections scroll when they do not fit (F49c);
            // header and Done button stay fixed.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Calculation Method Section
                    _buildSectionHeader(
                      context,
                      isArabic ? 'طريقة الحساب' : 'Calculation Method',
                      Icons.settings_suggest,
                    ),
                    const SizedBox(height: AppConstants.paddingSmall),
                    ...AdhanCalculationMethod.values.map((method) {
                      final isSelected = _method == method.value;
                      return ListTile(
                        leading: Radio<String>(
                          value: method.value,
                          groupValue: _method,
                          activeColor: AppConstants.getPrimary(isDark),
                          onChanged: (value) {
                            if (value != null) {
                              _selectMethod(value);
                            }
                          },
                        ),
                        title: Text(
                          method.getLocalizedName(isArabic),
                          style: AppTypography.bodyM.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: method.description.isNotEmpty
                            ? Text(
                                method.getLocalizedName(isArabic,
                                    showDescription: true),
                                style: AppTypography.caption.copyWith(
                                  color: AppConstants.textMuted(isDark),
                                ),
                              )
                            : null,
                        onTap: () {
                          _selectMethod(method.value);
                        },
                      );
                    }),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Asr Madhab Section
                    _buildSectionHeader(
                      context,
                      isArabic ? 'مذهب العصر' : 'Asr Madhab',
                      Icons.mosque_outlined,
                    ),
                    const SizedBox(height: AppConstants.paddingSmall),
                    ...AsrMadhab.values.map((madhab) {
                      final isSelected = _madhab == madhab.value;
                      return ListTile(
                        leading: Radio<String>(
                          value: madhab.value,
                          groupValue: _madhab,
                          activeColor: AppConstants.getPrimary(isDark),
                          onChanged: (value) {
                            if (value != null) {
                              _selectMadhab(value);
                            }
                          },
                        ),
                        title: Text(
                          madhab.getLocalizedName(isArabic),
                          style: AppTypography.bodyM.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: madhab.description.isNotEmpty
                            ? Text(
                                madhab.getLocalizedName(isArabic,
                                    showDescription: true),
                                style: AppTypography.caption.copyWith(
                                  color: AppConstants.textMuted(isDark),
                                ),
                              )
                            : null,
                        onTap: () {
                          _selectMadhab(madhab.value);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            // Apply Button
            AuraButton(
              label: isArabic ? 'تم' : 'Done',
              onPressed: () => Navigator.pop(context),
              expanded: true,
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
                color: AppConstants.textPrimary(isDark),
              ),
        ),
      ],
    );
  }
}

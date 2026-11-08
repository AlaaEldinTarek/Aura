import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aura_button.dart';
import 'adhan_calculation_method.dart';

/// Prayer calculation method dialog: the 12 methods only (F57).
///
/// A tap only moves the radio; "Done" closes and returns the chosen
/// [AdhanCalculationMethod.value]; close (X) or back returns null.
class CalculationMethodDialog extends StatefulWidget {
  final String currentMethod;

  const CalculationMethodDialog({super.key, required this.currentMethod});

  @override
  State<CalculationMethodDialog> createState() =>
      _CalculationMethodDialogState();

  /// Shows the dialog; the chosen value on "Done", null otherwise.
  static Future<String?> show(
    BuildContext context, {
    required String currentMethod,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          CalculationMethodDialog(currentMethod: currentMethod),
    );
  }
}

class _CalculationMethodDialogState extends State<CalculationMethodDialog> {
  late String _method = widget.currentMethod;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primary = AppConstants.getPrimary(isDark);

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
            Row(
              children: [
                Icon(Icons.settings_suggest, color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'prayer_calc_method_title'.tr(),
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
            // The list scrolls when it does not fit (F49c); header and Done
            // stay fixed.
            Flexible(
              child: SingleChildScrollView(
                child: RadioGroup<String>(
                  groupValue: _method,
                  onChanged: (value) {
                    if (value != null) setState(() => _method = value);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: AdhanCalculationMethod.values.map((method) {
                      final isSelected = _method == method.value;
                      return ListTile(
                        leading: Radio<String>(
                          value: method.value,
                          activeColor: primary,
                        ),
                        title: Text(
                          method.getLocalizedName(isArabic),
                          style: AppTypography.bodyM.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                        onTap: () => setState(() => _method = method.value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            AuraButton(
              label: 'prayer_calc_done'.tr(),
              onPressed: () => Navigator.pop(context, _method),
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

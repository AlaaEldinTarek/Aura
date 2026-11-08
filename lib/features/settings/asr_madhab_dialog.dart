import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aura_button.dart';
import 'asr_madhab_selection.dart';

/// Asr madhab dialog: Shafi / Hanafi only (F57).
///
/// A tap only moves the radio; "Done" closes and returns the chosen
/// [AsrMadhab.value]; close (X) or back returns null.
class AsrMadhabDialog extends StatefulWidget {
  final String currentMadhab;

  const AsrMadhabDialog({super.key, required this.currentMadhab});

  @override
  State<AsrMadhabDialog> createState() => _AsrMadhabDialogState();

  /// Shows the dialog; the chosen value on "Done", null otherwise.
  static Future<String?> show(
    BuildContext context, {
    required String currentMadhab,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AsrMadhabDialog(currentMadhab: currentMadhab),
    );
  }
}

class _AsrMadhabDialogState extends State<AsrMadhabDialog> {
  late String _madhab = widget.currentMadhab;

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
                Icon(Icons.mosque_outlined, color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'prayer_asr_madhab_title'.tr(),
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
            Flexible(
              child: SingleChildScrollView(
                child: RadioGroup<String>(
                  groupValue: _madhab,
                  onChanged: (value) {
                    if (value != null) setState(() => _madhab = value);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: AsrMadhab.values.map((madhab) {
                      final isSelected = _madhab == madhab.value;
                      return ListTile(
                        leading: Radio<String>(
                          value: madhab.value,
                          activeColor: primary,
                        ),
                        title: Text(
                          madhab.getLocalizedName(isArabic),
                          style: AppTypography.bodyM.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                        onTap: () => setState(() => _madhab = madhab.value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            AuraButton(
              label: 'prayer_calc_done'.tr(),
              onPressed: () => Navigator.pop(context, _madhab),
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

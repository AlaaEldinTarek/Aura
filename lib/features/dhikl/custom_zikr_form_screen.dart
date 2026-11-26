import 'dart:ui' as ui show TextDirection;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aura_button.dart';
import '../../core/models/dhikr.dart';

/// Full-screen form for adding or editing a custom Zikr
class CustomZikrFormScreen extends StatefulWidget {
  final DhikrPreset? existingPreset;

  const CustomZikrFormScreen({super.key, this.existingPreset});

  @override
  State<CustomZikrFormScreen> createState() => _CustomZikrFormScreenState();
}

class _CustomZikrFormScreenState extends State<CustomZikrFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _arabicController;
  late final TextEditingController _transliterationController;
  late final TextEditingController _translationController;
  late final TextEditingController _targetController;
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.existingPreset != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPreset;
    _nameController = TextEditingController(text: p?.name ?? '');
    _arabicController = TextEditingController(text: p?.arabicText ?? '');
    _transliterationController = TextEditingController(text: p?.transliteration ?? '');
    _translationController = TextEditingController(text: p?.translation ?? '');
    _targetController = TextEditingController(text: (p?.defaultTarget ?? 33).toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _arabicController.dispose();
    _transliterationController.dispose();
    _translationController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final arabicText = _arabicController.text.trim();
    final transliteration = _transliterationController.text.trim();
    final translation = _translationController.text.trim();
    final target = int.parse(_targetController.text.trim());

    if (_isEditing) {
      final updated = DhikrPreset(
        id: widget.existingPreset!.id,
        name: name,
        arabicText: arabicText,
        transliteration: transliteration,
        translation: translation,
        defaultTarget: target,
      );
      Navigator.pop(context, updated);
    } else {
      final created = DhikrPreset(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        arabicText: arabicText,
        transliteration: transliteration,
        translation: translation,
        defaultTarget: target,
      );
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'dhikr_edit_title'.tr() : 'dhikr_add_custom'.tr()),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              'save'.tr(),
              style: AppTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview card
              _buildPreviewCard(isDark),
              const SizedBox(height: AppConstants.paddingLarge),

              // Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'dhikr_field_name'.tr(),
                  hintText: 'dhikr_field_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.label_outline),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'dhikr_field_required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Arabic text
              TextFormField(
                controller: _arabicController,
                textDirection: ui.TextDirection.rtl,
                style: AppTypography.headingM,
                decoration: InputDecoration(
                  labelText: 'dhikr_field_arabic'.tr(),
                  hintText: 'dhikr_field_arabic_hint'.tr(),
                  prefixIcon: const Icon(Icons.translate),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Transliteration
              TextFormField(
                controller: _transliterationController,
                decoration: InputDecoration(
                  labelText: 'dhikr_field_transliteration'.tr(),
                  hintText: 'dhikr_field_transliteration_hint'.tr(),
                  prefixIcon: const Icon(Icons.record_voice_over_outlined),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Translation
              TextFormField(
                controller: _translationController,
                decoration: InputDecoration(
                  labelText: 'dhikr_field_translation'.tr(),
                  hintText: 'dhikr_field_translation_hint'.tr(),
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppConstants.paddingLarge),

              // Target count
              Text(
                'dhikr_field_target'.tr(),
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textMuted(isDark),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.filter_7),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final num = int.tryParse(value ?? '');
                  if (num == null || num <= 0) {
                    return 'dhikr_field_target_invalid'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Quick pick chips
              Text(
                'dhikr_quick_pick'.tr(),
                style: AppTypography.caption.copyWith(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [33, 99, 100, 333, 500, 1000].map((val) {
                  final selected = _targetController.text == val.toString();
                  return ChoiceChip(
                    label: Text('$val'),
                    selected: selected,
                    selectedColor: AppConstants.getPrimary(isDark).withOpacity(0.2),
                    onSelected: (_) {
                      setState(() {
                        _targetController.text = val.toString();
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: AppConstants.paddingXLarge),

              // Save button
              AuraButton(
                label: _isEditing ? 'dhikr_save_changes'.tr() : 'dhikr_add_zikr'.tr(),
                onPressed: _save,
                expanded: true,
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark) {
    final name = _nameController.text.trim();
    final arabicText = _arabicController.text.trim();
    final translation = _translationController.text.trim();
    final target = int.tryParse(_targetController.text.trim()) ?? 33;

    final displayText = arabicText.isNotEmpty ? arabicText : (name.isEmpty ? '?' : name);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.card(isDark),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppConstants.getPrimary(isDark).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'dhikr_preview'.tr(),
            style: AppTypography.labelS.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppConstants.getPrimary(isDark).withOpacity(0.15),
                child: arabicText.isNotEmpty
                    ? Text(
                        arabicText[0],
                        style: AppTypography.headingS.copyWith(
                          color: AppConstants.getPrimary(isDark),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(Icons.edit_note, color: AppConstants.getPrimary(isDark)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayText,
                      style: AppTypography.headingM.copyWith(
                        fontSize: arabicText.isNotEmpty ? 22 : 16,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary(isDark),
                      ),
                    ),
                    if (translation.isNotEmpty)
                      Text(
                        translation,
                        style: AppTypography.caption.copyWith(
                          color: AppConstants.textMuted(isDark),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$target',
                    style: AppTypography.headingS.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.getPrimary(isDark),
                    ),
                  ),
                  Text(
                    'dhikr_target_suffix'.tr(),
                    style: AppTypography.caption.copyWith(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isArabic ? 'تعديل الذكر' : 'Edit Zikr')
              : (isArabic ? 'إضافة ذكر مخصص' : 'Add Custom Zikr'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              isArabic ? 'حفظ' : 'Save',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              _buildPreviewCard(isDark, isArabic),
              const SizedBox(height: AppConstants.paddingLarge),

              // Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الاسم' : 'Name *',
                  hintText: isArabic ? 'مثال: صلاة على النبي' : 'e.g., Salawat',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isArabic ? 'مطلوب' : 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Arabic text
              TextFormField(
                controller: _arabicController,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: isArabic ? 'النص العربي' : 'Arabic Text',
                  hintText: isArabic ? 'مثال: اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ' : 'e.g., اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
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
                  labelText: isArabic ? 'النطق' : 'Transliteration',
                  hintText: isArabic ? 'اختياري' : 'e.g., Allahumma salli ala Muhammad',
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
                  labelText: isArabic ? 'الترجمة' : 'Translation',
                  hintText: isArabic ? 'اختياري' : 'e.g., O Allah send blessings upon Muhammad',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppConstants.paddingLarge),

              // Target count
              Text(
                isArabic ? 'العدد المستهدف' : 'Target Count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                    return isArabic ? 'أدخل رقماً صحيحاً' : 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Quick pick chips
              Text(
                isArabic ? 'اختيار سريع:' : 'Quick pick:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                    selectedColor: AppConstants.primaryColor.withOpacity(0.2),
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
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
                child: Text(
                  _isEditing
                      ? (isArabic ? 'حفظ التعديلات' : 'Save Changes')
                      : (isArabic ? 'إضافة الذكر' : 'Add Zikr'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark, bool isArabic) {
    final name = _nameController.text.trim();
    final arabicText = _arabicController.text.trim();
    final translation = _translationController.text.trim();
    final target = int.tryParse(_targetController.text.trim()) ?? 33;

    final displayText = arabicText.isNotEmpty ? arabicText : (name.isEmpty ? '?' : name);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            isArabic ? 'معاينة' : 'Preview',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                child: arabicText.isNotEmpty
                    ? Text(
                        arabicText[0],
                        style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(Icons.edit_note, color: AppConstants.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: arabicText.isNotEmpty ? 22 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (translation.isNotEmpty)
                      Text(
                        translation,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  Text(
                    isArabic ? 'هدف' : 'target',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/dhikr.dart';
import '../../core/models/prayer_record.dart';
import '../../core/services/dhikr_service.dart';
import 'custom_zikr_form_screen.dart';

/// Dhikr Counter (Tasbeeh) Screen
/// Digital tasbeeh with haptic feedback and progress tracking
class DhikrScreen extends ConsumerStatefulWidget {
  const DhikrScreen({super.key});

  @override
  ConsumerState<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends ConsumerState<DhikrScreen>
    with TickerProviderStateMixin {
  int _currentCount = 0;
  int _currentTarget = 33;
  DhikrPreset? _selectedPreset;
  bool _isCompleted = false;

  // Custom presets
  List<DhikrPreset> _customPresets = [];
  static const String _customPresetsKey = 'custom_dhikr_presets';

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _selectedPreset = DhikrPresets.builtIn[0];
    _loadCustomPresets();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // ==================== Custom Presets Persistence ====================

  Future<void> _loadCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_customPresetsKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        setState(() {
          _customPresets = jsonList.map((e) => DhikrPreset.fromJson(e as Map<String, dynamic>)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading custom presets: $e');
    }
  }

  Future<void> _saveCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_customPresets.map((e) => e.toJson()).toList());
      await prefs.setString(_customPresetsKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving custom presets: $e');
    }
  }

  List<DhikrPreset> get _allPresets => [...DhikrPresets.builtIn, ..._customPresets];

  // ==================== Counter Logic ====================

  void _incrementCounter() {
    if (_isCompleted) {
      _resetCounter();
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _currentCount++;
      if (_currentCount >= _currentTarget) {
        _isCompleted = true;
        _onComplete();
      }
    });

    _pulseController.forward().then((_) => _pulseController.reverse());
    _updateProgressAnimation();

    // Vibrate if supported
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 50);
      }
    });
  }

  void _resetCounter() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentCount = 0;
      _isCompleted = false;
    });
    _updateProgressAnimation();
  }

  void _updateProgressAnimation() {
    _progressController.animateTo(_currentCount / _currentTarget);
  }

  void _onComplete() {
    HapticFeedback.heavyImpact();

    // Persist session to Firestore
    final userId = getCurrentUserId();
    DhikrService.instance.recordSession(
      userId: userId,
      dhikrText: _selectedPreset?.displayName ?? '',
      count: _currentCount,
      target: _currentTarget,
    );

    // Vibrate pattern
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 100, 50, 100]);
      }
    });

    // Show completion dialog
    _showCompletionDialog();
  }

  // ==================== Dialogs ====================

  void _showCompletionDialog() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'الحمد لله' : 'Alhamdulillah',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic ? 'أكملت الذكر' : 'Zikr Completed!',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetCounter();
                    },
                    child: Text(isArabic ? 'بدء جديد' : 'Start New'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _incrementCounter(); // Continue counting
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                    ),
                    child: Text(isArabic ? 'متابعة' : 'Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Preset Selector ====================

  void _showPresetSelector() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final allPresets = _allPresets;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isArabic ? 'اختر الذكر' : 'Select Zikr',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),

                // Built-in presets
                ...DhikrPresets.builtIn.map((preset) {
                  final isSelected = _selectedPreset?.id == preset.id && _selectedPreset?.name == preset.name;
                  return _buildPresetTile(preset, isSelected, isCustom: false);
                }),

                // Custom presets with edit/delete
                if (_customPresets.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      isArabic ? 'أذكار مخصصة' : 'Custom Zikr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  ..._customPresets.map((preset) {
                    final isSelected = _selectedPreset?.id == preset.id;
                    return _buildPresetTile(preset, isSelected, isCustom: true);
                  }),
                ],

                const SizedBox(height: AppConstants.paddingSmall),

                // Add Custom Zikr button
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                    child: Icon(Icons.add, color: AppConstants.primaryColor, size: 20),
                  ),
                  title: Text(
                    isArabic ? 'إضافة ذكر مخصص' : 'Add Custom Zikr',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openCustomZikrScreen();
                  },
                ),

                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetTile(DhikrPreset preset, bool isSelected, {required bool isCustom}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isSelected
            ? AppConstants.primaryColor
            : Colors.grey.shade300,
        child: preset.arabicText.isNotEmpty
            ? Text(
                preset.arabicText[0],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              )
            : Icon(Icons.edit_note, size: 18, color: isSelected ? Colors.white : Colors.black87),
      ),
      title: Text(
        preset.arabicText.isNotEmpty ? preset.arabicText : preset.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: preset.arabicText.isNotEmpty ? 20 : 16,
        ),
      ),
      subtitle: preset.translation.isNotEmpty
          ? Text(preset.translation, style: const TextStyle(fontSize: 12))
          : null,
      trailing: isCustom
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) Icon(Icons.check_circle, color: AppConstants.primaryColor, size: 20),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500),
                  onPressed: () {
                    Navigator.pop(context);
                    _openCustomZikrScreen(existing: preset);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteCustomZikr(preset);
                  },
                ),
              ],
            )
          : isSelected
              ? Icon(Icons.check_circle, color: AppConstants.primaryColor)
              : null,
      onTap: () {
        setState(() {
          _selectedPreset = preset;
          _currentTarget = preset.defaultTarget;
        });
        Navigator.pop(context);
        _resetCounter();
      },
    );
  }

  // ==================== Custom Zikr Form Screen ====================

  Future<void> _openCustomZikrScreen({DhikrPreset? existing}) async {
    final result = await Navigator.of(context).push<DhikrPreset>(
      MaterialPageRoute(
        builder: (_) => CustomZikrFormScreen(existingPreset: existing),
      ),
    );

    if (result == null || !mounted) return;

    final isEditing = existing != null;

    if (isEditing) {
      final index = _customPresets.indexWhere((p) => p.id == existing!.id);
      if (index != -1) {
        setState(() {
          _customPresets[index] = result;
          if (_selectedPreset?.id == existing.id) {
            _selectedPreset = result;
            _currentTarget = result.defaultTarget;
          }
        });
      }
    } else {
      setState(() {
        _customPresets.add(result);
      });
    }

    _saveCustomPresets();
  }

  void _deleteCustomZikr(DhikrPreset preset) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Text(isArabic ? 'حذف الذكر' : 'Delete Zikr'),
        content: Text(
          isArabic
              ? 'هل تريد حذف "${preset.displayName}"؟'
              : 'Delete "${preset.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _customPresets.removeWhere((p) => p.id == preset.id);
                // Reset selection if deleted preset was selected
                if (_selectedPreset?.id == preset.id) {
                  _selectedPreset = DhikrPresets.builtIn[0];
                  _currentTarget = _selectedPreset!.defaultTarget;
                  _currentCount = 0;
                  _isCompleted = false;
                }
              });
              _saveCustomPresets();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
  }

  // ==================== Target Selector ====================

  void _showTargetSelector() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isArabic ? 'اختر العدد المستهدف' : 'Select Target',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ...[33, 99, 100, 333, 1000].map((target) {
              return ListTile(
                title: Text(
                  '$target',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: _currentTarget == target
                    ? Icon(Icons.check_circle, color: AppConstants.primaryColor)
                    : null,
                onTap: () {
                  setState(() {
                    _currentTarget = target;
                  });
                  Navigator.pop(context);
                  _resetCounter();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'المسبحة' : 'Tasbeeh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () {
              Navigator.of(context).pushNamed('/dhikr_stats');
            },
            tooltip: isArabic ? 'الإحصائيات' : 'Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showPresetSelector,
            tooltip: isArabic ? 'الإعدادات' : 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            // Preset selector
            GestureDetector(
              onTap: _showPresetSelector,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  border: Border.all(
                    color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedPreset?.isCustom == true ? Icons.edit_note : Icons.dashboard,
                      color: AppConstants.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPreset?.displayName ?? 'Custom',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (_selectedPreset?.translation != null &&
                              _selectedPreset!.translation.isNotEmpty)
                            Text(
                              _selectedPreset!.translation,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            // Counter display
            _buildCounterDisplay(context, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingLarge),

            // Progress bar
            _buildProgressBar(context, isDark),

            const SizedBox(height: AppConstants.paddingMedium),

            // Target selector
            GestureDetector(
              onTap: _showTargetSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMedium,
                  vertical: AppConstants.paddingSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isArabic ? 'الهدف: ' : 'Target: ',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '$_currentTarget',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: AppConstants.primaryColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetCounter,
                    icon: const Icon(Icons.refresh),
                    label: Text(isArabic ? 'إعادة' : 'Reset'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.paddingMedium),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _incrementCounter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                    ),
                    child: Text(
                      isArabic ? 'عدّ' : 'Count',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom padding
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterDisplay(BuildContext context, bool isDark, bool isArabic) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: _incrementCounter,
            child: Semantics(
              button: true,
              label: '${isArabic ? 'عداد التسبيح' : 'Tasbeeh counter'}: $_currentCount / $_currentTarget',
              child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isCompleted
                      ? [Colors.green.shade400, Colors.green.shade600]
                      : [
                          AppConstants.primaryColor,
                          AppConstants.primaryColor.withOpacity(0.7),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isCompleted ? Colors.green : AppConstants.primaryColor)
                        .withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_currentCount',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/ $_currentTarget',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, bool isDark) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: _isCompleted ? Colors.green : AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }
}

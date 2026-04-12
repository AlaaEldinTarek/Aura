import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/haptic_feedback.dart';

class IqamaSettingsScreen extends ConsumerStatefulWidget {
  const IqamaSettingsScreen({super.key});

  @override
  ConsumerState<IqamaSettingsScreen> createState() => _IqamaSettingsScreenState();
}

class _IqamaSettingsScreenState extends ConsumerState<IqamaSettingsScreen> {
  // Default iqama minutes for each prayer
  final Map<String, int> _iqamaMinutes = {
    'Fajr': 15,
    'Zuhr': 15,
    'Asr': 15,
    'Maghrib': 5,
    'Isha': 15,
  };

  // SharedPreferences keys
  static const String _prefsKey = 'iqama_minutes';

  @override
  void initState() {
    super.initState();
    _loadIqamaSettings();
  }

  /// Load iqama settings from SharedPreferences
  Future<void> _loadIqamaSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_prefsKey);

      if (savedData != null) {
        // Parse saved JSON string
        final Map<String, dynamic> savedMap = {};
        savedData.split(',').forEach((pair) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            savedMap[parts[0].trim()] = int.tryParse(parts[1].trim());
          }
        });

        setState(() {
          _iqamaMinutes['Fajr'] = savedMap['Fajr'] ?? 15;
          _iqamaMinutes['Zuhr'] = savedMap['Zuhr'] ?? savedMap['Dhuhr'] ?? 15;
          _iqamaMinutes['Asr'] = savedMap['Asr'] ?? 15;
          _iqamaMinutes['Maghrib'] = savedMap['Maghrib'] ?? 5;
          _iqamaMinutes['Isha'] = savedMap['Isha'] ?? 15;
        });

        debugPrint('✅ Iqama settings loaded: $_iqamaMinutes');
      }
    } catch (e) {
      debugPrint('❌ Error loading iqama settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'أوقات الإقامة' : 'Iqama Times'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppConstants.primaryColor.withOpacity(0.15),
                        AppConstants.accentCyan.withOpacity(0.1),
                      ]
                    : [
                        AppConstants.primaryColor.withOpacity(0.08),
                        AppConstants.accentCyan.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: AppConstants.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'الإقامة هو الوقت الذي تبدأ فيه الصلاة بعد الأذان'
                        : 'Iqama is the time when prayer starts after adhan',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Iqama Time Adjustments
          _buildIqamaTile(context, 'Fajr', 'الفجر', '🌙', isDark, isArabic),
          _buildIqamaTile(context, 'Zuhr', 'الظهر', '☀️', isDark, isArabic),
          _buildIqamaTile(context, 'Asr', 'العصر', '🌤️', isDark, isArabic),
          _buildIqamaTile(context, 'Maghrib', 'المغرب', '🌇', isDark, isArabic),
          _buildIqamaTile(context, 'Isha', 'العشاء', '🌙', isDark, isArabic),

          const SizedBox(height: AppConstants.paddingLarge),

          // Reset Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
            child: OutlinedButton.icon(
              onPressed: () {
                _showResetDialog(context, isArabic);
              },
              icon: const Icon(Icons.restore),
              label: Text(isArabic ? 'إعادة تعيين' : 'Reset to Defaults'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
                side: BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // Bottom padding for nav bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildIqamaTile(
    BuildContext context,
    String prayerName,
    String prayerNameAr,
    String emoji,
    bool isDark,
    bool isArabic,
  ) {
    final minutes = _iqamaMinutes[prayerName] ?? 15;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: ListTile(
        leading: Text(
          emoji,
          style: const TextStyle(fontSize: 28),
        ),
        title: Text(
          isArabic ? prayerNameAr : prayerName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          isArabic ? '$minutes دقيقة بعد الأذان' : '$minutes minutes after adhan',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppConstants.primaryColor,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrease button
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: minutes > 0
                  ? () {
                            setState(() {
                        _iqamaMinutes[prayerName] = (minutes - 5).clamp(0, 60);
                      });
                      _saveIqamaSettings();
                    }
                  : null,
            ),
            // Minutes display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              ),
              child: Text(
                '$minutes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
            ),
            // Increase button
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: minutes < 60
                  ? () {
                            setState(() {
                        _iqamaMinutes[prayerName] = (minutes + 5).clamp(0, 60);
                      });
                      _saveIqamaSettings();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetDialog(BuildContext context, bool isArabic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'إعادة تعيين' : 'Reset'),
        content: Text(
          isArabic
              ? 'هل تريد إعادة تعيين أوقات الإقامة إلى القيم الافتراضية؟'
              : 'Reset iqama times to default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isArabic ? 'إعادة تعيين' : 'Reset',
              style: const TextStyle(color: AppConstants.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _iqamaMinutes['Fajr'] = 15;
        _iqamaMinutes['Zuhr'] = 15;
        _iqamaMinutes['Asr'] = 15;
        _iqamaMinutes['Maghrib'] = 5;
        _iqamaMinutes['Isha'] = 15;
      });
      _saveIqamaSettings();
    }
  }

  Future<void> _saveIqamaSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert map to string format: "Fajr:15,Dhuhr:15,Asr:15,Maghrib:5,Isha:15"
      final dataString = _iqamaMinutes.entries
          .map((e) => '${e.key}:${e.value}')
          .join(',');

      await prefs.setString(_prefsKey, dataString);
      debugPrint('✅ Iqama settings saved: $dataString');

      // Trigger haptic feedback
      HapticFeedback.light();
    } catch (e) {
      debugPrint('❌ Error saving iqama settings: $e');
    }
  }
}

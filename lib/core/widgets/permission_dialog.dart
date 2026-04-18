import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/platform_channel_service.dart';
import '../services/notification_service.dart';

/// Checks all required permissions and shows a dialog for missing ones.
class PermissionDialogHandler extends StatefulWidget {
  const PermissionDialogHandler({super.key});

  @override
  State<PermissionDialogHandler> createState() => _PermissionDialogHandlerState();
}

class _PermissionDialogHandlerState extends State<PermissionDialogHandler> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkAllPermissions();
    });
  }

  Future<void> _checkAllPermissions() async {
    if (_hasChecked) return;

    final missing = <_PermInfo>[];

    // 1. Location
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      missing.add(_PermInfo(
        icon: Icons.location_on,
        title: 'location_permission_title',
        desc: 'location_permission_desc',
        color: Colors.blue,
        action: () => Permission.location.request(),
        openSettings: () => openAppSettings(),
      ));
    }

    // 2. Notifications (Android 13+)
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        missing.add(_PermInfo(
          icon: Icons.notifications_active,
          title: 'notification_permission_title',
          desc: 'notification_permission_desc',
          color: Colors.orange,
          action: () => Permission.notification.request(),
          openSettings: () => openAppSettings(),
        ));
      }
    }

    // 3. Exact Alarms (Android 12+)
    final canSchedule = await PlatformChannelService.canScheduleExactAlarms();
    if (!canSchedule) {
      missing.add(_PermInfo(
        icon: Icons.alarm,
        title: 'exact_alarm_title',
        desc: 'exact_alarm_message',
        color: Colors.red,
        action: null,
        openSettings: () => PlatformChannelService.openExactAlarmSettings(),
      ));
    }

    // 4. Battery Optimization
    final isIgnoring = await PlatformChannelService.isIgnoringBatteryOptimizations();
    if (!isIgnoring) {
      missing.add(_PermInfo(
        icon: Icons.battery_alert_outlined,
        title: 'battery_optimization_title',
        desc: 'battery_optimization_message',
        color: Colors.amber.shade800,
        action: null,
        openSettings: () => PlatformChannelService.openBatteryOptimizationSettings(),
      ));
    }

    // 5. Do Not Disturb access (for silent mode)
    final dndStatus = await Permission.accessNotificationPolicy.status;
    if (!dndStatus.isGranted) {
      missing.add(_PermInfo(
        icon: Icons.do_not_disturb_on,
        title: 'dnd_permission_title',
        desc: 'dnd_permission_desc',
        color: Colors.purple,
        action: () => Permission.accessNotificationPolicy.request(),
        openSettings: () => openAppSettings(),
      ));
    }

    // 6. Accessibility Service (auto-accepts screen pinning during Focus Mode)
    // Only show if user has never enabled it before — Huawei EMUI kills services between sessions
    if (Platform.isAndroid) {
      final notifService = NotificationService.instance;
      final prefs = await SharedPreferences.getInstance();
      final everEnabled = prefs.getBool('focus_a11y_ever_enabled') ?? false;
      final a11yEnabled = await notifService.isAccessibilityServiceEnabled();
      if (a11yEnabled && !everEnabled) {
        await prefs.setBool('focus_a11y_ever_enabled', true);
      }
      if (!a11yEnabled && !everEnabled) {
        missing.add(_PermInfo(
          icon: Icons.phonelink_lock,
          title: 'accessibility_permission_title',
          desc: 'accessibility_permission_desc',
          color: Colors.teal,
          action: null,
          openSettings: () async {
            await notifService.requestAccessibilityPermission();
          },
        ));
      }
    }

    if (missing.isEmpty || !mounted) {
      _hasChecked = true;
      return;
    }

    _hasChecked = true;
    _showPermissionsPage(missing);
  }

  void _showPermissionsPage(List<_PermInfo> missing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PermissionsPage(permissions: missing),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ==================== Permissions Page ====================

class _PermissionsPage extends StatefulWidget {
  final List<_PermInfo> permissions;
  const _PermissionsPage({required this.permissions});

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage> with WidgetsBindingObserver {
  late List<bool> _granted;

  @override
  void initState() {
    super.initState();
    _granted = List.filled(widget.permissions.length, false);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recheck all ungranted permissions when user returns from settings
      for (int i = 0; i < widget.permissions.length; i++) {
        if (!_granted[i]) _recheckPermission(i);
      }
    }
  }

  Future<void> _grantPermission(int index) async {
    final perm = widget.permissions[index];
    if (perm.action != null) {
      final result = await perm.action!();
      if (result.isGranted) {
        setState(() => _granted[index] = true);
        return;
      }
    }
    // If direct request failed or not available, open settings
    perm.openSettings();
    // Wait for user to return from settings, then re-check
    await Future.delayed(const Duration(seconds: 1));
    await _recheckPermission(index);
  }

  Future<void> _recheckPermission(int index) async {
    final perm = widget.permissions[index];
    bool nowGranted = false;

    if (perm.title == 'battery_optimization_title') {
      nowGranted = await PlatformChannelService.isIgnoringBatteryOptimizations();
    } else if (perm.title == 'exact_alarm_title') {
      nowGranted = await PlatformChannelService.canScheduleExactAlarms();
    } else if (perm.title == 'location_permission_title') {
      nowGranted = await Permission.location.status.isGranted;
    } else if (perm.title == 'notification_permission_title') {
      nowGranted = await Permission.notification.status.isGranted;
    } else if (perm.title == 'dnd_permission_title') {
      nowGranted = await Permission.accessNotificationPolicy.status.isGranted;
    } else if (perm.title == 'accessibility_permission_title') {
      nowGranted = await NotificationService.instance.isAccessibilityServiceEnabled();
      if (nowGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('focus_a11y_ever_enabled', true);
      }
    }

    if (nowGranted && mounted) {
      setState(() => _granted[index] = true);
    }
  }

  Future<void> _grantAll() async {
    for (int i = 0; i < widget.permissions.length; i++) {
      if (!_granted[i]) {
        await _grantPermission(i);
        // Small delay between requests
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final allGranted = _granted.every((g) => g);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الأذونات المطلوبة' : 'Required Permissions'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            color: AppConstants.primaryColor.withOpacity(0.08),
            child: Column(
              children: [
                Icon(
                  allGranted ? Icons.check_circle : Icons.security,
                  size: 48,
                  color: allGranted ? Colors.green : AppConstants.primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  allGranted
                      ? (isArabic ? 'جميع الأذونات ممنوحة' : 'All permissions granted')
                      : (isArabic
                          ? 'يحتاج التطبيق هذه الأذونات ليعمل بشكل صحيح'
                          : 'Aura needs these permissions to work properly'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Permission list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              itemCount: widget.permissions.length,
              itemBuilder: (context, index) {
                final perm = widget.permissions[index];
                final isGranted = _granted[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                  decoration: BoxDecoration(
                    color: isDark ? AppConstants.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    border: Border.all(
                      color: isGranted
                          ? Colors.green.withOpacity(0.5)
                          : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isGranted ? Colors.green : perm.color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      child: Icon(
                        isGranted ? Icons.check_circle : perm.icon,
                        color: isGranted ? Colors.green : perm.color,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      isArabic ? _arabicTitle(perm.title) : perm.title.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isArabic ? _arabicDesc(perm.desc) : perm.desc.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    trailing: isGranted
                        ? Text(
                            isArabic ? 'ممنوح' : 'Granted',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () => _grantPermission(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: perm.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                              ),
                            ),
                            child: Text(
                              isArabic ? 'تفعيل' : 'Enable',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(isArabic ? 'لاحقاً' : 'Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: allGranted ? () => Navigator.pop(context) : _grantAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allGranted ? Colors.green : AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      allGranted
                          ? (isArabic ? 'تم' : 'Done')
                          : (isArabic ? 'تفعيل الكل' : 'Enable All'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _arabicTitle(String key) {
    const map = {
      'location_permission_title': 'الموقع',
      'notification_permission_title': 'الإشعارات',
      'exact_alarm_title': 'المنبهات الدقيقة',
      'battery_optimization_title': 'تحسين البطارية',
      'dnd_permission_title': 'وضع عدم الإزعاج',
      'accessibility_permission_title': 'أذونات وضع التركيز',
    };
    return map[key] ?? key;
  }

  String _arabicDesc(String key) {
    const map = {
      'location_permission_desc': 'مطلوب لحساب أوقات الصلاة بدقة',
      'notification_permission_desc': 'مطلوب لإشعارات أوقات الصلاة',
      'exact_alarm_message': 'مطلوب لتشغيل الأذان في الوقت المحدد',
      'battery_optimization_message': 'مطلوب لضمان عمل الإشعارات في الخلفية',
      'dnd_permission_desc': 'مطلوب لتفعيل الوضع الصامت أثناء الصلاة',
      'accessibility_permission_desc': 'مطلوب لعمل وضع التركيز بشكل صحيح',
    };
    return map[key] ?? key;
  }
}

// ==================== Permission Info Model ====================

class _PermInfo {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final Future<PermissionStatus> Function()? action;
  final VoidCallback openSettings;

  _PermInfo({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.action,
    required this.openSettings,
  });
}

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

    // Read app mode to filter relevant permissions
    final prefs = await SharedPreferences.getInstance();
    final appMode = prefs.getString('app_mode') ?? 'both';
    final needsPrayer = appMode != 'tasks_only';
    final needsTasks  = appMode != 'prayer_only';

    final missing = <_PermInfo>[];

    // 1. Location — prayer only
    if (needsPrayer) {
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        missing.add(_PermInfo(
          icon: Icons.location_on,
          title: 'location_permission_title',
          desc: 'location_permission_desc',
          color: Colors.blue,
          group: _PermGroup.prayer,
          action: () => Permission.location.request(),
          openSettings: () => openAppSettings(),
        ));
      }
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
          group: _PermGroup.prayer,
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
        group: _PermGroup.prayer,
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
        group: _PermGroup.prayer,
        action: null,
        openSettings: () => PlatformChannelService.openBatteryOptimizationSettings(),
      ));
    }

    // 5. Do Not Disturb — dual purpose:
    // - Prayer silent mode (if prayer enabled)
    // - Focus mode silence (if tasks enabled)
    final dndStatus = await Permission.accessNotificationPolicy.status;
    if (!dndStatus.isGranted) {
      // Place under whichever group the user has enabled; Focus if both
      final dndGroup = needsTasks ? _PermGroup.focusMode : _PermGroup.prayer;
      missing.add(_PermInfo(
        icon: Icons.do_not_disturb_on,
        title: 'dnd_permission_title',
        desc: 'dnd_permission_desc',
        color: Colors.purple,
        group: dndGroup,
        action: () => Permission.accessNotificationPolicy.request(),
        openSettings: () => openAppSettings(),
      ));
    }

    // 6. Overlay — only needed for Focus Mode (tasks)
    if (Platform.isAndroid && needsTasks) {
      final canOverlay = await NotificationService.instance.canDrawOverlays();
      if (!canOverlay) {
        missing.add(_PermInfo(
          icon: Icons.picture_in_picture_alt,
          title: 'overlay_permission_title',
          desc: 'overlay_permission_desc',
          color: Colors.deepOrange,
          group: _PermGroup.focusMode,
          action: null,
          openSettings: () => NotificationService.instance.requestOverlayPermission(),
        ));
      }
    }

    // Accessibility service removed — screen pinning dialog handled manually by user

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
    } else if (perm.title == 'overlay_permission_title') {
      nowGranted = await NotificationService.instance.canDrawOverlays();
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
            color: AppConstants.getPrimary(isDark).withOpacity(0.08),
            child: Column(
              children: [
                Icon(
                  allGranted ? Icons.check_circle : Icons.security,
                  size: 48,
                  color: allGranted ? Colors.green : AppConstants.getPrimary(isDark),
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

          // Permission list — grouped by prayer / focus mode
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              children: [
                if (widget.permissions.any((p) => p.group == _PermGroup.prayer)) ...[
                  _GroupHeader(
                    icon: Icons.mosque_outlined,
                    label: isArabic ? '🕌 أذونات الصلاة' : '🕌 Prayer Permissions',
                    color: AppConstants.getPrimary(isDark),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  ...widget.permissions.asMap().entries
                      .where((e) => e.value.group == _PermGroup.prayer)
                      .map((e) => _PermTile(
                            perm: e.value,
                            isGranted: _granted[e.key],
                            isArabic: isArabic,
                            isDark: isDark,
                            onGrant: () => _grantPermission(e.key),
                          )),
                ],
                if (widget.permissions.any((p) => p.group == _PermGroup.focusMode)) ...[
                  const SizedBox(height: 12),
                  _GroupHeader(
                    icon: Icons.lock_clock,
                    label: isArabic ? '🎯 أذونات وضع التركيز' : '🎯 Focus Mode Permissions',
                    color: Colors.deepOrange,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  ...widget.permissions.asMap().entries
                      .where((e) => e.value.group == _PermGroup.focusMode)
                      .map((e) => _PermTile(
                            perm: e.value,
                            isGranted: _granted[e.key],
                            isArabic: isArabic,
                            isDark: isDark,
                            onGrant: () => _grantPermission(e.key),
                          )),
                ],
              ],
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
                      backgroundColor: allGranted ? Colors.green : AppConstants.getPrimary(isDark),
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
      'location_permission_title': 'الموقع الجغرافي',
      'notification_permission_title': 'الإشعارات',
      'exact_alarm_title': 'المنبهات الدقيقة',
      'battery_optimization_title': 'تحسين البطارية',
      'dnd_permission_title': 'وضع عدم الإزعاج',
      'overlay_permission_title': 'العرض فوق التطبيقات',
      'accessibility_permission_title': 'خدمة إمكانية الوصول',
    };
    return map[key] ?? key;
  }

  String _arabicDesc(String key) {
    const map = {
      'location_permission_desc': 'مطلوب لحساب أوقات الصلاة بدقة واتجاه القبلة',
      'notification_permission_desc': 'مطلوب لإشعارات أوقات الصلاة والمهام',
      'exact_alarm_message': 'مطلوب لتشغيل الأذان في الوقت المحدد تماماً',
      'battery_optimization_message': 'مطلوب لضمان عمل الإشعارات في الخلفية',
      'dnd_permission_desc': 'مطلوب لوضع الصامت أثناء الصلاة ووضع التركيز',
      'overlay_permission_desc': 'مطلوب لعرض شاشة وضع التركيز فوق التطبيقات',
      'accessibility_permission_desc': 'يقبل تلقائياً تثبيت الشاشة أثناء وضع التركيز',
    };
    return map[key] ?? key;
  }
}

// ── Group header widget ────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Permission tile widget ─────────────────────────────────────────────────
class _PermTile extends StatelessWidget {
  final _PermInfo perm;
  final bool isGranted, isArabic, isDark;
  final VoidCallback onGrant;
  const _PermTile({
    required this.perm,
    required this.isGranted,
    required this.isArabic,
    required this.isDark,
    required this.onGrant,
  });

  String _title() {
    const ar = {
      'location_permission_title': 'الموقع الجغرافي',
      'notification_permission_title': 'الإشعارات',
      'exact_alarm_title': 'المنبهات الدقيقة',
      'battery_optimization_title': 'تحسين البطارية',
      'dnd_permission_title': 'وضع عدم الإزعاج',
      'overlay_permission_title': 'العرض فوق التطبيقات',
      'accessibility_permission_title': 'خدمة إمكانية الوصول',
    };
    return isArabic ? (ar[perm.title] ?? perm.title) : perm.title.tr();
  }

  String _desc() {
    const ar = {
      'location_permission_desc': 'مطلوب لحساب أوقات الصلاة بدقة واتجاه القبلة',
      'notification_permission_desc': 'مطلوب لإشعارات أوقات الصلاة والمهام',
      'exact_alarm_message': 'مطلوب لتشغيل الأذان في الوقت المحدد تماماً',
      'battery_optimization_message': 'مطلوب لضمان عمل الإشعارات في الخلفية',
      'dnd_permission_desc': 'مطلوب لوضع الصامت أثناء الصلاة ووضع التركيز',
      'overlay_permission_desc': 'مطلوب لعرض شاشة وضع التركيز فوق التطبيقات',
      'accessibility_permission_desc': 'يقبل تلقائياً تثبيت الشاشة أثناء وضع التركيز',
    };
    return isArabic ? (ar[perm.desc] ?? perm.desc) : perm.desc.tr();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.4)
              : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isGranted ? Colors.green : perm.color).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isGranted ? Icons.check_circle_rounded : perm.icon,
            color: isGranted ? Colors.green : perm.color,
            size: 24,
          ),
        ),
        title: Text(
          _title(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          _desc(),
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        trailing: isGranted
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isArabic ? 'مفعّل' : 'Granted',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: onGrant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: perm.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isArabic ? 'تفعيل' : 'Enable',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }
}

// ==================== Permission Info Model ====================

enum _PermGroup { prayer, focusMode }

class _PermInfo {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final _PermGroup group;
  final Future<PermissionStatus> Function()? action;
  final VoidCallback openSettings;

  _PermInfo({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.group,
    required this.action,
    required this.openSettings,
  });
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart' show PermissionStatusGetters;
import '../constants/app_constants.dart';
import '../services/platform_channel_service.dart';
import '../theme/app_typography.dart';
import 'aura_button.dart';
import 'auto_launch_dialog.dart';
import 'permission_rows.dart';

/// Checks all required permissions and shows a dialog for missing ones.
class PermissionDialogHandler extends StatefulWidget {
  const PermissionDialogHandler({super.key, this.onDone});

  /// Called after the permissions check (and any dialog) is complete.
  final VoidCallback? onDone;

  static final Completer<void> _completer = Completer<void>();
  static Future<void> get permissionsDone => _completer.future;

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

    // Desktop (Windows/macOS/Linux) has no Android permissions to check
    if (!Platform.isAndroid && !Platform.isIOS) {
      _hasChecked = true;
      if (!PermissionDialogHandler._completer.isCompleted) {
        PermissionDialogHandler._completer.complete();
      }
      widget.onDone?.call();
      return;
    }

    try {
      await _runChecks();
    } catch (e) {
      debugPrint('PermissionDialog: unexpected error - $e');
    } finally {
      if (!_hasChecked) {
        _hasChecked = true;
        if (!PermissionDialogHandler._completer.isCompleted) {
          PermissionDialogHandler._completer.complete();
        }
        widget.onDone?.call();
      }
    }
  }

  Future<void> _runChecks() async {
    // Popup mode: only the missing ones of the four original checks (exact alarm,
    // battery, Do Not Disturb, overlay). Notifications, Location and Auto-launch are
    // only on the Settings page. The rules live in buildPermissionRows.
    final missing = await buildPermissionRows(const RealPermissionProbe(), showAll: false);

    // Accessibility service removed — screen pinning dialog handled manually by user

    if (missing.isEmpty || !mounted) {
      _hasChecked = true;
      if (!PermissionDialogHandler._completer.isCompleted) {
        PermissionDialogHandler._completer.complete();
      }
      widget.onDone?.call();
      return;
    }

    _hasChecked = true;
    // A Huawei-only hint, never part of the missing list (it cannot be checked).
    final autoLaunchHint = await PlatformChannelService.isEmuiDevice();
    if (!mounted) {
      if (!PermissionDialogHandler._completer.isCompleted) {
        PermissionDialogHandler._completer.complete();
      }
      widget.onDone?.call();
      return;
    }
    await _showPermissionsPage(missing, autoLaunchHint: autoLaunchHint);
    if (!PermissionDialogHandler._completer.isCompleted) {
      PermissionDialogHandler._completer.complete();
    }
    widget.onDone?.call();
  }

  Future<void> _showPermissionsPage(List<PermRow> missing, {bool autoLaunchHint = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PermissionsPage(rows: missing, showAutoLaunchHint: autoLaunchHint),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Opens the permissions page in "show everything" mode (every applicable row with
/// its state), from the Settings "Permissions" tile.
/// Spec: docs/designs/permissions-status-screen.md. [probe] is a test seam.
Future<void> showPermissionsStatusPage(
  BuildContext context, {
  PermissionProbe? probe,
}) async {
  final rows = await buildPermissionRows(probe ?? const RealPermissionProbe(), showAll: true);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PermissionsPage(rows: rows, showAll: true)),
  );
}

// ==================== Permissions Page ====================

/// The permissions page. Popup mode (`showAll: false`): only missing rows, no back
/// arrow, rechecks only rows not yet granted. Show-everything mode (`showAll: true`):
/// every row with its state, a back arrow, a summary, and a recheck of every readable
/// row when the user comes back to the app.
class PermissionsPage extends StatefulWidget {
  final List<PermRow> rows;
  final bool showAll;
  final bool showAutoLaunchHint;
  const PermissionsPage({
    super.key,
    required this.rows,
    this.showAll = false,
    this.showAutoLaunchHint = false,
  });

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  late List<PermState> _states;

  /// Rows where an Enable attempt ended not granted: show the "turn it on in the
  /// app's settings" line. Page state only, not stored.
  late List<bool> _denied;

  @override
  void initState() {
    super.initState();
    _states = widget.rows.map((r) => r.state).toList();
    _denied = List.filled(widget.rows.length, false);
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
      for (int i = 0; i < widget.rows.length; i++) {
        if (widget.showAll) {
          // Every readable row: the user may also have revoked a permission.
          if (_states[i] != PermState.checkByHand) _recheckPermission(i);
        } else {
          // Popup: only rows not granted yet, as before.
          if (_states[i] != PermState.granted) _recheckPermission(i);
        }
      }
    }
  }

  Future<void> _grantPermission(int index) async {
    final perm = widget.rows[index];
    if (perm.action != null) {
      final result = await perm.action!();
      if (result.isGranted) {
        if (!mounted) return;
        setState(() {
          _states[index] = PermState.granted;
          _denied[index] = false;
        });
        return;
      }
      if (perm.explainsDenial && mounted) {
        setState(() => _denied[index] = true);
      }
    }
    // If direct request failed or not available, open settings
    perm.openSettings();
    // Wait for user to return from settings, then re-check
    await Future.delayed(const Duration(seconds: 1));
    await _recheckPermission(index);
  }

  Future<void> _recheckPermission(int index) async {
    final now = await widget.rows[index].recheck();
    if (!mounted) return;
    if (widget.showAll) {
      if (now != _states[index]) {
        setState(() {
          _states[index] = now;
          if (now == PermState.granted) _denied[index] = false;
        });
      }
    } else if (now == PermState.granted) {
      setState(() => _states[index] = PermState.granted);
    }
  }

  Future<void> _grantAll() async {
    for (int i = 0; i < widget.rows.length; i++) {
      if (_states[i] == PermState.missing) {
        await _grantPermission(i);
        // Small delay between requests
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  String _summaryText(PermSummary s) {
    switch (s) {
      case PermSummary.allSet:
        return 'permissions_all_set'.tr();
      case PermSummary.allSetPlusHand:
        return 'permissions_all_set_plus_hand'.tr();
      case PermSummary.someMissing:
        return 'permissions_some_missing'.tr();
    }
  }

  List<Widget> _tiles(PermGroup group, bool isArabic, bool isDark) {
    return widget.rows.asMap().entries.where((e) => e.value.group == group).map((e) {
      final i = e.key;
      return _PermTile(
        perm: e.value,
        state: _states[i],
        denied: _denied[i],
        isArabic: isArabic,
        isDark: isDark,
        onGrant: () => _grantPermission(i),
        onGuide: () => e.value.showGuide?.call(context),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final anyMissing = _states.contains(PermState.missing);
    final allGranted = !anyMissing;
    final summary = summarizePermissions(_states);
    final headerOk = widget.showAll ? summary != PermSummary.someMissing : allGranted;

    final primaryButton = ElevatedButton(
      onPressed: allGranted ? () => Navigator.pop(context) : _grantAll,
      style: ElevatedButton.styleFrom(
        backgroundColor: allGranted ? Colors.green : AppConstants.getPrimary(isDark),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        allGranted
            ? (isArabic ? 'تم' : 'Done')
            : (isArabic ? 'تفعيل الكل' : 'Enable All'),
        style: AppTypography.bodyM.copyWith(fontWeight: FontWeight.bold),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showAll
            ? 'permissions_page_title_all'.tr()
            : (isArabic ? 'الأذونات المطلوبة' : 'Required Permissions')),
        automaticallyImplyLeading: widget.showAll,
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
                  headerOk ? Icons.check_circle : Icons.security,
                  size: 48,
                  color: headerOk ? Colors.green : AppConstants.getPrimary(isDark),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.showAll
                      ? _summaryText(summary)
                      : (allGranted
                          ? (isArabic ? 'جميع الأذونات ممنوحة' : 'All permissions granted')
                          : (isArabic
                              ? 'يحتاج التطبيق هذه الأذونات ليعمل بشكل صحيح'
                              : 'Aura needs these permissions to work properly')),
                  style: AppTypography.bodyL.copyWith(
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
                if (widget.rows.any((p) => p.group == PermGroup.prayer)) ...[
                  _GroupHeader(
                    icon: Icons.mosque_outlined,
                    label: isArabic ? '🕌 أذونات الصلاة' : '🕌 Prayer Permissions',
                    color: AppConstants.getPrimary(isDark),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  ..._tiles(PermGroup.prayer, isArabic, isDark),
                ],
                if (widget.rows.any((p) => p.group == PermGroup.focusMode)) ...[
                  const SizedBox(height: 12),
                  _GroupHeader(
                    icon: Icons.lock_clock,
                    label: isArabic ? '🎯 أذونات وضع التركيز' : '🎯 Focus Mode Permissions',
                    color: Colors.deepOrange,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  ..._tiles(PermGroup.focusMode, isArabic, isDark),
                ],
                if (widget.showAutoLaunchHint && !widget.showAll) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.rocket_launch_outlined, color: Colors.deepPurple),
                      title: Text('auto_launch_title'.tr()),
                      subtitle: Text('auto_launch_subtitle'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showAutoLaunchDialog(context),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: widget.showAll
                ? SizedBox(width: double.infinity, child: primaryButton)
                : Row(
                    children: [
                      Expanded(
                        child: AuraButton.secondary(
                          label: isArabic ? 'لاحقاً' : 'Later',
                          onPressed: () => Navigator.pop(context),
                          expanded: true,
                          verticalPadding: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: primaryButton),
                    ],
                  ),
          ),
        ],
      ),
    );
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
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.bold,
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
  final PermRow perm;
  final PermState state;
  final bool denied;
  final bool isArabic, isDark;
  final VoidCallback onGrant;
  final VoidCallback onGuide;
  const _PermTile({
    required this.perm,
    required this.state,
    required this.denied,
    required this.isArabic,
    required this.isDark,
    required this.onGrant,
    required this.onGuide,
  });

  bool get _granted => state == PermState.granted;
  bool get _byHand => state == PermState.checkByHand;

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
    // A key that is not in the map (for example the Auto-launch row) goes through
    // .tr() instead of showing the raw key.
    return isArabic ? (ar[perm.title] ?? perm.title.tr()) : perm.title.tr();
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
    return isArabic ? (ar[perm.desc] ?? perm.desc.tr()) : perm.desc.tr();
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppConstants.textMuted(isDark);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppConstants.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _granted
              ? Colors.green.withValues(alpha: 0.4)
              : (AppConstants.border(isDark)),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (_granted ? Colors.green : perm.color).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _granted ? Icons.check_circle_rounded : perm.icon,
            color: _granted ? Colors.green : perm.color,
            size: 24,
          ),
        ),
        title: Text(
          _title(),
          style: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _desc(),
              style: AppTypography.caption.copyWith(height: 1.4, color: muted),
            ),
            if (_byHand) ...[
              const SizedBox(height: 4),
              Text(
                'permissions_check_by_hand'.tr(),
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
            if (denied && state == PermState.missing) ...[
              const SizedBox(height: 4),
              Text(
                'permissions_denied_hint'.tr(),
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ],
        ),
        trailing: _granted
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isArabic ? 'مفعّل' : 'Granted',
                  style: AppTypography.labelS.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: _byHand ? onGuide : onGrant,
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
                  _byHand
                      ? 'permissions_check_by_hand_button'.tr()
                      : (isArabic ? 'تفعيل' : 'Enable'),
                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }
}

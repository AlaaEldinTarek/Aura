import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/services/prayer_alarm_service.dart';
import '../../core/widgets/setting_tile.dart';

/// Number of taps on the Version tile that reveals the developer tile.
const int kDevTapsToUnlock = 7;

/// The Profile "Version" tile. Seven taps reveal a hidden developer tile
/// (docs/designs/dev-test-adhan.md). The tap counter lives in this widget's
/// state only: it is not persisted and resets on every new visit to the screen.
class ProfileVersionTile extends StatefulWidget {
  final String title;
  final String version;

  /// Fires the real adhan flow; defaults to [PrayerAlarmService.testAdhanNow].
  final Future<void> Function(String prayerName)? fireTestAdhan;

  /// Defaults to [PrayerAlarmService.canScheduleExactAlarms].
  final Future<bool> Function()? canScheduleExactAlarms;

  /// Shows the post-prayer check for the next prayer now (docs/designs/fix-post-check-remind-later.md).
  /// When null the "Test post-check" item is not shown.
  final Future<void> Function()? firePostCheck;

  /// Fires the real task digest card now with real counts (T4). When null the "Test digest" item is not shown.
  final Future<void> Function()? fireDigest;

  /// Fires the real post-prayer azkar trigger now (T6). When null the "Test azkar" item is not shown.
  final Future<void> Function()? fireAzkar;

  /// Posts the real Jumu'ah card now with a fake Zuhr 30 min ahead, any day (T7). When null the "Test Jumu'ah" item is not shown.
  final Future<void> Function()? fireJumuah;

  const ProfileVersionTile({
    super.key,
    required this.title,
    required this.version,
    this.fireTestAdhan,
    this.canScheduleExactAlarms,
    this.firePostCheck,
    this.fireDigest,
    this.fireAzkar,
    this.fireJumuah,
  });

  @override
  State<ProfileVersionTile> createState() => _ProfileVersionTileState();
}

class _ProfileVersionTileState extends State<ProfileVersionTile> {
  int _taps = 0;

  bool get _unlocked => _taps >= kDevTapsToUnlock;

  void _onVersionTap() {
    if (_unlocked) return;
    setState(() => _taps++);
  }

  Future<void> _confirmAndFire() async {
    // Captured before any await: the dialog and snackbar outlive this build.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('dev_test_adhan_dialog_title'.tr()),
        content: Text('dev_test_adhan_dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('dev_test_adhan_fire'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // testAdhanNow swallows errors and the native handler has no permission
    // check, so without exact-alarm permission nothing would fire silently.
    final canSchedule = widget.canScheduleExactAlarms ??
        PrayerAlarmService.instance.canScheduleExactAlarms;
    if (!await canSchedule()) {
      messenger.showSnackBar(
        SnackBar(content: Text('dev_test_adhan_no_exact_alarm'.tr())),
      );
      return;
    }

    // Zuhr only: Fajr and Isha also trigger a Flutter recalculation.
    final fire =
        widget.fireTestAdhan ?? PrayerAlarmService.instance.testAdhanNow;
    await fire('Zuhr');
    messenger.showSnackBar(
      SnackBar(content: Text('dev_test_adhan_scheduled'.tr())),
    );
  }

  Future<void> _firePostCheck() async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.firePostCheck!();
    messenger.showSnackBar(
      SnackBar(content: Text('dev_test_post_check_sent'.tr())),
    );
  }

  Future<void> _fireDigest() async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.fireDigest!();
    messenger.showSnackBar(
      SnackBar(content: Text('dev_test_digest_sent'.tr())),
    );
  }

  Future<void> _fireAzkar() async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.fireAzkar!();
    messenger.showSnackBar(
      SnackBar(content: Text('dev_test_azkar_sent'.tr())),
    );
  }

  Future<void> _fireJumuah() async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.fireJumuah!();
    messenger.showSnackBar(
      SnackBar(content: Text('dev_test_jumuah_sent'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingTile(
          icon: Icons.info_outline,
          title: widget.title,
          subtitle: widget.version,
          onTap: _onVersionTap,
          showChevron: false,
        ),
        if (_unlocked)
          SettingTile(
            icon: Icons.notifications_active_outlined,
            title: 'dev_test_adhan_title'.tr(),
            subtitle: 'dev_test_adhan_subtitle'.tr(),
            onTap: _confirmAndFire,
            showChevron: false,
          ),
        if (_unlocked && widget.firePostCheck != null)
          SettingTile(
            icon: Icons.fact_check_outlined,
            title: 'dev_test_post_check_title'.tr(),
            subtitle: 'dev_test_post_check_subtitle'.tr(),
            onTap: _firePostCheck,
            showChevron: false,
          ),
        if (_unlocked && widget.fireDigest != null)
          SettingTile(
            icon: Icons.checklist_rtl_outlined,
            title: 'dev_test_digest_title'.tr(),
            subtitle: 'dev_test_digest_subtitle'.tr(),
            onTap: _fireDigest,
            showChevron: false,
          ),
        if (_unlocked && widget.fireAzkar != null)
          SettingTile(
            icon: Icons.self_improvement_outlined,
            title: 'dev_test_azkar_title'.tr(),
            subtitle: 'dev_test_azkar_subtitle'.tr(),
            onTap: _fireAzkar,
            showChevron: false,
          ),
        if (_unlocked && widget.fireJumuah != null)
          SettingTile(
            icon: Icons.mosque_outlined,
            title: 'dev_test_jumuah_title'.tr(),
            subtitle: 'dev_test_jumuah_subtitle'.tr(),
            onTap: _fireJumuah,
            showChevron: false,
          ),
      ],
    );
  }
}

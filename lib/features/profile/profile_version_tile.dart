import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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

  const ProfileVersionTile({
    super.key,
    required this.title,
    required this.version,
    this.fireTestAdhan,
    this.canScheduleExactAlarms,
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
          ),
      ],
    );
  }
}

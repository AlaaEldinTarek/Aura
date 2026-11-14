import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/platform_channel_service.dart';
import 'auto_launch_dialog.dart';

// The rows of the permissions page and the rules for which rows exist, as pure
// logic over a [PermissionProbe]. Spec: docs/designs/permissions-status-screen.md.

enum PermGroup { prayer, focusMode }

/// Every row the page can show. No full-screen-intent and no storage row (spec).
enum PermId { exactAlarm, battery, dnd, overlay, notifications, location, autoLaunch }

/// `checkByHand` is for a setting the app cannot read (EMUI Auto-launch): it is never
/// "granted" and never "missing".
enum PermState { granted, missing, checkByHand }

enum PermSummary { allSet, allSetPlusHand, someMissing }

/// What the page needs from the phone: every state read and every action. The real
/// one talks to the platform; tests use a fake.
abstract class PermissionProbe {
  bool get isAndroid;
  Future<String> appMode();
  Future<bool> canScheduleExactAlarms();
  Future<bool> isIgnoringBatteryOptimizations();
  Future<bool> dndGranted();
  Future<bool> canDrawOverlays();
  Future<bool> notificationsGranted();
  Future<bool> locationGranted();
  Future<bool> isEmuiDevice();

  Future<PermissionStatus> requestDnd();
  Future<PermissionStatus> requestNotification();
  Future<PermissionStatus> requestLocation();
  Future<void> openAppSettings();
  Future<void> openExactAlarmSettings();
  Future<void> openBatterySettings();
  Future<void> openOverlaySettings();
  Future<void> showAutoLaunchGuide(BuildContext context);
}

class RealPermissionProbe implements PermissionProbe {
  const RealPermissionProbe();

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  Future<String> appMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_mode') ?? 'both';
  }

  @override
  Future<bool> canScheduleExactAlarms() => PlatformChannelService.canScheduleExactAlarms();

  @override
  Future<bool> isIgnoringBatteryOptimizations() =>
      PlatformChannelService.isIgnoringBatteryOptimizations();

  @override
  Future<bool> dndGranted() async => (await Permission.accessNotificationPolicy.status).isGranted;

  @override
  Future<bool> canDrawOverlays() => NotificationService.instance.canDrawOverlays();

  @override
  Future<bool> notificationsGranted() async => (await Permission.notification.status).isGranted;

  @override
  Future<bool> locationGranted() async => (await Permission.location.status).isGranted;

  @override
  Future<bool> isEmuiDevice() => PlatformChannelService.isEmuiDevice();

  @override
  Future<PermissionStatus> requestDnd() => Permission.accessNotificationPolicy.request();

  @override
  Future<PermissionStatus> requestNotification() => Permission.notification.request();

  @override
  Future<PermissionStatus> requestLocation() => Permission.location.request();

  @override
  Future<void> openAppSettings() async {
    await openAppSettings_();
  }

  @override
  Future<void> openExactAlarmSettings() => PlatformChannelService.openExactAlarmSettings();

  @override
  Future<void> openBatterySettings() => PlatformChannelService.openBatteryOptimizationSettings();

  @override
  Future<void> openOverlaySettings() => NotificationService.instance.requestOverlayPermission();

  @override
  Future<void> showAutoLaunchGuide(BuildContext context) => showAutoLaunchDialog(context);
}

/// permission_handler's top-level `openAppSettings`, under another name because the
/// probe method of the same name shadows it inside the class.
Future<bool> openAppSettings_() => openAppSettings();

/// One row of the page.
class PermRow {
  final PermId id;
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final PermGroup group;
  final PermState state;

  /// A direct system request, when the permission has one.
  final Future<PermissionStatus> Function()? action;

  /// Where to go when [action] is missing or does not grant.
  final VoidCallback openSettings;

  /// Reads the state again (after the user came back from system settings).
  final Future<PermState> Function() recheck;

  /// Notifications and Location: after an Enable attempt that ends not granted, the
  /// page shows the "turn it on in the app's settings" line.
  final bool explainsDenial;

  /// For the check-by-hand row: opens the explanation.
  final Future<void> Function(BuildContext context)? showGuide;

  const PermRow({
    required this.id,
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.group,
    required this.state,
    required this.action,
    required this.openSettings,
    required this.recheck,
    this.explainsDenial = false,
    this.showGuide,
  });
}

PermState _fromBool(bool granted) => granted ? PermState.granted : PermState.missing;

/// Builds the rows for one mode.
///
/// * `showAll: false` is the automatic popup: only the missing ones of the four
///   original checks (exact alarm, battery, Do Not Disturb, overlay), as before.
/// * `showAll: true` is the Settings page: every applicable row with its state.
///
/// The exact-alarm row is always built; below Android 12 the native check is always
/// true, so it reads Granted (spec, final choice 1).
Future<List<PermRow>> buildPermissionRows(
  PermissionProbe probe, {
  required bool showAll,
}) async {
  final mode = await probe.appMode();
  final needsPrayer = mode != 'tasks_only';
  final needsTasks = mode != 'prayer_only';

  final rows = <PermRow>[];

  final exactAlarm = await probe.canScheduleExactAlarms();
  rows.add(PermRow(
    id: PermId.exactAlarm,
    icon: Icons.alarm,
    title: 'exact_alarm_title',
    desc: 'exact_alarm_message',
    color: Colors.red,
    group: PermGroup.prayer,
    state: _fromBool(exactAlarm),
    action: null,
    openSettings: () => probe.openExactAlarmSettings(),
    recheck: () async => _fromBool(await probe.canScheduleExactAlarms()),
  ));

  final battery = await probe.isIgnoringBatteryOptimizations();
  rows.add(PermRow(
    id: PermId.battery,
    icon: Icons.battery_alert_outlined,
    title: 'battery_optimization_title',
    desc: 'battery_optimization_message',
    color: Colors.amber.shade800,
    group: PermGroup.prayer,
    state: _fromBool(battery),
    action: null,
    openSettings: () => probe.openBatterySettings(),
    recheck: () async => _fromBool(await probe.isIgnoringBatteryOptimizations()),
  ));

  // Do Not Disturb: prayer silent mode and Focus Mode silence. Under Focus Mode when
  // the app mode has tasks, else under Prayer.
  final dnd = await probe.dndGranted();
  rows.add(PermRow(
    id: PermId.dnd,
    icon: Icons.do_not_disturb_on,
    title: 'dnd_permission_title',
    desc: 'dnd_permission_desc',
    color: Colors.purple,
    group: needsTasks ? PermGroup.focusMode : PermGroup.prayer,
    state: _fromBool(dnd),
    action: () => probe.requestDnd(),
    openSettings: () => probe.openAppSettings(),
    recheck: () async => _fromBool(await probe.dndGranted()),
  ));

  // Overlay: only for Focus Mode (tasks), and only on Android.
  if (probe.isAndroid && needsTasks) {
    final overlay = await probe.canDrawOverlays();
    rows.add(PermRow(
      id: PermId.overlay,
      icon: Icons.picture_in_picture_alt,
      title: 'overlay_permission_title',
      desc: 'overlay_permission_desc',
      color: Colors.deepOrange,
      group: PermGroup.focusMode,
      state: _fromBool(overlay),
      action: null,
      openSettings: () => probe.openOverlaySettings(),
      recheck: () async => _fromBool(await probe.canDrawOverlays()),
    ));
  }

  if (!showAll) {
    // The popup lists only what is missing, and never the rows below.
    return rows.where((r) => r.state == PermState.missing).toList();
  }

  // Notifications: needed in every mode (prayer alerts and task reminders).
  final notifications = await probe.notificationsGranted();
  rows.add(PermRow(
    id: PermId.notifications,
    icon: Icons.notifications_active_outlined,
    title: 'notification_permission_title',
    desc: 'notification_permission_desc',
    color: Colors.blue,
    group: PermGroup.prayer,
    state: _fromBool(notifications),
    action: () => probe.requestNotification(),
    openSettings: () => probe.openAppSettings(),
    recheck: () async => _fromBool(await probe.notificationsGranted()),
    explainsDenial: true,
  ));

  // Location: for prayer times, so not in tasks-only mode.
  if (needsPrayer) {
    final location = await probe.locationGranted();
    rows.add(PermRow(
      id: PermId.location,
      icon: Icons.location_on_outlined,
      title: 'location_permission_title',
      desc: 'location_permission_desc',
      color: Colors.teal,
      group: PermGroup.prayer,
      state: _fromBool(location),
      action: () => probe.requestLocation(),
      openSettings: () => probe.openAppSettings(),
      recheck: () async => _fromBool(await probe.locationGranted()),
      explainsDenial: true,
    ));
  }

  // EMUI Auto-launch: the app cannot read it, so it is never granted or missing.
  if (await probe.isEmuiDevice()) {
    rows.add(PermRow(
      id: PermId.autoLaunch,
      icon: Icons.rocket_launch_outlined,
      title: 'auto_launch_title',
      desc: 'auto_launch_subtitle',
      color: Colors.deepPurple,
      group: PermGroup.prayer,
      state: PermState.checkByHand,
      action: null,
      openSettings: () {},
      recheck: () async => PermState.checkByHand,
      showGuide: (context) => probe.showAutoLaunchGuide(context),
    ));
  }

  return rows;
}

/// The page summary: any missing row wins; a check-by-hand row alone never gives "all set".
PermSummary summarizePermissions(Iterable<PermState> states) {
  var hand = false;
  for (final s in states) {
    if (s == PermState.missing) return PermSummary.someMissing;
    if (s == PermState.checkByHand) hand = true;
  }
  return hand ? PermSummary.allSetPlusHand : PermSummary.allSet;
}

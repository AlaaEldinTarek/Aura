import 'package:aura_app/core/widgets/permission_rows.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

/// A scriptable [PermissionProbe] for the permissions page tests
/// (docs/designs/permissions-status-screen.md). Every state is a plain field, every
/// action is recorded in [calls].
class FakePermissionProbe implements PermissionProbe {
  String mode = 'both';
  @override
  bool isAndroid = true;
  bool exactAlarm = true;
  bool battery = true;
  bool dnd = true;
  bool overlay = true;
  bool notifications = true;
  bool location = true;
  bool emui = false;

  PermissionStatus notificationRequestResult = PermissionStatus.denied;
  PermissionStatus locationRequestResult = PermissionStatus.denied;
  PermissionStatus dndRequestResult = PermissionStatus.denied;

  final List<String> calls = [];

  @override
  Future<String> appMode() async => mode;
  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarm;
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => battery;
  @override
  Future<bool> dndGranted() async => dnd;
  @override
  Future<bool> canDrawOverlays() async => overlay;
  @override
  Future<bool> notificationsGranted() async => notifications;
  @override
  Future<bool> locationGranted() async => location;
  @override
  Future<bool> isEmuiDevice() async => emui;

  @override
  Future<PermissionStatus> requestDnd() async {
    calls.add('requestDnd');
    return dndRequestResult;
  }

  @override
  Future<PermissionStatus> requestNotification() async {
    calls.add('requestNotification');
    return notificationRequestResult;
  }

  @override
  Future<PermissionStatus> requestLocation() async {
    calls.add('requestLocation');
    return locationRequestResult;
  }

  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');
  @override
  Future<void> openExactAlarmSettings() async => calls.add('openExactAlarmSettings');
  @override
  Future<void> openBatterySettings() async => calls.add('openBatterySettings');
  @override
  Future<void> openOverlaySettings() async => calls.add('openOverlaySettings');
  @override
  Future<void> showAutoLaunchGuide(BuildContext context) async =>
      calls.add('showAutoLaunchGuide');
}

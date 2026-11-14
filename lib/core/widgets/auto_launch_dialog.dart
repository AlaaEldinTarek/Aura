import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/platform_channel_service.dart';

/// The explanation dialog behind the Huawei "App launch" tile (Settings) and the
/// permissions-page hint. It tells the user the EMUI menu path and the three
/// switches to turn on. Spec: docs/designs/fix-boot-start-service.md, section 3a, P1b.
///
/// "Open app details" opens Aura's app details screen and leaves the dialog open,
/// so the text stays readable after coming back. [openDetails] is a test seam; it
/// defaults to [PlatformChannelService.openAppDetails].
Future<void> showAutoLaunchDialog(
  BuildContext context, {
  Future<void> Function()? openDetails,
}) {
  final open = openDetails ?? PlatformChannelService.openAppDetails;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('auto_launch_dialog_title'.tr()),
      content: SingleChildScrollView(
        child: Text('auto_launch_dialog_body'.tr()),
      ),
      actions: [
        TextButton(
          onPressed: () => open(),
          child: Text('auto_launch_dialog_open_details'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('ok'.tr()),
        ),
      ],
    ),
  );
}

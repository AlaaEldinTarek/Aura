import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures the widget identified by [key] as a PNG and shares it.
/// On Windows/desktop, saves to Documents and opens the file instead.
Future<void> captureAndShare(GlobalKey key, String filename) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      // Desktop: no native share sheet — open the file directly
      final docsDir = await getApplicationDocumentsDirectory();
      final destFile = File('${docsDir.path}/$filename');
      await file.copy(destFile.path);
      // Use process launch to open the image in the default viewer
      if (Platform.isWindows) {
        await Process.run('explorer', [destFile.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [destFile.path]);
      }
    } else {
      await Share.shareXFiles([XFile(file.path)], text: '');
    }
  } catch (e) {
    debugPrint('captureAndShare error: $e');
  }
}

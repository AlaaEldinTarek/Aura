import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Moves an unreadable `shared_preferences.json` aside (F62).
///
/// `shared_preferences_windows` throws on invalid JSON or invalid UTF-8 and
/// start-up then never reaches `runApp`. A missing file, an empty file and any
/// valid JSON are left alone (the plugin reads those). The unreadable file is
/// renamed to `shared_preferences.json.unreadable-<yyyyMMdd-HHmmss>.bak`
/// (`-1`, `-2`, … if taken); nothing is deleted. Returns the backup path, or
/// null when nothing was moved. Never throws.
Future<String?> backUpUnreadablePrefsFile(Directory dir,
    {DateTime? now}) async {
  try {
    final file =
        File('${dir.path}${Platform.pathSeparator}shared_preferences.json');
    if (!file.existsSync()) return null;

    try {
      final text = utf8.decode(file.readAsBytesSync());
      if (text.isEmpty) return null;
      jsonDecode(text);
      return null;
    } on FormatException {
      // Invalid UTF-8 or invalid JSON: back it up below.
    }

    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    final base = '${file.path}.unreadable-$stamp';
    var target = '$base.bak';
    for (var i = 1; File(target).existsSync(); i++) {
      target = '$base-$i.bak';
    }
    file.renameSync(target);
    return target;
  } catch (e) {
    debugPrint('❌ [PREFS] Prefs file check failed: $e');
    return null;
  }
}

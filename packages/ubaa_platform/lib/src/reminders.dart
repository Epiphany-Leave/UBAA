import 'dart:convert';
import 'dart:io';

import 'paths.dart';

File _reminderFile(String account, String? directory) {
  final bytes = utf8.encode(account.trim());
  if (bytes.isEmpty || bytes.length > 100)
    throw ArgumentError('Invalid account key');
  // Hex avoids path separators and case collisions on Windows filesystems.
  final key = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return File(
    '${directory ?? defaultConfigDirectory()}/ui-reminders/$key.enabled',
  );
}

Future<bool> readYgdkHomeReminder(String account, {String? directory}) =>
    _reminderFile(account, directory).exists();

Future<void> saveYgdkHomeReminder(
  String account,
  bool enabled, {
  String? directory,
}) async {
  final file = _reminderFile(account, directory);
  if (enabled) {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const [], flush: true);
  } else if (await file.exists()) {
    await file.delete();
  }
}

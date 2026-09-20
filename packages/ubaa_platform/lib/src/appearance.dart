import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'paths.dart';

File _file() => File('${defaultConfigDirectory()}/ui-appearance.json');
Future<Map<Object?, Object?>> readAppearanceSettings() async {
  final file = _file();
  if (!await file.exists()) return {};
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

Future<void> _pendingSave = Future<void>.value();
Future<void> saveAppearanceSettings(Map<String, Object?> settings) {
  final snapshot = Map<String, Object?>.of(settings);
  final result = _pendingSave.then((_) => _save(snapshot));
  _pendingSave = result.catchError((Object _) {});
  return result;
}

Future<void> _save(Map<String, Object?> settings) async {
  final file = _file();
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(settings), flush: true);
  if (Platform.isAndroid) {
    await const MethodChannel(
      'cn.edu.ubaa/widget_schedule',
    ).invokeMethod<void>('selectTerm', settings['term']);
  }
}

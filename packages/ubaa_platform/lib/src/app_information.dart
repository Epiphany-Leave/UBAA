import 'package:flutter/services.dart';

const _appInformation = MethodChannel('cn.edu.ubaa/app_information');

/// Installed package metadata only; no school requests or session access.
Future<String?> readInstalledAppVersion() =>
    _appInformation.invokeMethod<String>('version');

Future<bool> openUbaaProject() async =>
    await _appInformation.invokeMethod<bool>('openProject') ?? false;

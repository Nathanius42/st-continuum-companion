import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The player's settings, remembered in settings.json: in %APPDATA%\Continuum Companion
/// on Windows and the app's files folder on Android (asked of MainActivity.kt,
/// as path_provider is a plugin). Elsewhere, and under `flutter test`, they
/// last for the session only.
class Settings {
  Settings._();

  static const _channel = MethodChannel('continuum_dex/sound');

  /// The LCARS beeps are off (#941).
  static final muted = ValueNotifier<bool>(false);

  /// Every screen in classic TNG LCARS, rather than each era's and faction's
  /// own interface (#592).
  static final classicLcars = ValueNotifier<bool>(false);

  static File? _file;

  static final bool _testing = Platform.environment.containsKey('FLUTTER_TEST');

  /// Reads the saved settings. Safe to call more than once.
  static Future<void> load() async {
    if (_testing) return;
    try {
      final dir = await _dir();
      if (dir == null) return;
      _file = File('${dir.path}${Platform.pathSeparator}settings.json');
      if (await _file!.exists()) {
        final json = jsonDecode(await _file!.readAsString());
        if (json is Map) {
          muted.value = json['muted'] == true;
          classicLcars.value = json['classicLcars'] == true;
        }
      }
    } on Exception {
      // No settings yet, or unreadable: keep the defaults.
    }
  }

  static Future<void> setMuted(bool value) async {
    muted.value = value;
    await _save();
  }

  static Future<void> setClassicLcars(bool value) async {
    classicLcars.value = value;
    await _save();
  }

  static Future<void> _save() async {
    try {
      await _file?.parent.create(recursive: true);
      await _file?.writeAsString(
        jsonEncode({'muted': muted.value, 'classicLcars': classicLcars.value}),
      );
    } on Exception {
      // Not remembered this time; the switch still works for the session.
    }
  }

  static Future<Directory?> _dir() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      return appData == null
          ? null
          : Directory('$appData\\Continuum Companion');
    }
    if (Platform.isAndroid) {
      final path = await _channel.invokeMethod<String>('filesDir');
      return path == null ? null : Directory(path);
    }
    return null;
  }
}

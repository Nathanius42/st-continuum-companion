import 'dart:io';

import 'package:flutter/services.dart';

const _links = MethodChannel('continuum_dex/links');

/// Opens [url] in the system browser. Only https links are opened, since every
/// link comes from the Dex's own data.
///
/// Done without a plugin, because Flutter plugins on Windows need Developer
/// Mode to build: Android hands the link to an intent (MainActivity.kt), and the
/// desktops pass it to the shell's own opener as a single argument, never
/// through a command line.
Future<bool> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    if (Platform.isAndroid) {
      return await _links.invokeMethod<bool>('open', url) ?? false;
    }
    if (Platform.isWindows) {
      await Process.start('rundll32', ['url.dll,FileProtocolHandler', url]);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [url]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', [url]);
      return true;
    }
  } on Exception {
    return false;
  }
  return false;
}

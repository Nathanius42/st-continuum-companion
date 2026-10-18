import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/settings.dart';

/// LCARS beeps (#941), from the STC website's sound set (assets/sounds/).
enum Beep {
  /// The splash's "request access".
  login('login_beep'),

  /// A button or sidebar block.
  tap('main_beep'),

  /// Opening a section of the front page.
  select('beep4'),

  /// Back and home.
  back('beep_41'),

  /// The library opening.
  processing('processing3'),

  /// Comms.
  hail('hail');

  const Beep(this.file);
  final String file;
}

/// Plays the beeps without a plugin, because Flutter plugins on Windows need
/// Developer Mode to build: Windows calls winmm's PlaySound on the bundled WAV,
/// Android plays it through SoundPool (MainActivity.kt). Elsewhere, under
/// `flutter test`, and when [Settings.muted] is on, it stays quiet.
class Sounds {
  Sounds._();

  static const _channel = MethodChannel('continuum_dex/sound');

  static final bool _testing = Platform.environment.containsKey('FLUTTER_TEST');

  static void play(Beep beep) {
    if (Settings.muted.value || _testing) return;
    try {
      if (Platform.isWindows) {
        _Winmm.instance?.play(beep.file);
      } else if (Platform.isAndroid) {
        _channel.invokeMethod<void>('play', beep.file);
      }
    } on Exception {
      // A missing beep never stops a button working.
    }
  }
}

typedef _PlaySoundNative = Int32 Function(Pointer<Uint16>, IntPtr, Uint32);
typedef _PlaySoundDart = int Function(Pointer<Uint16>, int, int);
typedef _AllocNative = Pointer<Void> Function(IntPtr);
typedef _AllocDart = Pointer<Void> Function(int);

/// winmm's PlaySoundW on the WAV files Flutter bundles beside the executable
/// (data/flutter_assets/assets/sounds/). The paths are kept for the life of the
/// app, because an asynchronous PlaySound reads its file name after returning.
class _Winmm {
  _Winmm._(this._playSound, this._alloc, this._folder);

  static final _Winmm? instance = _open();

  static _Winmm? _open() {
    try {
      final winmm = DynamicLibrary.open('winmm.dll');
      final ole32 = DynamicLibrary.open('ole32.dll');
      final exe = File(Platform.resolvedExecutable).parent.path;
      return _Winmm._(
        winmm.lookupFunction<_PlaySoundNative, _PlaySoundDart>('PlaySoundW'),
        ole32.lookupFunction<_AllocNative, _AllocDart>('CoTaskMemAlloc'),
        '$exe\\data\\flutter_assets\\assets\\sounds',
      );
    } on Object {
      return null;
    }
  }

  final _PlaySoundDart _playSound;
  final _AllocDart _alloc;
  final String _folder;
  final _paths = <String, Pointer<Uint16>>{};

  static const _async = 0x0001, _noDefault = 0x0002, _filename = 0x00020000;

  void play(String name) {
    final path = _paths.putIfAbsent(name, () {
      final units = '$_folder\\$name.wav'.codeUnits;
      final p = _alloc((units.length + 1) * 2).cast<Uint16>();
      for (var i = 0; i < units.length; i++) {
        p[i] = units[i];
      }
      p[units.length] = 0;
      return p;
    });
    _playSound(path, 0, _async | _noDefault | _filename);
  }
}

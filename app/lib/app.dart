import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/home_content.dart';
import 'data/settings.dart';
import 'data/ship_repository.dart';
import 'screens/front_page.dart';
import 'screens/splash_screen.dart';
import 'theme/dex_theme.dart';
import 'ui/sound.dart';

/// Root of Continuum Companion. Loads the bundled ship data, themes and front-page
/// content, then shows the splash, which opens the front page (#941).
class DexApp extends StatefulWidget {
  const DexApp({super.key, this.repository, this.themes});

  /// Supplied by tests; the app itself loads the bundled files.
  final ShipRepository? repository;
  final ThemeLibrary? themes;

  @override
  State<DexApp> createState() => _DexAppState();
}

class _DexAppState extends State<DexApp> {
  late final Future<(FrontPageData, ThemeLibrary)> _loaded = _load();
  final _navigator = GlobalKey<NavigatorState>();
  static final _classic = ThemeLibrary.classic();

  Future<(FrontPageData, ThemeLibrary)> _load() async {
    final bundle = DefaultAssetBundle.of(context);
    final repository = widget.repository ?? await ShipRepository.load(bundle);
    final themes =
        widget.themes ??
        await ThemeLibrary.load(bundle)
            .catchError((_) => ThemeLibrary.classic());
    final content = await HomeContent.load(bundle);
    await Settings.load();
    return (FrontPageData(repository: repository, content: content), themes);
  }

  /// Back a screen, or all the way to the front page, with the elbow's beep.
  /// Nothing happens on the first screen.
  void _go({required bool home}) {
    final nav = _navigator.currentState;
    if (nav == null || !nav.canPop()) return;
    Sounds.play(Beep.back);
    home ? nav.popUntil((route) => route.isFirst) : nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loaded,
      builder: (context, snapshot) {
        final loaded = snapshot.data;
        return MaterialApp(
          title: 'Continuum Companion',
          navigatorKey: _navigator,
          // Keyboard (#547): Escape or Alt+Left goes back, Alt+Home returns to
          // the front page, as BACK and HOME do. Tab and the arrow keys move
          // between controls, and Enter or Space presses one (Flutter's own).
          shortcuts: {
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.escape):
                const _BackIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
                const _BackIntent(),
            const SingleActivator(LogicalKeyboardKey.home, alt: true):
                const _HomeIntent(),
          },
          actions: {
            ...WidgetsApp.defaultActions,
            _BackIntent: CallbackAction<_BackIntent>(
              onInvoke: (_) => _go(home: false),
            ),
            _HomeIntent: CallbackAction<_HomeIntent>(
              onInvoke: (_) => _go(home: true),
            ),
          },
          debugShowCheckedModeBanner: false,
          theme: DexTheme.classic.toThemeData(),
          // Above the navigator, so every pushed screen can find the themes.
          // Classic LCARS everywhere (#592) swaps in the theme library that
          // has no era or faction looks.
          builder: (context, child) => loaded == null
              ? child!
              : ValueListenableBuilder<bool>(
                  valueListenable: Settings.classicLcars,
                  builder: (context, classic, _) => ThemeLibraryScope(
                    library: classic ? _classic : loaded.$2,
                    child: FrontPageScope(data: loaded.$1, child: child!),
                  ),
                ),
          home: switch (snapshot) {
            AsyncSnapshot(hasError: true) => Scaffold(
              body: Center(
                child: Text("Couldn't load the ship data: ${snapshot.error}"),
              ),
            ),
            _ when loaded == null => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            _ => SplashScreen(data: loaded.$1),
          },
        );
      },
    );
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _HomeIntent extends Intent {
  const _HomeIntent();
}

import 'dart:convert';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../ui/shapes.dart';

/// The shape family a theme's frame is drawn in (Design Language wiki page).
enum DexShape {
  /// TNG LCARS: rounded elbows and pill caps.
  lcars,

  /// Klingon: chamfered 45° corners and wedge-ended bars.
  angular,

  /// TOS: Matt Jefferies' consoles. Flat dark panels with square corners,
  /// small rectangular buttons and indicator lamps.
  console,

  /// The film era (TMP): circles and rings, after Okuda's radial displays.
  radial,

  /// Voth: rounded rectangles, softer than LCARS elbows.
  rounded,

  /// Cardassian: elliptical corners and trapezoid buttons.
  elliptical,

  /// Borg: a rigid grid, no curves.
  grid,

  /// The film era (TMP): slanted, outlined panels holding small oval buttons,
  /// after the Star Trek IV Enterprise-A consoles.
  film,

  /// Romulan: thin outlined frames with sharp slants, parallelogram buttons
  /// and short slanted accent bars along the top, after the warbird consoles.
  slanted,

  /// Dominion: heavy arches, the keyhole frames of the Jem'Hadar consoles.
  arched,

  /// ENT, before LCARS: grey bezels and buttons with a flat raised shading,
  /// after the NX-01's panels.
  panel,

  /// Gorn: bevelled khaki stone rims round dark screens, with glossy green
  /// buttons, after the Gorn interface in Starfleet Command II.
  stone,

  /// Ferengi: rounded device bezels with a thick darker rim.
  bezel;

  /// Drawn as thin outlines over a faint fill rather than solid blocks.
  bool get outlined => this == film || this == slanted;

  static DexShape parse(String? name) => DexShape.values.firstWhere(
    (s) => s.name == name,
    orElse: () => DexShape.lcars,
  );
}

/// Everything a screen needs to know about the current theme (#566). Screens and
/// the frame widgets read only from this, so a theme can change without any
/// screen changing.
///
/// The colours come from `assets/data/themes.json`, which the pipeline builds
/// from the hand-researched `data/themes.source.json`. The era sets the frame;
/// a faction with an interface of its own (Klingon, Romulan...) replaces it,
/// and other factions change only the accent.
@immutable
class DexTheme extends ThemeExtension<DexTheme> {
  const DexTheme({
    required this.background,
    required this.structure,
    required this.textOnStructure,
    required this.data,
    required this.accent,
    required this.textOnAccent,
    required this.highlight,
    required this.textOnBackground,
    required this.statusOk,
    required this.statusWarning,
    required this.statusAlert,
    required this.shape,
    this.headingFont,
    this.scriptFont,
    this.transition = const Duration(milliseconds: 300),
  });

  /// Classic TNG LCARS, used where no era is chosen yet (the home screen) and
  /// as the fallback if the theme file can't be read.
  static const classic = DexTheme(
    background: Color(0xFF000000),
    structure: [Color(0xFFEB943A), Color(0xFFEA9C72), Color(0xFFFFCC99)],
    textOnStructure: [Colors.black, Colors.black, Colors.black],
    data: [Color(0xFF8899FF), Color(0xFF99CCFF)],
    accent: Color(0xFFBAA4E5),
    textOnAccent: Colors.black,
    highlight: Color(0xFFEB943A),
    textOnBackground: Colors.white,
    statusOk: Color(0xFF99CCFF),
    statusWarning: Color(0xFFFFBB33),
    statusAlert: Color(0xFFFF2200),
    shape: DexShape.lcars,
    headingFont: 'LeagueGothic',
  );

  final Color background;

  /// Bars, elbows and sidebar blocks: three warm colours in LCARS.
  final List<Color> structure;

  /// Black or white, whichever reads better on each structure colour.
  final List<Color> textOnStructure;

  /// Cool colours for values and data.
  final List<Color> data;
  final Color accent;
  final Color textOnAccent;

  /// Titles, the selected item and values a variant changes.
  final Color highlight;
  final Color textOnBackground;
  final Color statusOk;
  final Color statusWarning;
  final Color statusAlert;
  final DexShape shape;

  /// Bundled font family for frame lettering, buttons and titles; null keeps
  /// the platform font. Body text always uses the platform font, so it stays
  /// readable.
  final String? headingFont;

  /// The faction's own script (Klingon, Romulan and so on), or null. It only
  /// decorates: the screen title is repeated in it, hidden from screen
  /// readers, and nothing is ever written in it alone.
  final String? scriptFont;

  /// Length of screen and state transitions; LCARS keeps them under a second.
  final Duration transition;

  /// Structure colour [i], cycling through the three.
  Color structureAt(int i) => structure[i % structure.length];
  Color textOnStructureAt(int i) => textOnStructure[i % textOnStructure.length];

  /// [base] in the heading font, for frame lettering, buttons and titles.
  TextStyle? heading(TextStyle? base) {
    if (headingFont == null) return base;
    final style = (base ?? const TextStyle()).copyWith(fontFamily: headingFont);
    final scale = _headingScale[headingFont] ?? 1;
    return style.fontSize == null || scale == 1
        ? style
        : style.copyWith(fontSize: style.fontSize! * scale);
  }

  /// Heading fonts narrower than the platform font are drawn larger, so small
  /// labels stay readable (League Gothic and Pathway Gothic are very
  /// condensed).
  static const _headingScale = {'LeagueGothic': 1.25, 'PathwayGothic': 1.2};

  static DexTheme of(BuildContext context) =>
      Theme.of(context).extension<DexTheme>() ?? classic;

  @override
  DexTheme copyWith({
    Color? accent,
    Color? textOnAccent,
    DexShape? shape,
    String? scriptFont,
  }) => DexTheme(
    background: background,
    structure: structure,
    textOnStructure: textOnStructure,
    data: data,
    accent: accent ?? this.accent,
    textOnAccent: textOnAccent ?? this.textOnAccent,
    highlight: highlight,
    textOnBackground: textOnBackground,
    statusOk: statusOk,
    statusWarning: statusWarning,
    statusAlert: statusAlert,
    shape: shape ?? this.shape,
    headingFont: headingFont,
    scriptFont: scriptFont ?? this.scriptFont,
    transition: transition,
  );

  @override
  DexTheme lerp(DexTheme? other, double t) {
    if (other == null) return this;
    List<Color> lerpAll(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i % b.length], t)!,
    ];
    return DexTheme(
      background: Color.lerp(background, other.background, t)!,
      structure: lerpAll(structure, other.structure),
      textOnStructure: t < 0.5 ? textOnStructure : other.textOnStructure,
      data: lerpAll(data, other.data),
      accent: Color.lerp(accent, other.accent, t)!,
      textOnAccent: t < 0.5 ? textOnAccent : other.textOnAccent,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      textOnBackground: Color.lerp(
        textOnBackground,
        other.textOnBackground,
        t,
      )!,
      statusOk: Color.lerp(statusOk, other.statusOk, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusAlert: Color.lerp(statusAlert, other.statusAlert, t)!,
      shape: t < 0.5 ? shape : other.shape,
      headingFont: t < 0.5 ? headingFont : other.headingFont,
      scriptFont: t < 0.5 ? scriptFont : other.scriptFont,
      transition: Duration(
        milliseconds: lerpDouble(
          transition.inMilliseconds,
          other.transition.inMilliseconds,
          t,
        )!.round(),
      ),
    );
  }

  /// A Material theme whose colours follow these tokens, so stock widgets
  /// (chips, list tiles, progress indicators) match the frame.
  ThemeData toThemeData() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: structure.first,
          brightness: Brightness.dark,
        ).copyWith(
          surface: background,
          onSurface: textOnBackground,
          primary: structure.first,
          onPrimary: textOnStructure.first,
          secondary: data.first,
          onSecondary: Colors.black,
          tertiary: accent,
          onTertiary: textOnAccent,
          error: statusAlert,
        );
    final base = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: [this],
    );
    final label = base.textTheme.labelLarge;
    return base.copyWith(
      // Keyboard focus (#547): a light wash over the focused button or block,
      // strong enough to see on the bright LCARS colours.
      focusColor: Colors.white.withValues(alpha: 0.45),
      // Recolour the stock text styles rather than replacing them, so the font is kept.
      chipTheme: ChipThemeData(
        selectedColor: accent,
        backgroundColor: background,
        side: BorderSide(color: data.first.withValues(alpha: 0.6)),
        labelStyle: label?.copyWith(color: textOnBackground),
        secondaryLabelStyle: label?.copyWith(color: textOnAccent),
        checkmarkColor: textOnAccent,
        shape: switch (shape) {
          DexShape.lcars => const StadiumBorder(),
          DexShape.angular => const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          DexShape.console => const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          DexShape.radial => const StadiumBorder(),
          DexShape.rounded => const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          DexShape.elliptical => const TrapezoidBorder(slant: 0.35),
          DexShape.grid => const RoundedRectangleBorder(),
          DexShape.film => const StadiumBorder(),
          DexShape.slanted => const ParallelogramBorder(slant: 0.35),
          DexShape.arched => const StadiumBorder(),
          DexShape.panel => const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          DexShape.stone => const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
          DexShape.bezel => const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        },
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: highlight,
        selectedTileColor: highlight.withValues(alpha: 0.12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Every theme from `assets/data/themes.json`: a frame per era, and per faction
/// either a frame of its own or an accent.
class ThemeLibrary {
  ThemeLibrary(this._json);

  static const asset = 'assets/data/themes.json';

  /// No theme file: classic LCARS everywhere.
  ThemeLibrary.classic() : _json = const {};

  final Map<String, dynamic> _json;

  static Future<ThemeLibrary> load(AssetBundle bundle) async => ThemeLibrary(
    jsonDecode(await bundle.loadString(asset)) as Map<String, dynamic>,
  );

  /// The theme for [era], with [faction]'s own frame in place of it if the
  /// faction has one, or just its accent if not.
  DexTheme resolve({String? era, String? faction}) {
    final eraJson =
        (_json['eras'] as Map<String, dynamic>?)?[era] as Map<String, dynamic>?;
    final theme = eraJson == null ? DexTheme.classic : _frameTheme(eraJson);
    final f =
        (_json['factions'] as Map<String, dynamic>?)?[faction]
            as Map<String, dynamic>?;
    if (f == null) return theme;
    final script = f['scriptFont'] as String?;
    if (f['frame'] != null) {
      return _frameTheme(f['frame'] as Map<String, dynamic>)
          .copyWith(scriptFont: script);
    }
    return theme.copyWith(
      accent: f['accent'] == null ? null : _colour(f['accent'] as String),
      textOnAccent: f['textOnAccent'] == null
          ? null
          : _colour(f['textOnAccent'] as String),
      scriptFont: script,
    );
  }

  static DexTheme _frameTheme(Map<String, dynamic> json) {
    final c = json['colours'] as Map<String, dynamic>;
    List<Color> all(String key) => [
      for (final h in c[key] as List) _colour(h as String),
    ];
    return DexTheme(
      background: _colour(c['background'] as String),
      structure: all('structure'),
      textOnStructure: all('textOnStructure'),
      data: all('data'),
      accent: _colour(c['accent'] as String),
      textOnAccent: _colour(c['textOnAccent'] as String),
      highlight: _colour(
        (c['highlight'] ?? (c['structure'] as List).first) as String,
      ),
      textOnBackground: _colour(c['textOnBackground'] as String),
      statusOk: _colour(c['statusOk'] as String),
      statusWarning: _colour(c['statusWarning'] as String),
      statusAlert: _colour(c['statusAlert'] as String),
      shape: DexShape.parse(json['shape'] as String?),
      headingFont: json['headingFont'] as String?,
    );
  }

  static Color _colour(String hex) =>
      Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
}

/// Makes the [ThemeLibrary] available below it, so any screen can theme itself
/// for its era and faction with [DexThemeScope].
class ThemeLibraryScope extends InheritedWidget {
  const ThemeLibraryScope({
    super.key,
    required this.library,
    required super.child,
  });

  final ThemeLibrary library;

  static ThemeLibrary of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ThemeLibraryScope>()
          ?.library ??
      ThemeLibrary.classic();

  @override
  bool updateShouldNotify(ThemeLibraryScope oldWidget) =>
      library != oldWidget.library;
}

/// Themes [child] for an era and, optionally, a faction (#569).
class DexThemeScope extends StatelessWidget {
  const DexThemeScope({super.key, this.era, this.faction, required this.child});

  final String? era;
  final String? faction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeLibraryScope.of(context)
        .resolve(era: era, faction: faction);
    return AnimatedTheme(
      data: theme.toThemeData(),
      duration: theme.transition,
      child: child,
    );
  }
}

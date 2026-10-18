import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/home_content.dart';
import '../data/settings.dart';
import '../data/ship_repository.dart';
import '../theme/dex_theme.dart';
import '../ui/lcars.dart';
import '../ui/lcars_display.dart';
import '../ui/lcars_motion.dart';
import '../ui/sound.dart';
import '../version.dart';
import 'info_screens.dart';
import 'factions_screen.dart';
import 'search_screen.dart';
import 'ship_library_screen.dart';

/// The front page's sections, in sidebar order.
enum Section {
  library('Starship Database', Beep.processing),
  search('Search', Beep.select),
  factions('Factions', Beep.select),
  about('About', Beep.select),
  comms('Comms', Beep.hail),
  access('Access', Beep.select),
  media('Media', Beep.select);

  const Section(this.label, this.beep);
  final String label;

  /// Played when the section opens.
  final Beep beep;
}

/// Everything a section needs: the ships for the library and factions, the
/// bundled text for the rest.
class FrontPageData {
  const FrontPageData({required this.repository, required this.content});

  final ShipRepository repository;
  final HomeContent content;
}

Widget _sectionScreen(Section s, FrontPageData d) => switch (s) {
  Section.library => ShipLibraryScreen(repository: d.repository),
  Section.search => SearchScreen(data: d),
  Section.factions => FactionsScreen(data: d),
  Section.about => AboutScreen(data: d),
  Section.comms => CommsScreen(data: d),
  Section.access => AccessScreen(data: d),
  Section.media => MediaScreen(data: d),
};

/// Makes the [FrontPageData] available to any screen, such as the ship page's
/// Compare button, which needs the search screen.
class FrontPageScope extends InheritedWidget {
  const FrontPageScope({super.key, required this.data, required super.child});

  final FrontPageData data;

  static FrontPageData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrontPageScope>()?.data;

  @override
  bool updateShouldNotify(FrontPageScope oldWidget) => data != oldWidget.data;
}

/// Opens [section] from the front page, or swaps to it from another section so
/// the back button still returns to the front page.
void openSection(
  BuildContext context,
  Section section,
  FrontPageData data, {
  bool sibling = false,
}) {
  if (sibling) {
    replaceWithSibling(context, (_) => _sectionScreen(section, data));
  } else {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _sectionScreen(section, data)),
    );
  }
}

/// The sidebar every section shares, so the others are one tap away.
List<LcarsNavItem> sectionNav(
  BuildContext context,
  FrontPageData data, {
  Section? current,
}) => [
  for (final s in Section.values)
    LcarsNavItem(
      label: s.label,
      selected: s == current,
      beep: s.beep,
      onTap: () => openSection(context, s, data, sibling: current != null),
    ),
];

/// The sections as sidebar blocks for a TNG display ([LcarsDisplay]).
List<LcarsItem> sectionItems(
  BuildContext context,
  FrontPageData data, {
  Section? current,
}) {
  const colours = [
    LcarsColours.periwinkle,
    LcarsColours.gold,
    LcarsColours.lilac,
    LcarsColours.coral,
  ];
  return [
    for (final (i, n) in sectionNav(context, data, current: current).indexed)
      LcarsItem(
        label: n.label,
        colour: colours[i % colours.length],
        selected: n.selected,
        beep: n.beep,
        onTap: n.onTap,
      ),
  ];
}

/// The front page's own palette, sampled from the TNG display it's modelled on:
/// corals, salmon and orange for the frame, rose, mauve, lavender and pink for
/// the controls.
abstract final class _Home {
  static const coral = Color(0xFFDA6557);
  static const salmon = Color(0xFFEC8D83);
  static const orange = Color(0xFFFF7F30);
  static const rose = Color(0xFFC27C85);
  static const mauve = Color(0xFF935E78);
  static const lavender = Color(0xFFC8A6DB);
  static const pink = Color(0xFFDA80B7);
  static const plum = Color(0xFF4C313F);
  static const figure = Color(0xFFFF9854);
}

/// The front page (#941), modelled on a TNG status display: a top section
/// framed by an elbow down the left holds the mod's logo; a bar sweeps across
/// the middle and down the right, like an S; and the bottom section holds the
/// menu, one button per section, with the settings in the right-hand column
/// and the versions along the bottom bar. No sidebar: the menu is the page.
class FrontPage extends StatelessWidget {
  const FrontPage({super.key, required this.data});

  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    return DexThemeScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final g = _HomeGeometry(c.maxWidth, c.maxHeight);
              return SingleChildScrollView(
                child: SizedBox(
                  width: g.width,
                  height: g.height,
                  child: _HomeLayout(g: g, data: data),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Where everything on the front page goes, worked out from the width so the
/// frame can be painted in one piece around content of a known size.
class _HomeGeometry {
  /// Fits [available] height where it can: the logo shrinks (to no less than
  /// 80 high) before the page scrolls, and spare height goes to the bottom
  /// section, so the frame always reaches the foot of the screen.
  _HomeGeometry(this.width, double available) {
    final w = width - 2 * pad;
    left = (w * 0.17).clamp(64, 130).toDouble();
    right = (w * 0.2).clamp(84, 170).toDouble();
    bar = (w * 0.045).clamp(16, 26).toDouble();
    gap = (bar * 0.25).clamp(4, 6).toDouble();
    outer = left * 0.7;
    inner = bar * 1.1;

    // Top section: the logo, as big as fits but no taller than 200.
    final logoRoom = w - left - gap * 4;
    var logoWidth = math.min(logoRoom, 200 * _logoAspect);

    // Middle: just the sweep of the bar.
    middleH = math.max(outer + gap, bar + inner + gap * 2);

    // Bottom section: the menu rows.
    var row = width < 600 ? 50.0 : 56.0;
    final menuRoom = w - right - gap * 6;
    columns = menuRoom >= 760 ? 2 : 1;
    columnW = math.min(420, (menuRoom - (columns - 1) * gap * 4) / columns);
    final rows = (Section.values.length / columns).ceil();
    final menuH = rows * row + (rows - 1) * gap * 2;
    // The right-hand column: two elbows and four blocks, two of them switches.
    final columnH = 2 * (inner + right * 0.15) + 4 * 48 + 5 * gap;
    var bottom = math.max(menuH, columnH) + gap * 8 + bar * 2;

    double top(double logoWidth) =>
        bar + gap * 4 + logoWidth / _logoAspect + gap * 4;
    final excess = top(logoWidth) + middleH + bottom + pad - available;
    if (excess > 0) {
      final h = math.max(70.0, logoWidth / _logoAspect - excess);
      logoWidth = math.min(logoWidth, h * _logoAspect);
    }
    logoW = logoWidth;
    logoH = logoW / _logoAspect;
    topH = top(logoW);
    final spare = available - (topH + middleH + bottom + pad);
    if (spare > 0) {
      bottom += spare;
      // Taller rows, up to 64, rather than empty space under the menu.
      row += math.min(spare * 0.8 / rows, 64 - row);
    }
    rowH = row;
    bottomH = bottom;
    height = topH + middleH + bottomH + pad;
  }

  static const pad = 6.0;

  /// The logo as drawn: the part of its 720 × 226 frame it actually fills.
  static const logoCrop = Rect.fromLTRB(104, 52, 626, 176);
  static final _logoAspect = logoCrop.width / logoCrop.height;
  final double width;
  late final double left, right, bar, gap, outer, inner;
  late final double logoW, logoH, topH, middleH, rowH, columnW, bottomH;
  late final int columns;
  late final double height;

  double get contentLeft => pad + left + gap * 4;

  /// Room at the end of the top bar for "STARDATE" and today's stardate.
  double get stardateW => bar * 11;

  /// The logo's left edge, centring it between the sidebar and the right edge.
  double get logoLeft {
    final innerLeft = pad + left;
    return innerLeft + (width - pad - innerLeft - logoW) / 2;
  }

  double get midY => topH + middleH; // bottom edge of the middle bar
  double get menuTop => midY + gap * 4;
  double get menuRight => width - pad - right - gap * 4;
  double get bottomBarTop => topH + middleH + bottomH - bar;
}

class _HomeLayout extends StatelessWidget {
  const _HomeLayout({required this.g, required this.data});

  final _HomeGeometry g;
  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final text = Theme.of(context).textTheme;
    final ships = data.repository.data;
    final date = ships.generatedAt.toIso8601String().substring(0, 10);
    TextStyle? label(double size, Color colour) => theme
        .heading(text.labelLarge)
        ?.copyWith(fontSize: size, color: colour, letterSpacing: 1, height: 1);

    // Right-hand column: the space between its two elbows.
    final columnTop = g.midY - g.bar + g.inner + g.right * 0.15 + g.gap;
    final columnBottom = g.bottomBarTop - g.inner - g.right * 0.15 - g.gap;
    final blockH = (columnBottom - columnTop - 3 * g.gap) / 4;
    final columnX = g.width - _HomeGeometry.pad - g.right;
    Positioned block(int i, Widget child) => Positioned(
      left: columnX,
      top: columnTop + i * (blockH + g.gap),
      width: g.right,
      height: blockH,
      child: child,
    );

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _HomeFramePainter(g))),

        // Top bar: today's stardate at its end.
        Positioned(
          right: _HomeGeometry.pad,
          top: 0,
          height: g.bar * 1.5,
          width: g.stardateW,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topRight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                ExcludeSemantics(
                  child: Text(
                    'STARDATE ',
                    style: theme
                        .heading(text.titleLarge)
                        ?.copyWith(color: _Home.salmon, height: 1),
                  ),
                ),
                Stardate(
                  style: theme
                      .heading(text.headlineMedium)
                      ?.copyWith(color: _Home.figure, height: 1),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: _HomeGeometry.pad + g.left + g.inner + g.left * 0.6 + g.gap,
          top: 0,
          width: g.left * 0.55,
          height: g.bar,
          child: _BarLabel('47', style: label(g.bar * 0.6, _Home.salmon)),
        ),
        // The elbow's label, where the sidebar meets the middle.
        Positioned(
          left: _HomeGeometry.pad,
          top: g.topH - g.gap - g.bar * 1.2,
          width: g.left - 6,
          height: g.bar,
          child: _BarLabel('02-4024', style: label(g.bar * 0.6, Colors.black)),
        ),

        // The logo, centred in the top section's frame.
        Positioned(
          left: g.logoLeft,
          top: g.bar + g.gap * 4,
          width: g.logoW,
          height: g.logoH,
          child: const _Logo(),
        ),

        // Middle: the bar's label.
        Positioned(
          right: _HomeGeometry.pad + g.right * 1.3 + g.inner,
          top: g.midY - g.bar,
          width: math.min(g.width * 0.42, 300),
          height: g.bar,
          child: ColoredBox(
            color: _Home.salmon,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _BarLabel(
                'Library computer access',
                style: label(g.bar * 0.7, Colors.black),
              ),
            ),
          ),
        ),

        // The menu.
        Positioned(
          left: _HomeGeometry.pad,
          top: g.menuTop,
          width: g.menuRight - _HomeGeometry.pad,
          child: _Menu(g: g, data: data),
        ),

        // Right-hand column: the settings between two plain blocks.
        block(0, const _ColumnBlock(colour: _Home.coral, label: '08-1')),
        block(
          1,
          ValueListenableBuilder<bool>(
            valueListenable: Settings.muted,
            builder: (context, muted, _) => _ColumnBlock(
              colour: muted ? _Home.mauve : _Home.orange,
              label: muted ? 'Audio off' : 'Audio on',
              toggled: !muted,
              onTap: () => Settings.setMuted(!muted),
            ),
          ),
        ),
        block(
          2,
          ValueListenableBuilder<bool>(
            valueListenable: Settings.classicLcars,
            builder: (context, classic, _) => _ColumnBlock(
              colour: classic ? _Home.orange : _Home.coral,
              label: classic ? 'Classic LCARS' : 'Era interfaces',
              caption: classic ? 'All eras' : 'By era',
              toggled: classic,
              onTap: () => Settings.setClassicLcars(!classic),
            ),
          ),
        ),
        block(3, const _ColumnBlock(colour: _Home.salmon, label: '08-40')),

        // Bottom bar: the app and data versions.
        Positioned(
          left: _HomeGeometry.pad + g.bar,
          top: g.bottomBarTop,
          width: g.menuRight - _HomeGeometry.pad - g.bar * 2,
          height: g.bar,
          child: Semantics(
            label:
                'Continuum Companion $appVersion (build $appBuild) · ship data r${ships.modRevision}, $date',
            excludeSemantics: true,
            child: _BarLabel(
              'Continuum Companion $appVersion · ship data r${ships.modRevision} · $date',
              style: label(g.bar * 0.7, Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small capitals on a bar, shrinking to fit it.
class _BarLabel extends StatelessWidget {
  const _BarLabel(this.text, {this.style, this.twoLines = false});

  final String text;
  final TextStyle? style;

  /// One word to a line.
  final bool twoLines;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomRight,
      child: Text(
        twoLines
            ? text.toUpperCase().replaceAll(' ', '\n')
            : text.toUpperCase(),
        maxLines: twoLines ? 2 : 1,
        textAlign: TextAlign.right,
        style: style?.copyWith(height: twoLines ? 1.05 : null),
      ),
    ),
  );
}

/// The menu: a row per section in the display's style, a rounded block with
/// the name, a figure, and a square tail with a caption.
class _Menu extends StatelessWidget {
  const _Menu({required this.g, required this.data});

  final _HomeGeometry g;
  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    final ships = data.repository.data;
    final rows = [
      for (final (i, s) in Section.values.indexed)
        _MenuRow(
          section: s,
          height: g.rowH,
          index: i,
          figure: switch (s) {
            Section.library => ships.ships.length.toString(),
            Section.search => ships.eras.length.toString().padLeft(2, '0'),
            Section.factions => ships.factions.length.toString(),
            Section.media => data.content.media.length.toString().padLeft(
              2,
              '0',
            ),
            _ => (i + 1).toString().padLeft(2, '0'),
          },
          caption: switch (s) {
            Section.search => 'Eras',
            Section.factions => 'Powers',
            Section.about => 'Mission',
            Section.comms => 'Discord',
            Section.access => 'Downloads',
            Section.media => 'Trailers',
            Section.library => 'Entries',
          },
          counted: const {
            Section.library,
            Section.search,
            Section.factions,
            Section.media,
          }.contains(s),
          onTap: () => openSection(context, s, data),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: g.gap * 4,
          runSpacing: g.gap * 2,
          children: [
            for (final r in rows) SizedBox(width: g.columnW, child: r),
          ],
        ),
      ],
    );
  }
}

/// A tappable piece of the front page, with its beep, its name for screen
/// readers, and keyboard focus.
class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.label,
    required this.onTap,
    required this.child,
    this.beep = Beep.select,
    this.toggled,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final Beep beep;
  final bool? toggled;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    toggled: toggled,
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          Sounds.play(beep);
          onTap();
        },
        child: child,
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.section,
    required this.height,
    required this.index,
    required this.figure,
    required this.caption,
    required this.onTap,
    this.counted = false,
  });

  final Section section;

  /// Whether [figure] counts something (entries, eras), rather than being a code.
  final bool counted;
  final double height;
  final int index;
  final String figure;
  final String caption;
  final VoidCallback onTap;

  static const _blocks = [_Home.rose, _Home.mauve, _Home.coral, _Home.salmon];
  static const _tails = [
    _Home.lavender,
    _Home.pink,
    _Home.lavender,
    _Home.orange,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final text = Theme.of(context).textTheme;
    final block = _blocks[index % _blocks.length];
    final tail = _tails[index % _tails.length];
    TextStyle? small(double size) => theme
        .heading(text.labelLarge)
        ?.copyWith(
          color: Colors.black,
          fontSize: size,
          letterSpacing: 1,
          height: 1,
        );
    return _HomeButton(
      // Counts are read with their caption; the other figures are decoration.
      label: counted
          ? '${section.label}, ${int.parse(figure)} ${caption.toLowerCase()}'
          : '${section.label}, $caption',
      beep: section.beep,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                height: height,
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 5),
                decoration: BoxDecoration(
                  color: block,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(height / 2),
                  ),
                ),
                // Two-word names (Starship Database) take two lines.
                child: _BarLabel(
                  section.label,
                  style: small(height * 0.36),
                  twoLines: section.label.contains(' '),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: height * 1.1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  figure,
                  style: theme
                      .heading(text.displaySmall)
                      ?.copyWith(
                        color: block,
                        fontSize: height * 0.85,
                        height: 1,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: Container(
                height: height,
                color: tail,
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                child: _BarLabel(caption, style: small(height * 0.28)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A block in the right-hand column: plain, or a switch.
class _ColumnBlock extends StatelessWidget {
  const _ColumnBlock({
    required this.colour,
    required this.label,
    this.caption,
    this.toggled,
    this.onTap,
  });

  final Color colour;
  final String label;
  final String? caption;
  final bool? toggled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final text = Theme.of(context).textTheme;
    final style = theme
        .heading(text.labelLarge)
        ?.copyWith(color: Colors.black, letterSpacing: 1, height: 1.05);
    final face = Container(
      color: colour,
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 6),
      alignment: Alignment.bottomRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomRight,
        child: Text(
          [label, ?caption].map((s) => s.toUpperCase()).join('\n'),
          textAlign: TextAlign.right,
          style: style,
        ),
      ),
    );
    if (onTap == null) return ExcludeSemantics(child: face);
    return _HomeButton(
      label: caption == null ? label : '$label, $caption',
      toggled: toggled,
      onTap: onTap!,
      beep: Beep.tap,
      child: face,
    );
  }
}

/// The frame: the top-left elbow and sidebar, the S of the middle bar sweeping
/// down the right, and the bottom bar.
class _HomeFramePainter extends CustomPainter {
  _HomeFramePainter(this.g);

  final _HomeGeometry g;

  /// An elbow in the top-left corner of [r]: an arm [arm] wide down the left
  /// and a bar [bar] high along the top, drawn into another corner by flipping.
  void _elbow(
    Canvas canvas,
    Rect r, {
    required double arm,
    required double bar,
    required double outer,
    required double inner,
    required Color colour,
    bool flipX = false,
    bool flipY = false,
  }) {
    canvas.save();
    canvas.translate(flipX ? r.right : r.left, flipY ? r.bottom : r.top);
    canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    final w = r.width, h = r.height;
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, outer)
      ..arcToPoint(Offset(outer, 0), radius: Radius.circular(outer))
      ..lineTo(w, 0)
      ..lineTo(w, bar)
      ..lineTo(arm + inner, bar)
      ..arcToPoint(
        Offset(arm, bar + inner),
        radius: Radius.circular(inner),
        clockwise: false,
      )
      ..lineTo(arm, h)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
    canvas.restore();
  }

  void _bar(Canvas canvas, double x0, double x1, double y, double h, Color c) {
    if (x1 > x0) {
      canvas.drawRect(Rect.fromLTRB(x0, y, x1, y + h), Paint()..color = c);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = _HomeGeometry.pad;
    final gap = g.gap, bar = g.bar;
    final right = size.width - pad;
    final elbowW = g.left + g.inner + g.left * 0.6;

    // Top section: the elbow, then the top bar's pieces up to the stardate.
    _elbow(
      canvas,
      Rect.fromLTWH(pad, 0, elbowW, g.topH - gap),
      arm: g.left,
      bar: bar,
      outer: g.outer,
      inner: g.inner,
      colour: _Home.coral,
    );
    var x = pad + elbowW + gap;
    _bar(canvas, x, x + g.left * 0.55, 0, bar, _Home.plum);
    x += g.left * 0.55 + gap;
    _bar(canvas, x, right - g.stardateW - gap, 0, bar, _Home.salmon);

    // Middle: the elbow out of the sidebar into the bar, which runs across and
    // turns down into the right-hand column.
    final midTop = g.topH;
    _elbow(
      canvas,
      Rect.fromLTWH(pad, midTop, elbowW, g.middleH),
      arm: g.left,
      bar: bar,
      outer: g.outer,
      inner: g.inner,
      colour: _Home.salmon,
      flipY: true,
    );
    final barY = g.midY - bar;
    final rightElbowW = g.right + g.inner + g.right * 0.15;
    final labelW = math.min(size.width * 0.42, 300.0);
    final labelRight = right - g.right * 1.3 - g.inner;
    _bar(
      canvas,
      pad + elbowW + gap,
      labelRight - labelW - gap,
      barY,
      bar,
      _Home.salmon,
    );
    _elbow(
      canvas,
      Rect.fromLTWH(
        right - rightElbowW,
        barY,
        rightElbowW,
        g.inner + g.right * 0.15 + bar,
      ),
      arm: g.right,
      bar: bar,
      outer: g.right * 0.6,
      inner: g.inner,
      colour: _Home.coral,
      flipX: true,
    );

    // Bottom: the right-hand column turns into the bottom bar.
    final bottomTop = g.bottomBarTop;
    final cornerH = g.inner + g.right * 0.15 + bar;
    _elbow(
      canvas,
      Rect.fromLTWH(
        right - rightElbowW,
        bottomTop + bar - cornerH,
        rightElbowW,
        cornerH,
      ),
      arm: g.right,
      bar: bar,
      outer: g.right * 0.6,
      inner: g.inner,
      colour: _Home.salmon,
      flipX: true,
      flipY: true,
    );
    final barEnd = right - rightElbowW - gap;
    final rr = RRect.fromLTRBAndCorners(
      pad,
      bottomTop,
      g.menuRight - bar,
      bottomTop + bar,
      topLeft: Radius.circular(bar / 2),
      bottomLeft: Radius.circular(bar / 2),
    );
    canvas.drawRRect(rr, Paint()..color = _Home.salmon);
    _bar(canvas, g.menuRight - bar + gap, barEnd, bottomTop, bar, _Home.coral);
  }

  @override
  bool shouldRepaint(_HomeFramePainter old) =>
      old.g.width != g.width || old.g.height != g.height;
}

/// The mod's animated logo (animatics/STC_Logo.webm, converted to WebP): it
/// plays once, then the still takes over; a tap plays it again. The animation
/// opens on black frames, so it only shows while it's actually playing: once it
/// ends, or as soon as another screen covers the front page, the still stands
/// in, and coming back never finds it stalled on a black frame.
class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> {
  static const _still = AssetImage('assets/home/stc_logo_still.webp');

  /// 114 frames at 50 ms.
  static const _length = Duration(milliseconds: 114 * 50 + 300);

  int _plays = 0;
  bool _playing = true;
  Timer? _end;

  @override
  void initState() {
    super.initState();
    _end = Timer(_length, _stop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_still, context);
    // Covered by another screen: settle on the still.
    if (!TickerMode.valuesOf(context).enabled && _playing) _stop();
  }

  void _stop() {
    _end?.cancel();
    if (mounted && _playing) setState(() => _playing = false);
  }

  void _replay() {
    _end?.cancel();
    setState(() {
      _plays++;
      _playing = true;
    });
    _end = Timer(_length, _stop);
  }

  @override
  void dispose() {
    _end?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = motionAllowed(context) && _playing;
    return Semantics(
      image: true,
      label: 'Star Trek: Continuum',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: motionAllowed(context) ? _replay : null,
        // The frame is mostly black margin: draw it so the logo itself
        // fills the box, and clip the margin off.
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, c) {
              const crop = _HomeGeometry.logoCrop;
              final k = c.maxWidth / crop.width;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -crop.left * k,
                    top: -crop.top * k,
                    width: 720 * k,
                    height: 226 * k,
                    child: Image(
                      image: animate
                          ? _ReplayAsset('assets/home/stc_logo.webp', _plays)
                          : _still,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// An asset image keyed by play count, so each play starts from the first frame.
class _ReplayAsset extends AssetImage {
  const _ReplayAsset(super.assetName, this.play);

  final int play;

  @override
  bool operator ==(Object other) =>
      other is _ReplayAsset &&
      other.assetName == assetName &&
      other.play == play;

  @override
  int get hashCode => Object.hash(assetName, play);
}

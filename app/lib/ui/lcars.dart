import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dex_theme.dart';
import 'shapes.dart';
import 'sound.dart';

/// LCARS frame and controls (#511), drawn from the current [DexTheme], so the
/// same screens become rounded LCARS, film-era rings, angular Klingon, rounded
/// Romulan, elliptical Cardassian, film-era outlined panels or flat consoles.
///
/// Proportions follow the fan-standard measurements on the Design Language
/// wiki page, all relative to the sidebar width S:
/// top bar 0.53 S, bottom bar 0.47 S, elbow inner radius 0.47 S,
/// gap between elbow and bar 0.09 S, gap between sidebar blocks 0.06 S.
class LcarsMetrics {
  LcarsMetrics(this.s)
    : topBar = 0.53 * s,
      bottomBar = 0.47 * s,
      innerRadius = 0.47 * s,
      gap = (0.09 * s).clamp(3, 8),
      blockGap = (0.06 * s).clamp(2, 6);

  /// Sidebar width for a window of [width]: narrower on a phone.
  factory LcarsMetrics.forWidth(double width) =>
      LcarsMetrics(width < 600 ? 52 : 80);

  final double s;
  final double topBar;
  final double bottomBar;
  final double innerRadius;
  final double gap;
  final double blockGap;
}

/// A sidebar block that switches to a sibling of the current screen, such as
/// another era on the faction list.
class LcarsNavItem {
  const LcarsNavItem({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.beep = Beep.tap,
  });

  final String label;
  final VoidCallback onTap;

  /// Played on a tap.
  final Beep beep;

  /// Shown in place of the label, such as the faction's badge; built at the size
  /// given, which fits the block. The label stays as its tooltip and its name
  /// for screen readers.
  final Widget Function(double size)? icon;

  /// The screen being shown; drawn in the highlight colour and not tappable.
  final bool selected;
}

/// A screen inside an LCARS frame: an elbow and title bar at the top, a sidebar
/// of coloured blocks down the left, and a closing elbow at the bottom.
///
/// The top elbow is the back button when there's somewhere to go back to.
class LcarsFrame extends StatelessWidget {
  const LcarsFrame({
    super.key,
    required this.title,
    required this.child,
    this.sidebarLabels = const [],
    this.sidebarNav,
    this.footer,
    this.emblem,
  });

  final String title;
  final Widget child;

  /// Small labels for the sidebar blocks, top to bottom (up to four blocks).
  final List<String> sidebarLabels;

  /// When given, the sidebar lists these instead of [sidebarLabels]: the
  /// options of the list one level up, so a sibling is one tap away.
  final List<LcarsNavItem>? sidebarNav;

  /// Text on the bottom bar.
  final String? footer;

  /// Shown on the first sidebar block, such as the faction's emblem.
  final Widget? emblem;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    // Whether there is a screen below this one, not above it: the route's own
    // view, which also rebuilds the frame when that changes.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final chrome = TextStyle(fontFamily: theme.headingFont);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final m = LcarsMetrics.forWidth(constraints.maxWidth);
              final elbowWidth = m.s + m.innerRadius + m.s;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DefaultTextStyle.merge(
                    style: chrome,
                    child: SizedBox(
                      height: m.topBar + m.innerRadius,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Elbow(
                            metrics: m,
                            barHeight: m.topBar,
                            width: elbowWidth,
                            colour: theme.structureAt(0),
                            top: true,
                            // The radial hub is itself the button; a label would sit on its rings.
                            label: canPop && theme.shape != DexShape.radial
                                ? 'BACK'
                                : null,
                            labelColour: theme.textOnStructureAt(0),
                            onTap: canPop
                                ? () => Navigator.of(context).maybePop()
                                : null,
                            semanticLabel: 'Back',
                          ),
                          SizedBox(width: m.gap),
                          Expanded(
                            child: _Bar(
                              height: m.topBar,
                              colour: theme.structureAt(0),
                              // Long titles shrink to fit rather than being cut off.
                              child: Semantics(
                                header: true,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // The title again in the faction's own
                                      // script, as decoration only.
                                      if (theme.scriptFont case final script?)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            right: m.gap * 2,
                                          ),
                                          child: ExcludeSemantics(
                                            child: Text(
                                              title.toUpperCase(),
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontFamily: script,
                                                color:
                                                    (theme.shape.outlined
                                                            ? theme.structureAt(
                                                                0,
                                                              )
                                                            : theme
                                                                  .textOnStructureAt(
                                                                    0,
                                                                  ))
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                fontSize: m.topBar * 0.5,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Text(
                                        title.toUpperCase(),
                                        // The screen's name, read as written.
                                        semanticsLabel: title,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: theme.shape.outlined
                                              ? theme.structureAt(0)
                                              : theme.textOnStructureAt(0),
                                          fontSize: m.topBar * 0.62,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: m.gap),
                          _Cap(
                            height: m.topBar,
                            colour: theme.structureAt(2),
                            right: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: m.gap),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DefaultTextStyle.merge(
                          style: chrome,
                          child: sidebarNav == null
                              ? _Sidebar(
                                  metrics: m,
                                  labels: sidebarLabels,
                                  emblem: emblem,
                                )
                              : _NavSidebar(metrics: m, items: sidebarNav!),
                        ),
                        SizedBox(width: m.innerRadius * 0.6),
                        Expanded(
                          child: theme.shape == DexShape.grid
                              ? CustomPaint(
                                  painter: GridPainter(
                                    colour: theme.data.first.withValues(
                                      alpha: 0.07,
                                    ),
                                    cell: 16,
                                  ),
                                  child: child,
                                )
                              : child,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: m.gap),
                  DefaultTextStyle.merge(
                    style: chrome,
                    child: SizedBox(
                      height: m.bottomBar + m.innerRadius,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _Elbow(
                            metrics: m,
                            barHeight: m.bottomBar,
                            width: elbowWidth,
                            colour: theme.structureAt(1),
                            top: false,
                            // The bottom elbow always returns to the home screen.
                            label: canPop && theme.shape != DexShape.radial
                                ? 'HOME'
                                : null,
                            labelColour: theme.textOnStructureAt(1),
                            onTap: canPop
                                ? () =>
                                      Navigator.of(context)
                                          .popUntil((route) => route.isFirst)
                                : null,
                            semanticLabel: 'Home',
                          ),
                          SizedBox(width: m.gap),
                          Expanded(
                            child: _Bar(
                              height: m.bottomBar,
                              colour: theme.structureAt(1),
                              child: footer == null
                                  ? null
                                  : Text(
                                      footer!.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.shape.outlined
                                            ? theme.structureAt(1)
                                            : theme.textOnStructureAt(1),
                                        fontSize: m.bottomBar * 0.5,
                                        letterSpacing: 1.5,
                                        height: 1,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(width: m.gap),
                          _Cap(
                            height: m.bottomBar,
                            colour: theme.accent,
                            right: true,
                          ),
                        ],
                      ),
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

/// An L-shaped elbow joining the sidebar to a bar.
class _Elbow extends StatelessWidget {
  const _Elbow({
    required this.metrics,
    required this.barHeight,
    required this.width,
    required this.colour,
    required this.top,
    this.label,
    this.labelColour,
    this.onTap,
    this.semanticLabel,
  });

  final LcarsMetrics metrics;
  final double barHeight;
  final double width;
  final Color colour;
  final bool top;
  final String? label;
  final Color? labelColour;
  final VoidCallback? onTap;

  /// What a screen reader announces for the button; defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = DexTheme.of(context).shape;
    final elbow = CustomPaint(
      size: Size(width, barHeight + metrics.innerRadius),
      painter: _ElbowPainter(
        colour: colour,
        shape: shape,
        sidebar: metrics.s,
        bar: barHeight,
        innerRadius: metrics.innerRadius,
        top: top,
      ),
      child: SizedBox(
        width: width,
        height: barHeight + metrics.innerRadius,
        child: label == null
            ? null
            // The label sits at the bottom right of the elbow's sidebar arm,
            // like the labels on the sidebar blocks below it.
            : Align(
                alignment: top ? Alignment.bottomLeft : Alignment.topLeft,
                child: SizedBox(
                  width: metrics.s,
                  child: Align(
                    alignment: top ? Alignment.bottomRight : Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      // On the Borg grid the label needs a solid backing to be read.
                      color: shape == DexShape.grid ? Colors.black : null,
                      padding: shape == DexShape.grid
                          ? const EdgeInsets.symmetric(horizontal: 3)
                          : null,
                      child: Text(
                        label!,
                        style: TextStyle(
                          color: shape == DexShape.grid || shape.outlined
                              ? colour
                              : labelColour,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
    if (onTap == null) return elbow;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          Sounds.play(Beep.back);
          onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: elbow),
      ),
    );
  }
}

class _ElbowPainter extends CustomPainter {
  _ElbowPainter({
    required this.colour,
    required this.shape,
    required this.sidebar,
    required this.bar,
    required this.innerRadius,
    required this.top,
  });

  final Color colour;
  final DexShape shape;
  final double sidebar;
  final double bar;
  final double innerRadius;
  final bool top;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (!top) {
      // Drawn as the top-left corner; the bottom one is the same shape flipped.
      canvas
        ..translate(0, h)
        ..scale(1, -1);
    }
    final paint = Paint()..color = colour;
    if (shape == DexShape.film) {
      _paintFilm(canvas, w, h);
      return;
    }
    if (shape == DexShape.slanted) {
      _paintSlanted(canvas, w, h);
      return;
    }
    if (shape == DexShape.radial) {
      _paintRadial(canvas, w, h, paint);
      return;
    }
    final (outer, inner) = switch (shape) {
      DexShape.lcars => (sidebar.clamp(0.0, h), innerRadius),
      DexShape.angular => (sidebar * 0.8, innerRadius),
      DexShape.rounded => (sidebar * 0.4, innerRadius * 0.5),
      DexShape.elliptical => (sidebar, innerRadius),
      // A heavy round arch, as the Dominion keyhole frames have.
      DexShape.arched => (math.min(sidebar * 1.6, h), innerRadius * 1.5),
      DexShape.stone => (sidebar * 0.3, innerRadius * 0.45),
      DexShape.bezel => (sidebar * 0.55, innerRadius * 0.7),
      DexShape.console ||
      DexShape.panel ||
      DexShape.radial ||
      DexShape.grid ||
      DexShape.slanted ||
      DexShape.film => (4.0, 2.0),
    };
    final cut = shape == DexShape.angular || shape == DexShape.stone;
    // Cardassian corners are quarter-ellipses, wider than they are tall.
    final elliptical = shape == DexShape.elliptical;
    final outerX = elliptical ? outer * 1.6 : outer;
    final outerY = elliptical ? h * 0.85 : outer;
    final innerX = elliptical ? inner * 1.8 : inner;
    final outerRadius = Radius.elliptical(outerX, outerY);
    final innerShape = Radius.elliptical(innerX, inner);
    final path = Path()..moveTo(0, h);
    if (cut) {
      path
        ..lineTo(0, outer)
        ..lineTo(outer, 0);
    } else {
      path
        ..lineTo(0, outerY)
        ..arcToPoint(Offset(outerX, 0), radius: outerRadius);
    }
    path
      ..lineTo(w, 0)
      ..lineTo(w, bar)
      ..lineTo(sidebar + innerX, bar);
    if (cut) {
      path.lineTo(sidebar, bar + inner);
    } else {
      path.arcToPoint(
        Offset(sidebar, bar + inner),
        radius: innerShape,
        clockwise: false,
      );
    }
    path
      ..lineTo(sidebar, h)
      ..close();
    canvas.drawPath(path, paint);
    _finish(canvas, path, Size(w, h));
    if (elliptical) {
      // An oval inset in the corner, as on Cardassian panels.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sidebar * 0.62, bar * 0.62),
          width: sidebar * 0.6,
          height: bar * 0.42,
        ),
        Paint()..color = const Color(0xFF000000),
      );
    } else if (shape == DexShape.grid) {
      canvas
        ..save()
        ..clipPath(path);
      GridPainter(
        colour: const Color(0xFF000000),
        cell: sidebar / 6,
        width: 1.5,
      ).paint(canvas, Size(w, h));
      canvas.restore();
    }
  }

  /// The surface each solid family adds over its fill: ENT's raised shading,
  /// the Gorn's stone rim, the Ferengi's bezel.
  void _finish(Canvas canvas, Path path, Size size) {
    switch (shape) {
      case DexShape.panel:
        canvas.drawPath(path, raisedShading(size));
      case DexShape.stone:
        canvas.drawPath(path, raisedShading(size, strength: 0.6));
        canvas.drawPath(path, rimPaint(colour, 3));
      case DexShape.bezel:
        canvas.drawPath(path, rimPaint(colour, 4));
      default:
        break;
    }
  }

  /// Romulan corner: a sharply slanted L drawn as a thin outline over a faint
  /// fill, like the warbird consoles' frames.
  void _paintSlanted(Canvas canvas, double w, double h) {
    final cut = sidebar * 0.9, inner = innerRadius * 1.2;
    final path = Path()
      ..moveTo(1, h)
      ..lineTo(1, cut)
      ..lineTo(cut, 1)
      ..lineTo(w - 1, 1)
      ..lineTo(w - 1, bar - 1)
      ..lineTo(sidebar + inner, bar - 1)
      ..lineTo(sidebar - 1, bar + inner)
      ..lineTo(sidebar - 1, h)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = colour.withValues(alpha: 0.12))
      ..drawPath(
        path,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  /// Film-era corner: a chamfered L drawn as a thin outline over a faint fill,
  /// like the slanted panel frames on the Enterprise-A consoles.
  void _paintFilm(Canvas canvas, double w, double h) {
    final cut = sidebar * 0.45, inner = innerRadius * 0.6;
    final path = Path()
      ..moveTo(1, h)
      ..lineTo(1, cut)
      ..lineTo(cut, 1)
      ..lineTo(w - 1, 1)
      ..lineTo(w - 1, bar - 1)
      ..lineTo(sidebar + inner, bar - 1)
      ..lineTo(sidebar - 1, bar + inner)
      ..lineTo(sidebar - 1, h)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = colour.withValues(alpha: 0.14))
      ..drawPath(
        path,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  /// Ringed hub corner (Borg): a hub over the sidebar, with the bar running out of it.
  void _paintRadial(Canvas canvas, double w, double h, Paint paint) {
    final r = sidebar / 2;
    final centre = Offset(r, r);
    canvas.drawRRect(
      RRect.fromLTRBR(r, 0, w, bar, Radius.circular(bar / 2)),
      paint,
    );
    canvas.drawCircle(centre, r, paint);
    canvas.drawCircle(
      centre,
      r * 0.7,
      Paint()..color = const Color(0xFF000000),
    );
    canvas.drawCircle(centre, r * 0.45, paint);
    canvas.drawCircle(
      centre,
      r * 0.18,
      Paint()..color = const Color(0xFF000000),
    );
  }

  @override
  bool shouldRepaint(_ElbowPainter old) =>
      old.colour != colour ||
      old.shape != shape ||
      old.sidebar != sidebar ||
      old.bar != bar ||
      old.top != top;
}

/// A straight bar; its child sits at the right-hand end.
class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.colour, this.child});

  final double height;
  final Color colour;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final bar = Container(
      height: height,
      decoration: surfaceDecoration(theme.shape, colour, 0),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
    if (theme.shape == DexShape.slanted) {
      // Short slanted accent bars along the top edge, as on the warbird consoles.
      return Stack(
        children: [
          bar,
          Positioned(
            left: 10,
            top: height * 0.3,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 18,
                    height: height * 0.4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: ShapeDecoration(
                      color: theme.data.first,
                      shape: const ParallelogramBorder(slant: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    if (theme.shape != DexShape.grid) return bar;
    return CustomPaint(
      foregroundPainter: GridPainter(
        colour: Colors.black.withValues(alpha: 0.35),
        cell: height / 3,
      ),
      child: bar,
    );
  }
}

/// The end of a bar: a pill cap (LCARS), a wedge (angular) or a square block (console).
class _Cap extends StatelessWidget {
  const _Cap({required this.height, required this.colour, required this.right});

  final double height;
  final Color colour;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final shape = DexTheme.of(context).shape;
    if (shape == DexShape.film) {
      // A small oval lamp rather than a block.
      return SizedBox(
        width: height * 1.2,
        height: height,
        child: Center(
          child: Container(
            width: height * 1.1,
            height: height * 0.55,
            decoration: ShapeDecoration(
              color: colour,
              shape: const StadiumBorder(),
            ),
          ),
        ),
      );
    }
    if (shape == DexShape.slanted) {
      return Container(
        width: height * 1.2,
        height: height,
        decoration: ShapeDecoration(
          color: colour.withValues(alpha: 0.2),
          shape: ParallelogramBorder(
            slant: 0.5,
            side: BorderSide(color: colour, width: 2),
          ),
        ),
      );
    }
    return Container(
      width: height * 1.2,
      height: height,
      decoration: ShapeDecoration(
        color: colour,
        shape: endShape(shape, height, right: right),
      ),
    );
  }
}

/// A light-to-dark wash over a fill, for ENT's raised buttons and the Gorn's
/// stone: brighter at the top, darker at the bottom.
Paint raisedShading(Size size, {double strength = 1}) =>
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.28 * strength),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3 * strength),
        ],
      ).createShader(Offset.zero & size);

/// A darker rim round a shape: the Gorn's stone frame, the Ferengi bezel.
Paint rimPaint(Color colour, double width) => Paint()
  ..color = Color.lerp(colour, Colors.black, 0.5)!
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// The raised look as a fill: lighter at the top, darker at the bottom.
Gradient raisedGradient(Color colour, {double strength = 1}) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color.lerp(colour, Colors.white, 0.28 * strength)!,
    colour,
    Color.lerp(colour, Colors.black, 0.3 * strength)!,
  ],
);

/// How a bar ([s] 0) or sidebar block ([s] the sidebar width) is filled in
/// each family: outlined over a faint fill (film, Romulan), shaded (ENT,
/// Gorn), rimmed (Gorn, Ferengi) or solid.
BoxDecoration surfaceDecoration(DexShape shape, Color colour, double s) {
  final radius = s == 0 ? null : _blockRadius(shape, s);
  final rim = Border.all(
    color: Color.lerp(colour, Colors.black, 0.5)!,
    width: 3,
  );
  return switch (shape) {
    DexShape.film || DexShape.slanted => BoxDecoration(
      color: colour.withValues(alpha: shape == DexShape.film ? 0.14 : 0.12),
      border: Border.all(color: colour, width: 2),
      borderRadius: radius,
    ),
    DexShape.panel => BoxDecoration(
      gradient: raisedGradient(colour),
      borderRadius: radius ?? BorderRadius.circular(2),
    ),
    DexShape.stone => BoxDecoration(
      gradient: raisedGradient(colour, strength: 0.6),
      border: rim,
      borderRadius: radius,
    ),
    DexShape.bezel => BoxDecoration(
      color: colour,
      border: rim,
      borderRadius: radius ?? BorderRadius.circular(8),
    ),
    _ => BoxDecoration(color: colour, borderRadius: radius),
  };
}

/// A TOS console's indicator lamp.
class _Lamp extends StatelessWidget {
  const _Lamp({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: colour,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black, width: 1.5),
      boxShadow: [
        BoxShadow(color: colour.withValues(alpha: 0.7), blurRadius: 4),
      ],
    ),
  );
}

/// [child] with a TOS lamp lit in its top-left corner, on the console family
/// only; the lamps take the data colours in turn.
Widget _withLamp(DexTheme theme, int i, Widget child) {
  if (theme.shape != DexShape.console) return child;
  return Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      Positioned(
        top: 5,
        left: 5,
        child: _Lamp(colour: theme.data[i % theme.data.length]),
      ),
    ],
  );
}

/// The shape for the end of a bar or button: rounded, wedged, slanted or square.
ShapeBorder endShape(
  DexShape shape,
  double height, {
  bool left = false,
  bool right = false,
}) {
  final r = Radius.circular(height / 2);
  final radius = BorderRadius.only(
    topLeft: left ? r : Radius.zero,
    bottomLeft: left ? r : Radius.zero,
    topRight: right ? r : Radius.zero,
    bottomRight: right ? r : Radius.zero,
  );
  return switch (shape) {
    DexShape.lcars => RoundedRectangleBorder(borderRadius: radius),
    DexShape.angular => BeveledRectangleBorder(borderRadius: radius),
    DexShape.console => const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(3)),
    ),
    DexShape.radial => const StadiumBorder(),
    DexShape.rounded => RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(height / 4)),
    ),
    DexShape.elliptical => TrapezoidBorder(left: left, right: right),
    DexShape.grid => const RoundedRectangleBorder(),
    DexShape.film => const StadiumBorder(),
    DexShape.slanted => ParallelogramBorder(slant: left && right ? 0.35 : 0.5),
    DexShape.arched => const StadiumBorder(),
    DexShape.panel => const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(2)),
    ),
    DexShape.stone => BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(height * 0.3)),
    ),
    DexShape.bezel => RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(height / 3)),
    ),
  };
}

/// The sidebar: coloured blocks split by thin black gaps, the last one taking
/// the remaining height. Labels sit at the bottom right of each block.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.metrics, required this.labels, this.emblem});

  final LcarsMetrics metrics;
  final List<String> labels;
  final Widget? emblem;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final count = labels.isEmpty ? 1 : labels.length.clamp(1, 4);
    Widget block(int i) {
      final colour = i == count - 1
          ? theme.data.first
          : theme.structureAt(i + 2);
      final text = i == count - 1
          ? Colors.black
          : theme.textOnStructureAt(i + 2);
      final film = theme.shape.outlined;
      return Container(
        width: metrics.s,
        decoration: surfaceDecoration(theme.shape, colour, metrics.s),
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.all(4),
        child: i == 0 && emblem != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Center(child: emblem)),
                  if (labels.isNotEmpty)
                    Text(
                      labels[0].toUpperCase(),
                      style: TextStyle(
                        color: film ? theme.highlight : text,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              )
            : i < labels.length
            ? Text(
                labels[i].toUpperCase(),
                style: TextStyle(
                  color: film ? theme.highlight : text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      );
    }

    Widget cells(Widget b) => theme.shape == DexShape.grid
        ? CustomPaint(
            foregroundPainter: GridPainter(
              colour: Colors.black.withValues(alpha: 0.35),
              cell: metrics.s / 4,
            ),
            child: b,
          )
        : b;

    return SizedBox(
      width: metrics.s,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count - 1; i++) ...[
            SizedBox(
              height: metrics.s * 1.4,
              child: _withLamp(theme, i, cells(block(i))),
            ),
            SizedBox(height: metrics.blockGap),
          ],
          Expanded(child: cells(block(count - 1))),
        ],
      ),
    );
  }
}

/// The sidebar as navigation: one block per [LcarsNavItem], scrolling when
/// there are more than fit, and a closing block taking whatever height is left.
class _NavSidebar extends StatelessWidget {
  const _NavSidebar({required this.metrics, required this.items});

  final LcarsMetrics metrics;
  final List<LcarsNavItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final film = theme.shape.outlined;
    final radius = _blockRadius(theme.shape, metrics.s);

    Widget block(Color colour, {Widget? child}) => Container(
      width: metrics.s,
      decoration: surfaceDecoration(theme.shape, colour, metrics.s),
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(4),
      child: child,
    );

    Widget item(int i, double height) {
      final it = items[i];
      // The current screen takes the highlight; the rest cycle the frame colours.
      final colour = it.selected ? theme.highlight : theme.structureAt(i + 2);
      final text = it.selected
          ? (ThemeData.estimateBrightnessForColor(colour) == Brightness.dark
                ? Colors.white
                : Colors.black)
          : theme.textOnStructureAt(i + 2);
      final label = Text(
        // One word to a line, so the shrink-to-fit below acts per word.
        it.icon == null
            ? it.label.toUpperCase().replaceAll(' ', '\n')
            : it.label.toUpperCase(),
        textAlign: TextAlign.right,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: film ? theme.highlight : text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      );
      // With an icon (a faction's badge) the block shows the badge alone, larger;
      // the name stays for screen readers and as a tooltip.
      final b = _withLamp(
        theme,
        i,
        block(
          colour,
          child: it.icon == null
              // Words never break: a long label shrinks to fit a phone's narrow sidebar.
              ? LayoutBuilder(
                  builder: (context, c) => Align(
                    alignment: Alignment.bottomRight,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomRight,
                        child: label,
                      ),
                    ),
                  ),
                )
              : Tooltip(
                  message: it.label,
                  child: Center(child: it.icon!(metrics.s * 0.62)),
                ),
        ),
      );
      return Semantics(
        button: !it.selected,
        selected: it.selected,
        label: it.label,
        // The label stands in for the block's contents, so the tap is given
        // here too, or a screen reader couldn't press it.
        onTap: it.selected ? null : it.onTap,
        excludeSemantics: true,
        child: SizedBox(
          height: height,
          // Material on both, so the selected block's label has the same text
          // style as the others rather than the frame's narrow heading font.
          child: it.selected
              ? Material(type: MaterialType.transparency, child: b)
              : Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () {
                      Sounds.play(it.beep);
                      it.onTap();
                    },
                    customBorder: radius == null
                        ? null
                        : RoundedRectangleBorder(borderRadius: radius),
                    child: b,
                  ),
                ),
        ),
      );
    }

    // Blocks shrink (to 0.7 of their height at most) so every item fits before
    // the sidebar has to scroll; text stays readable at that size.
    return SizedBox(
      width: metrics.s,
      child: LayoutBuilder(
        builder: (context, c) {
          final room =
              (c.maxHeight - metrics.s * 0.5) / items.length - metrics.blockGap;
          final height = room.clamp(metrics.s * 0.7, metrics.s * 1.1);
          return CustomScrollView(
            slivers: [
              SliverList.list(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    item(i, height),
                    SizedBox(height: metrics.blockGap),
                  ],
                ],
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: metrics.s * 0.5),
                  child: block(theme.data.first),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Swaps the current screen for a sibling without animating or growing the
/// back stack, so the back button still goes up a level.
void replaceWithSibling(BuildContext context, WidgetBuilder builder) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

/// Sidebar blocks: square in LCARS and its square-cornered cousins, capsules in
/// the film era's radial style, softly rounded for the rounded style, and
/// oval-ended for the Cardassians.
BorderRadius? _blockRadius(DexShape shape, double s) => switch (shape) {
  DexShape.radial => BorderRadius.circular(s / 2),
  DexShape.rounded => BorderRadius.circular(s / 5),
  DexShape.elliptical => BorderRadius.all(Radius.elliptical(s / 2, s / 4)),
  // Dominion blocks are arch-topped.
  DexShape.arched => BorderRadius.vertical(top: Radius.circular(s / 2)),
  DexShape.panel => BorderRadius.circular(2),
  DexShape.stone => BorderRadius.circular(5),
  DexShape.bezel => BorderRadius.circular(s / 4),
  _ => null,
};

/// A button in the theme's shape: a pill in LCARS, chamfered for Klingon,
/// square-cornered on a console. Colour [index] picks a structure colour.
class LcarsButton extends StatelessWidget {
  const LcarsButton({
    super.key,
    required this.label,
    this.caption,
    this.index = 0,
    this.colour,
    this.leading,
    this.beep = Beep.tap,
    required this.onPressed,
  });

  final String label;
  final String? caption;

  /// Played on a press.
  final Beep beep;

  /// Shown before the label, such as a faction's emblem.
  final Widget? leading;

  /// Which structure colour to use, cycling; ignored when [colour] is given.
  final int index;
  final Color? colour;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    // Read as written, not in the capitals it's shown in, with the caption after.
    button: true,
    label: caption == null ? label : '$label, $caption',
    onTap: onPressed,
    excludeSemantics: true,
    child: _button(context),
  );

  Widget _button(BuildContext context) {
    final theme = DexTheme.of(context);
    final fill = colour ?? theme.structureAt(index);
    final onFill = colour != null
        ? (ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
              ? Colors.white
              : Colors.black)
        : theme.textOnStructureAt(index);
    final text = Theme.of(context).textTheme;
    if (theme.shape == DexShape.film) {
      return _FilmButton(
        label: label,
        caption: caption,
        colour: fill,
        lamp: theme.accent,
        beep: beep,
        onPressed: onPressed,
      );
    }
    // Gorn buttons are glossy green whatever their place in the frame.
    final stone = theme.shape == DexShape.stone && colour == null;
    final base = stone ? theme.data.first : fill;
    final ink = stone
        ? (ThemeData.estimateBrightnessForColor(base) == Brightness.dark
              ? Colors.white
              : Colors.black)
        : (theme.shape == DexShape.slanted ? fill : onFill);
    final rim = BorderSide(
      color: Color.lerp(base, Colors.black, 0.5)!,
      width: 3,
    );
    final shape = switch (theme.shape) {
      DexShape.slanted => ParallelogramBorder(
        slant: 0.35,
        side: BorderSide(color: fill, width: 2),
      ),
      DexShape.stone => StadiumBorder(side: rim),
      DexShape.bezel => RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: rim,
      ),
      _ => endShape(theme.shape, 48, left: true, right: true),
    };
    final shaded =
        theme.shape == DexShape.panel || theme.shape == DexShape.stone;
    return Material(
      color: shaded
          ? Colors.transparent
          : theme.shape == DexShape.slanted
          ? fill.withValues(alpha: 0.14)
          : base,
      shape: shape,
      clipBehavior: shaded ? Clip.antiAlias : Clip.none,
      child: Ink(
        decoration: shaded
            ? ShapeDecoration(
                gradient: raisedGradient(
                  base,
                  strength: theme.shape == DexShape.stone ? 1.4 : 1,
                ),
                shape: shape,
              )
            : null,
        child: InkWell(
          customBorder: shape,
          onTap: () {
            Sounds.play(beep);
            onPressed();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                // TOS buttons carry an indicator lamp.
                if (theme.shape == DexShape.console) ...[
                  _Lamp(colour: theme.data[index % theme.data.length]),
                  const SizedBox(width: 12),
                ],
                if (leading != null) ...[leading!, const SizedBox(width: 16)],
                Expanded(
                  child: _LabelAndCaption(
                    label: Text(
                      label.toUpperCase(),
                      style: DexTheme.of(context)
                          .heading(text.titleMedium)
                          ?.copyWith(
                            color: ink,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    caption: caption == null
                        ? null
                        : Text(
                            caption!,
                            style: DexTheme.of(context)
                                .heading(text.labelLarge)
                                ?.copyWith(color: ink),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Film-era button: a slanted, outlined panel with a small oval lamp, as on the
/// Enterprise-A consoles.
class _FilmButton extends StatelessWidget {
  const _FilmButton({
    required this.label,
    required this.caption,
    required this.colour,
    required this.lamp,
    required this.beep,
    required this.onPressed,
  });

  final String label;
  final String? caption;
  final Color colour;
  final Color lamp;
  final Beep beep;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = BeveledRectangleBorder(
      side: BorderSide(color: colour, width: 2),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14),
        bottomRight: Radius.circular(14),
      ),
    );
    return Material(
      color: colour.withValues(alpha: 0.12),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () {
          Sounds.play(beep);
          onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 12,
                decoration: ShapeDecoration(
                  color: lamp,
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _LabelAndCaption(
                  label: Text(
                    label.toUpperCase(),
                    style: DexTheme.of(context)
                        .heading(text.titleMedium)
                        ?.copyWith(
                          color: colour,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  caption: caption == null
                      ? null
                      : Text(
                          caption!,
                          style: DexTheme.of(context)
                              .heading(text.labelLarge)
                              ?.copyWith(color: colour),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A button's label with its caption at the far end, or on a line of its own
/// beneath when the two don't fit side by side (a narrow screen, large text).
class _LabelAndCaption extends StatelessWidget {
  const _LabelAndCaption({required this.label, this.caption});

  final Widget label;
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    if (caption == null) return label;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 2,
      children: [label, caption!],
    );
  }
}

/// A section heading: a short block in the accent colour and the title in capitals.
class LcarsSectionTitle extends StatelessWidget {
  const LcarsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    return Semantics(
      header: true,
      label: title,
      excludeSemantics: true,
      child: _title(theme, context),
    );
  }

  Widget _title(DexTheme theme, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: theme.shape.outlined ? 12 : 18,
            decoration: ShapeDecoration(
              color: theme.accent,
              shape: endShape(theme.shape, 18, left: true),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title.toUpperCase(),
              style: theme
                  .heading(Theme.of(context).textTheme.titleSmall)
                  ?.copyWith(
                    color: theme.accent,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

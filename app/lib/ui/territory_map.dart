import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dex_theme.dart';
import 'lcars_display.dart';
import 'sound.dart';

/// A power on the galaxy chart, after the Starfleet cartography displays ("The
/// Game", "Milky Way Galaxy"): a translucent cylinder standing on the tilted
/// galactic disc, where the shows put the power. The chart is the Dex's own
/// drawing; published maps are copyright.
class Power {
  const Power({
    required this.colour,
    required this.bearing,
    required this.distance,
    required this.size,
    this.scale = const {},
    this.beyond,
  });

  final Color colour;

  /// Around the core in degrees: 90 is the Alpha Quadrant at the front, 0 the
  /// Beta Quadrant to the right, 270 the Delta Quadrant at the back and 180
  /// the Gamma Quadrant to the left.
  final double bearing;

  /// Out from the core: 0 at the core, 1 at the rim.
  final double distance;

  /// The cylinder's radius, as a fraction of the disc's.
  final double size;

  /// How big the power is in each era (1 when not given).
  final Map<String, double> scale;

  /// For a power outside the galaxy as charted ("Fluidic space"): drawn off
  /// the disc, at [bearing] and [distance] all the same.
  final String? beyond;
}

/// The powers. Colours are each power's own, not an era theme's.
const powers = <String, Power>{
  // United Earth in ENT, growing into the Federation of TNG.
  'federation': Power(
    colour: Color(0xFF3F7DFF),
    bearing: 72,
    distance: 0.78,
    size: 0.156,
    scale: {'ENT': 0.5, 'TOS': 0.75, 'TMP': 0.88},
  ),
  // The Klingons peak before Praxis (2293) and are no bigger by TNG.
  'klingon': Power(
    colour: Color(0xFFE0453A),
    bearing: 38,
    distance: 0.8,
    size: 0.130,
    scale: {'ENT': 0.75, 'TOS': 0.85, 'TMP': 1},
  ),
  // The Romulans lose ground in the Earth-Romulan War (2156-2160), and take
  // the TOS era to win it back.
  'romulan': Power(
    colour: Color(0xFF3FBF6A),
    bearing: 44,
    distance: 0.55,
    size: 0.117,
    scale: {'ENT': 0.9, 'TOS': 0.75, 'TMP': 0.9},
  ),
  'tholian': Power(
    colour: Color(0xFFFFB347),
    bearing: 58,
    distance: 0.66,
    size: 0.058,
  ),
  'gorn': Power(
    colour: Color(0xFF9ACD32),
    bearing: 82,
    distance: 0.97,
    size: 0.078,
  ),
  'cardassian': Power(
    colour: Color(0xFFD2A04B),
    bearing: 112,
    distance: 0.62,
    size: 0.104,
  ),
  'ferengi': Power(
    colour: Color(0xFFFFD34F),
    bearing: 98,
    distance: 0.42,
    size: 0.065,
  ),
  'breen': Power(
    colour: Color(0xFF5FD3C7),
    bearing: 126,
    distance: 0.9,
    size: 0.072,
  ),
  'dominion': Power(
    colour: Color(0xFF8E7BFF),
    bearing: 196,
    distance: 0.62,
    size: 0.143,
  ),
  'borg': Power(
    colour: Color(0xFF7CFC00),
    bearing: 262,
    distance: 0.6,
    size: 0.143,
  ),
  'voth': Power(
    colour: Color(0xFFFFD700),
    bearing: 300,
    distance: 0.55,
    size: 0.091,
  ),
  'undine': Power(
    colour: Color(0xFFFF66CC),
    bearing: 320,
    distance: 1.3,
    size: 0.078,
    beyond: 'Fluidic space',
  ),
  'terran': Power(
    colour: Color(0xFFFFC14D),
    bearing: 210,
    distance: 1.3,
    size: 0.104,
    beyond: 'Mirror universe',
  ),
};

/// Where things go on a chart of [size]: the disc, and each power's spot.
class _Chart {
  _Chart(this.size)
    : centre = Offset(size.width * 0.5, size.height * 0.56),
      rx = size.width * 0.4,
      ry = math.min(size.height * 0.34, size.width * 0.2);

  final Size size;
  final Offset centre;
  final double rx, ry;

  /// The point on the disc at [bearing] degrees and [distance] from the core.
  Offset at(double bearing, double distance) {
    final a = bearing * math.pi / 180;
    return centre +
        Offset(math.cos(a) * rx * distance, math.sin(a) * ry * distance);
  }

  /// A power's cylinder: its base ellipse and height.
  ({Offset base, double rx, double ry, double h}) cylinder(
    Power p,
    String era,
  ) {
    final s = p.size * (p.scale[era] ?? 1);
    return (
      base: at(p.bearing, p.distance),
      rx: rx * s,
      ry: ry * s,
      h: ry * s * 1.6,
    );
  }
}

/// The galaxy chart: the disc with its quadrants, the powers present in [era]
/// standing on it, and their names down each side. Tapping a power or its
/// name selects it.
class TerritoryMap extends StatelessWidget {
  const TerritoryMap({
    super.key,
    required this.era,
    required this.factions,
    required this.selected,
    required this.onSelect,
  });

  final String era;

  /// Faction id and name, for the factions present in [era].
  final List<({String id, String name})> factions;
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _labelH = 26.0;

  @override
  Widget build(BuildContext context) {
    final font = DexTheme.of(context).headingFont;
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final chart = _Chart(size);
        final labelW = math.min(170.0, size.width * 0.3);
        Offset baseOf(String id) => chart.cylinder(powers[id]!, era).base;

        // Names in a column down each side, in the order of their powers from
        // back to front, with a line to each.
        final placed = <({String id, String name, Offset label, Offset to})>[];
        for (final left in [true, false]) {
          final side = [
            for (final f in factions)
              if ((baseOf(f.id).dx < chart.centre.dx) == left) f,
          ]..sort((a, b) => baseOf(a.id).dy.compareTo(baseOf(b.id).dy));
          // Each name level with its power, nudged down only to clear the
          // one above, and the column shifted up if it runs off the bottom.
          final ys = <double>[];
          for (final f in side) {
            final cyl = chart.cylinder(powers[f.id]!, era);
            final want = cyl.base.dy - cyl.h - _labelH / 2;
            ys.add(math.max(want, ys.isEmpty ? 4.0 : ys.last + _labelH + 6));
          }
          final over = ys.isEmpty ? 0.0 : ys.last - (size.height - _labelH - 4);
          for (final (i, f) in side.indexed) {
            final cyl = chart.cylinder(powers[f.id]!, era);
            placed.add((
              id: f.id,
              name: f.name,
              label: Offset(
                left ? 4 : size.width - labelW - 4,
                math.max(4, ys[i] - math.max(0, over)),
              ),
              to: cyl.base - Offset(0, cyl.h),
            ));
          }
        }

        String? hit(Offset p) {
          String? best;
          var bestD = double.infinity;
          for (final f in factions) {
            final cyl = chart.cylinder(powers[f.id]!, era);
            final mid = cyl.base - Offset(0, cyl.h / 2);
            final d = (p - mid).distance;
            if (d < math.max(cyl.rx, 22) + 8 && d < bestD) {
              best = f.id;
              bestD = d;
            }
          }
          return best;
        }

        return GestureDetector(
          onTapUp: (d) {
            final id = hit(d.localPosition);
            if (id != null) {
              Sounds.play(Beep.select);
              onSelect(id);
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ChartPainter(
                    chart: chart,
                    era: era,
                    ids: [for (final f in factions) f.id],
                    selected: selected,
                    leaders: [
                      for (final p in placed)
                        (
                          // From under the pill, which hides the start, so the
                          // line meets the pill whatever its width.
                          from:
                              p.label +
                              Offset(
                                p.label.dx < size.width / 2 ? 8 : labelW - 8,
                                _labelH / 2,
                              ),
                          to: p.to,
                          colour: powers[p.id]!.colour,
                        ),
                    ],
                    font: font,
                  ),
                ),
              ),
              for (final p in placed)
                Positioned(
                  left: p.label.dx,
                  top: p.label.dy,
                  width: labelW,
                  height: _labelH,
                  child: _Marker(
                    name: p.name,
                    colour: powers[p.id]!.colour,
                    selected: p.id == selected,
                    right: p.label.dx > size.width / 2,
                    onTap: () => onSelect(p.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A power's name at the side of the chart: a tap target and a button for
/// screen readers.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.name,
    required this.colour,
    required this.selected,
    required this.right,
    required this.onTap,
  });

  final String name;
  final Color colour;
  final bool selected;

  /// On the right-hand side: aligned to the right.
  final bool right;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final font = DexTheme.of(context).headingFont;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          Sounds.play(Beep.select);
          onTap();
        },
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: ShapeDecoration(
              color: selected ? colour : Colors.black,
              shape: StadiumBorder(
                side: BorderSide(color: colour.withValues(alpha: 0.9)),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 15,
                  height: 1.1,
                  letterSpacing: 0.8,
                  color: selected ? Colors.black : colour,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.chart,
    required this.era,
    required this.ids,
    required this.selected,
    required this.leaders,
    required this.font,
  });

  final _Chart chart;
  final String era;
  final List<String> ids;
  final String? selected;
  final List<({Offset from, Offset to, Color colour})> leaders;
  final String? font;

  static const _gold = Color(0xFFE8A33B);

  void _text(Canvas canvas, String s, Offset at, Color c, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: s.toUpperCase(),
        style: TextStyle(
          fontFamily: font,
          fontSize: size,
          color: c,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  /// The galaxy's stars on the disc: four arms winding out from a central bar,
  /// each a scatter of blue-white stars with a haze along it, and the bar a
  /// denser, warmer crowd. Laid out with a fixed seed, so it never shifts.
  void _milkyWay(Canvas canvas, math.Random rng) {
    Offset onDisc(double angle, double r) =>
        chart.centre +
        Offset(math.cos(angle) * chart.rx * r, math.sin(angle) * chart.ry * r);
    double spread() => (rng.nextDouble() + rng.nextDouble() - 1) * 0.5;

    // The haze: soft, wide blobs along each arm.
    final haze = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    const arms = 4;
    for (var arm = 0; arm < arms; arm++) {
      for (var k = 0; k < 26; k++) {
        final t = k / 26;
        final r = 0.2 + 0.78 * t;
        final angle = arm * math.pi / 2 + 0.35 + t * math.pi * 1.35;
        haze.color = const Color(0xFF8FB0FF)
            .withValues(alpha: (arm.isEven ? 0.11 : 0.07) * (1 - t * 0.5));
        canvas.drawCircle(
          onDisc(angle, r),
          chart.ry * (0.12 + 0.08 * (1 - t)),
          haze,
        );
      }
    }

    // The stars along the arms, brightest in the two major arms.
    final buckets = <double, List<Offset>>{0.25: [], 0.45: [], 0.7: []};
    for (var n = 0; n < 2600; n++) {
      final arm = rng.nextInt(arms);
      final t = math.pow(rng.nextDouble(), 0.8).toDouble();
      final r = (0.2 + 0.78 * t + spread() * 0.08).clamp(0.05, 1.0);
      final angle =
          arm * math.pi / 2 + 0.35 + t * math.pi * 1.35 + spread() * 0.35;
      final b = rng.nextDouble();
      final key = arm.isEven ? (b < 0.5 ? 0.45 : 0.7) : (b < 0.6 ? 0.25 : 0.45);
      buckets[key]!.add(onDisc(angle, r));
    }
    final dot = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3;
    for (final e in buckets.entries) {
      dot.color = const Color(0xFFD6E2FF).withValues(alpha: e.key);
      canvas.drawPoints(ui.PointMode.points, e.value, dot);
    }

    // The bar across the core, warmer and denser.
    final bar = <Offset>[];
    for (var n = 0; n < 700; n++) {
      final along = spread() * 2 * 0.3;
      final across = spread() * 0.07;
      const tilt = 0.5;
      final x = along * math.cos(tilt) - across * math.sin(tilt);
      final y = along * math.sin(tilt) + across * math.cos(tilt);
      bar.add(chart.centre + Offset(x * chart.rx, y * chart.ry));
    }
    dot
      ..color = const Color(0xFFFFE6B8).withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    canvas.drawPoints(ui.PointMode.points, bar, dot);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF02030A));
    canvas.save();
    canvas.clipRect(rect);

    // Stars, the same every time.
    final rng = math.Random(47);
    final star = Paint();
    for (var i = 0; i < 420; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      star.color = Colors.white.withValues(
        alpha: 0.15 + rng.nextDouble() * 0.5,
      );
      canvas.drawCircle(p, rng.nextDouble() * 1.1 + 0.2, star);
    }

    final c = chart.centre;
    final disc = Rect.fromCenter(
      center: c,
      width: chart.rx * 2,
      height: chart.ry * 2,
    );
    // The disc: a faint glow, then the Milky Way itself, a barred spiral.
    canvas.drawOval(
      disc,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF6E8BD6).withValues(alpha: 0.35),
            const Color(0xFF253A75).withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0, 0.6, 1],
        ).createShader(disc),
    );
    _milkyWay(canvas, rng);
    // Rings and the quadrant lines, in gold.
    final ring = Paint()
      ..color = _gold.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke;
    for (final f in [1.0, 0.72, 0.38]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: chart.rx * 2 * f,
          height: chart.ry * 2 * f,
        ),
        ring..strokeWidth = f == 1 ? 3 : 1.2,
      );
    }
    ring.strokeWidth = 1.5;
    for (final b in [45.0, 135.0, 225.0, 315.0]) {
      canvas.drawLine(chart.at(b, 0.12), chart.at(b, 1), ring);
    }
    // The core.
    canvas.drawCircle(
      c,
      chart.ry * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9),
            const Color(0xFFFFE7B0).withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: chart.ry * 0.6)),
    );

    // Quadrant names, at the rim.
    const blue = Color(0xFF6FB6FF);
    final q = math.max(13.0, size.width * 0.018);
    _text(
      canvas,
      'Alpha Quadrant',
      chart.at(90, 1) + Offset(0, q * 1.3),
      blue,
      q,
    );
    _text(
      canvas,
      'Beta Quadrant',
      chart.at(0, 1) + Offset(-q * 3, q * 1.6),
      blue,
      q,
    );
    _text(
      canvas,
      'Gamma Quadrant',
      chart.at(180, 1) + Offset(q * 3.2, -q * 1.6),
      blue,
      q,
    );
    _text(
      canvas,
      'Delta Quadrant',
      chart.at(270, 1) - Offset(0, q * 1.3),
      blue,
      q,
    );

    // The powers, back to front so nearer ones stand in front.
    Offset baseOf(String id) => chart.cylinder(powers[id]!, era).base;
    final order = [...ids]
      ..sort((a, b) => baseOf(a).dy.compareTo(baseOf(b).dy));
    for (final id in order) {
      final p = powers[id]!;
      final cyl = chart.cylinder(p, era);
      final on = id == selected;
      final base = Rect.fromCenter(
        center: cyl.base,
        width: cyl.rx * 2,
        height: cyl.ry * 2,
      );
      final top = base.shift(Offset(0, -cyl.h));
      final body = Path()
        ..addArc(base, 0, math.pi)
        ..lineTo(top.left, top.center.dy)
        ..arcTo(top, math.pi, -math.pi, false)
        ..close();
      final fill = p.colour.withValues(alpha: on ? 0.75 : 0.5);
      canvas.drawPath(
        body,
        Paint()
          ..shader =
              LinearGradient(
                colors: [
                  fill,
                  p.colour.withValues(alpha: on ? 0.95 : 0.7),
                  fill,
                ],
              ).createShader(
                Rect.fromLTRB(base.left, top.top, base.right, base.bottom),
              ),
      );
      canvas.drawOval(
        top,
        Paint()..color = p.colour.withValues(alpha: on ? 1 : 0.8),
      );
      canvas.drawOval(
        top,
        Paint()
          ..color = Colors.white.withValues(alpha: on ? 0.8 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 2 : 1,
      );
      if (on) {
        canvas.drawOval(
          base.inflate(6),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      if (p.beyond != null) {
        _text(
          canvas,
          p.beyond!,
          cyl.base + Offset(0, cyl.ry + 10),
          p.colour,
          math.max(11.0, size.width * 0.014),
        );
      }
    }
    // Leader lines from the names to their powers, over the cylinders so a
    // line that passes one still reaches its own.
    for (final l in leaders) {
      final line = Paint()
        ..color = l.colour.withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final knee = Offset(l.to.dx, l.from.dy);
      canvas.drawPath(
        Path()
          ..moveTo(l.from.dx, l.from.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(l.to.dx, l.to.dy),
        line,
      );
      canvas.drawCircle(l.to, 2.5, Paint()..color = l.colour);
    }

    canvas.restore();
    canvas.drawRect(
      rect,
      Paint()
        ..color = LcarsColours.periwinkle.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.era != era ||
      old.selected != selected ||
      old.ids.length != ids.length ||
      old.chart.size != chart.size;
}

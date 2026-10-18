import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/ship_repository.dart';
import '../theme/dex_theme.dart';
import '../ui/lcars_display.dart';
import '../ui/sound.dart';
import 'faction_list_screen.dart';

/// The Starship Database: pick an era (#480). Modelled on the lower half of a
/// TNG subsystem status display: the eras are pills on either side of a
/// two-coloured trunk, joined to it by lines, each with its year. The
/// screen is plain TNG LCARS; each era's own look starts on the next screen.
class ShipLibraryScreen extends StatelessWidget {
  const ShipLibraryScreen({super.key, required this.repository});

  final ShipRepository repository;

  @override
  Widget build(BuildContext context) {
    final ships = repository.visibleShips().toList();
    return DexThemeScope(
      child: LcarsDisplay(
        title: 'Starship Database',
        topColours: const [
          LcarsColours.gold,
          LcarsColours.tan,
          LcarsColours.gold,
          LcarsColours.ochre,
        ],
        bandColours: const [
          LcarsColours.tan,
          LcarsColours.gold,
          LcarsColours.blue,
        ],
        sidebar: [
          LcarsItem(
            label: '${ships.length}',
            semanticLabel: '${ships.length} ships',
            colour: LcarsColours.tan,
          ),
          LcarsItem(
            label: 'r${repository.data.modRevision}',
            colour: LcarsColours.tan,
            flex: 2,
          ),
          const LcarsItem(label: 'Era select', colour: LcarsColours.pink),
        ],
        child: _EraTrunk(
          eras: [
            for (final era in repository.eras)
              (
                id: era.id,
                title: era.title,
                year: era.year,
                count: ships.where((s) => s.era == era.id).length,
              ),
          ],
          onOpen: (id) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  FactionListScreen(repository: repository, eraId: id),
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Era = ({String id, String title, int year, int count});

/// The eras in order, zigzagging either side of the trunk: the left ones join
/// its blue bar, the right ones its gold bar.
class _EraTrunk extends StatelessWidget {
  const _EraTrunk({required this.eras, required this.onOpen});

  final List<_Era> eras;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final narrow = w < 420;
        final barW = narrow ? 12.0 : (w * 0.022).clamp(14, 30).toDouble();
        final trunkX = w * 0.5 - barW - 4;
        final pillH = narrow ? 64.0 : 92.0;
        final pillW = math.min(360.0, trunkX - (narrow ? 14 : 40));
        final top = barW + 28;
        final rowH = math.max(
          pillH + 14,
          (c.maxHeight - top - 20) / math.max(1, eras.length),
        );
        final layout = [
          for (var i = 0; i < eras.length; i++)
            (
              era: eras[i],
              left: i.isEven,
              y: top + i * rowH + (rowH - pillH) / 2,
            ),
        ];
        final height = math.max(c.maxHeight, top + eras.length * rowH);
        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrunkPainter(
                      trunkX: trunkX,
                      barW: barW,
                      rows: [
                        for (final r in layout)
                          (y: r.y + pillH / 2, left: r.left),
                      ],
                      pillW: pillW,
                      rowH: rowH,
                      top: top,
                    ),
                  ),
                ),
                for (final r in layout)
                  Positioned(
                    left: r.left ? trunkX - (narrow ? 10 : 30) - pillW : null,
                    right: r.left
                        ? null
                        : w -
                              (trunkX +
                                  barW * 2 +
                                  8 +
                                  (narrow ? 10 : 30) +
                                  pillW),
                    top: r.y,
                    width: pillW,
                    height: pillH,
                    child: _EraPill(
                      era: r.era,
                      compact: narrow,
                      colour: r.left ? LcarsColours.blue : LcarsColours.ochre,
                      onTap: () => onOpen(r.era.id),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EraPill extends StatelessWidget {
  const _EraPill({
    required this.era,
    required this.colour,
    required this.onTap,
    this.compact = false,
  });

  final _Era era;

  /// On a phone: the era's name a word to a line.
  final bool compact;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final font = DexTheme.of(context).headingFont;
    TextStyle style(double size) => TextStyle(
      fontFamily: font,
      color: Colors.black,
      fontSize: size,
      height: 1,
      letterSpacing: 1,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return Semantics(
          button: true,
          label: '${era.title}, ${era.year}, ${era.count} ships',
          onTap: onTap,
          excludeSemantics: true,
          child: Material(
            color: colour,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                Sounds.play(Beep.select);
                onTap();
              },
              // The year ends where the right-hand curve begins, half the
              // pill's height in from its end.
              child: Padding(
                padding: EdgeInsets.fromLTRB(h * 0.4, 0, h / 2, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomLeft,
                          // The era's name, a word to a line on a phone.
                          child: Text(
                            compact
                                ? era.title.toUpperCase().replaceAll(' ', '\n')
                                : era.title.toUpperCase(),
                            style: style(h * (compact ? 0.2 : 0.26)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Both halves shrink to fit a narrow pill. The year sits on
                    // the pill's centreline, against the right-hand curve.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text('${era.year}', style: style(h * 0.62)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The trunk: a blue bar and a gold bar side by side, in segments, curving off
/// along the top (blue to the left, gold to the right), with a line from each
/// pill to its side's bar.
class _TrunkPainter extends CustomPainter {
  _TrunkPainter({
    required this.trunkX,
    required this.barW,
    required this.rows,
    required this.pillW,
    required this.rowH,
    required this.top,
  });

  final double trunkX, barW, pillW, rowH, top;
  final List<({double y, bool left})> rows;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 8.0;
    final blueX = trunkX, goldX = trunkX + barW + gap;
    final r = barW * 2;
    final bottom = size.height - 4;

    // The curves at the top, blue turning left and gold turning right,
    // drawn as thick strokes, which keeps the corners round and even.
    void sweep(double x, bool toLeft, Color colour) {
      final p = Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = barW;
      final cx = x + barW / 2;
      final y = barW / 2;
      final path = Path()..moveTo(cx, top);
      if (toLeft) {
        path
          ..lineTo(cx, y + r)
          ..arcToPoint(
            Offset(cx - r, y),
            radius: Radius.circular(r),
            clockwise: false,
          )
          ..lineTo(barW * 0.5, y);
      } else {
        path
          ..lineTo(cx, y + r)
          ..arcToPoint(Offset(cx + r, y), radius: Radius.circular(r))
          ..lineTo(size.width - barW * 0.5, y);
      }
      canvas.drawPath(path, p);
    }

    sweep(blueX, true, LcarsColours.blue);
    sweep(goldX, false, LcarsColours.ochre);

    // The bars, in segments between the rows.
    final breaks = [for (var i = 1; i < rows.length; i++) top + i * rowH];
    var y = top + 6;
    for (final b in [...breaks, bottom]) {
      for (final (x, c) in [
        (blueX, LcarsColours.blue),
        (goldX, LcarsColours.ochre),
      ]) {
        canvas.drawRect(
          Rect.fromLTRB(x, y, x + barW, b - 4),
          Paint()..color = c,
        );
      }
      y = b + 4;
    }

    // A line from each pill to its bar.
    // Long enough to reach under the pill.
    final lineReach = pillW * 0.5 + 40;
    final line = Paint()..strokeWidth = 4;
    for (final row in rows) {
      if (row.left) {
        line.color = LcarsColours.blue;
        canvas.drawLine(
          Offset(blueX - lineReach, row.y),
          Offset(blueX, row.y),
          line,
        );
      } else {
        line.color = LcarsColours.ochre;
        canvas.drawLine(
          Offset(goldX + barW, row.y),
          Offset(goldX + barW + lineReach, row.y),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrunkPainter old) =>
      old.trunkX != trunkX ||
      old.rowH != rowH ||
      old.rows.length != rows.length;
}

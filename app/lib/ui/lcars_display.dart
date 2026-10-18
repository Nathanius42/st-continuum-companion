import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dex_theme.dart';
import 'sound.dart';

/// The TNG display palette the section screens are drawn in, after the
/// reference displays (personnel files, subsystem status, command interface).
abstract final class LcarsColours {
  static const orange = Color(0xFFFF9900);
  static const gold = Color(0xFFFFCC66);
  static const peach = Color(0xFFFFCC99);
  static const lilac = Color(0xFFCC99CC);
  static const lavender = Color(0xFFCCA6E8);
  static const periwinkle = Color(0xFF9999FF);
  static const coral = Color(0xFFCC6666);
  static const tan = Color(0xFFD49A5E);
  static const blue = Color(0xFF2B9BD8);
  static const ochre = Color(0xFFDBA000);
  static const pink = Color(0xFFFFA6D0);
}

/// An elbow in the top-left corner of [r]: an arm [arm] wide down the left and
/// a bar [bar] high along the top, flipped into another corner with [flipX] and
/// [flipY].
void paintLcarsElbow(
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
  final o = math.min(outer, math.min(w, h));
  final path = Path()
    ..moveTo(0, h)
    ..lineTo(0, o)
    ..arcToPoint(Offset(o, 0), radius: Radius.circular(o))
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

/// A block in a sidebar or column: plain, or a button.
class LcarsItem {
  const LcarsItem({
    required this.label,
    required this.colour,
    this.onTap,
    this.semanticLabel,
    this.selected = false,
    this.toggled,
    this.beep = Beep.tap,
    this.flex = 1,
  });

  final String label;
  final Color colour;
  final VoidCallback? onTap;

  /// What a screen reader says, when the label is a code or abbreviation.
  final String? semanticLabel;

  /// The current one: drawn in the highlight and not tappable.
  final bool selected;
  final bool? toggled;
  final Beep beep;
  final int flex;
}

/// A coloured block with its label in small capitals at the bottom right, as
/// LCARS labels its blocks. Tappable when [item] has an onTap.
class LcarsBlock extends StatelessWidget {
  const LcarsBlock(this.item, {super.key, this.borderRadius});

  final LcarsItem item;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final colour = item.selected ? LcarsColours.orange : item.colour;
    final face = Container(
      decoration: BoxDecoration(color: colour, borderRadius: borderRadius),
      padding: const EdgeInsets.fromLTRB(6, 3, 7, 5),
      alignment: Alignment.bottomRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomRight,
        child: Text(
          item.label.toUpperCase().replaceAll(' ', '\n'),
          textAlign: TextAlign.right,
          maxLines: 3,
          style: TextStyle(
            fontFamily: theme.headingFont,
            color: Colors.black,
            fontSize: 15,
            height: 1.05,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
    if (item.onTap == null && !item.selected) {
      return ExcludeSemantics(child: face);
    }
    final label = item.semanticLabel ?? item.label;
    return Semantics(
      button: !item.selected,
      selected: item.selected,
      toggled: item.toggled,
      label: label,
      onTap: item.selected ? null : item.onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: item.selected || item.onTap == null
              ? null
              : () {
                  Sounds.play(item.beep);
                  item.onTap!();
                },
          child: face,
        ),
      ),
    );
  }
}

/// A rounded LCARS pill button with its label at the right.
class LcarsPill extends StatelessWidget {
  const LcarsPill({
    super.key,
    required this.label,
    required this.colour,
    this.onTap,
    this.semanticLabel,
    this.height = 44,
    this.beep = Beep.tap,
  });

  final String label;
  final Color colour;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double height;
  final Beep beep;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final enabled = onTap != null;
    final face = Container(
      height: height,
      padding: EdgeInsets.fromLTRB(height * 0.5, 4, height * 0.4, 6),
      decoration: ShapeDecoration(
        color: enabled ? colour : colour.withValues(alpha: 0.45),
        shape: const StadiumBorder(),
      ),
      alignment: Alignment.bottomRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomRight,
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          style: TextStyle(
            fontFamily: theme.headingFont,
            color: Colors.black,
            fontSize: height * 0.42,
            height: 1,
            letterSpacing: 1,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled
              ? () {
                  Sounds.play(beep);
                  onTap!();
                }
              : null,
          child: face,
        ),
      ),
    );
  }
}

/// The framed panel at the right of a display: a column of blocks coming down
/// from the band, with [child] beside it. Without a child it's just the column,
/// which is what a phone keeps.
class LcarsPanel {
  const LcarsPanel({required this.column, this.child, this.width = 360});

  final List<LcarsItem> column;
  final Widget? child;

  /// Width of the whole panel, column and child, in a wide window.
  final double width;
}

/// A TNG display screen: an optional top section framed by an elbow, a band
/// across the middle, then a sidebar down the left beside the content, with an
/// optional framed [panel] on the right. BACK is the top-left block and HOME
/// the last sidebar block whenever there's a screen to return to.
class LcarsDisplay extends StatelessWidget {
  const LcarsDisplay({
    super.key,
    required this.title,
    required this.child,
    this.top,
    this.topHeight = 150,
    this.sidebar = const [],
    this.panel,
    this.topColours = const [
      LcarsColours.lilac,
      LcarsColours.periwinkle,
      LcarsColours.gold,
      LcarsColours.orange,
    ],
    this.bandColours = const [
      LcarsColours.coral,
      LcarsColours.lilac,
      LcarsColours.periwinkle,
    ],
  });

  /// Below this width the display is laid out for a phone.
  static const narrowWidth = 600.0;

  final String title;
  final Widget child;

  /// The top section's content (a search box, buttons); null for a display
  /// that's only the lower half, with the title in a slim row above the band.
  final Widget? top;
  final double topHeight;
  final List<LcarsItem> sidebar;
  final LcarsPanel? panel;

  /// The top block, the top elbow and the top bar's pieces.
  final List<Color> topColours;

  /// The band's elbow, its bar and the panel's elbow.
  final List<Color> bandColours;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => _DisplayLayout(
            display: this,
            size: Size(c.maxWidth, c.maxHeight),
            canPop: canPop,
          ),
        ),
      ),
    );
  }
}

class _Geometry {
  _Geometry(Size size, LcarsDisplay d)
    : width = size.width,
      height = size.height {
    narrow = width < LcarsDisplay.narrowWidth;
    left = narrow ? 58 : (width * 0.1).clamp(90, 150).toDouble();
    bar = narrow ? 12 : (width * 0.016).clamp(14, 20).toDouble();
    outer = left * 0.55;
    inner = bar * 1.4;
    elbowW = left + inner + left * 0.5;
    titleH = narrow ? 32 : 50;
    if (d.top != null) {
      topH = math.max(d.topHeight, titleH + 60);
      backH = topH * 0.42;
      bandY = topH + gap * 1.5;
    } else {
      topH = 0;
      backH = titleH;
      bandY = titleH + gap * 2;
    }
    elbowH = math.max(outer, bar + inner) + gap;
    bodyY = bandY + bar + gap * 4;
    sideY = bandY + elbowH + gap;
    final p = d.panel;
    column = narrow ? 62 : (width * 0.055).clamp(66, 90).toDouble();
    if (p == null) {
      panelX = null;
    } else if (narrow || p.child == null) {
      panelX = width - pad - column;
    } else {
      panelX = width - pad - math.min(p.width, width * 0.38);
    }
  }

  static const pad = 6.0;
  static const gap = 5.0;
  final double width, height;
  late final bool narrow;
  late final double left, bar, outer, inner, elbowW, titleH;
  late final double topH, backH, bandY, elbowH, bodyY, sideY, column;
  late final double? panelX;

  double get contentLeft => pad + left + gap * 4;
  double get contentRight => panelX == null ? width - pad : panelX! - gap * 4;
}

class _DisplayLayout extends StatelessWidget {
  const _DisplayLayout({
    required this.display,
    required this.size,
    required this.canPop,
  });

  final LcarsDisplay display;
  final Size size;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    final g = _Geometry(size, display);
    final d = display;
    final theme = DexTheme.of(context);
    final nav = Navigator.of(context);
    const pad = _Geometry.pad, gap = _Geometry.gap;

    final back = LcarsItem(
      label: canPop ? 'Back' : 'LCARS',
      colour: d.topColours[0],
      onTap: canPop ? () => nav.maybePop() : null,
      beep: Beep.back,
    );
    final side = [
      ...d.sidebar,
      if (canPop)
        LcarsItem(
          label: 'Home',
          colour: LcarsColours.peach,
          onTap: () => nav.popUntil((route) => route.isFirst),
          beep: Beep.back,
        ),
    ];

    // Sidebar blocks share the height under the band's elbow.
    final sideTop = g.sideY;
    final sideH = size.height - pad - sideTop;
    final flexTotal = side.fold<int>(0, (n, s) => n + s.flex);
    final blocks = <Widget>[];
    var y = sideTop;
    for (final s in side) {
      final h =
          (sideH - gap * (side.length - 1)) * s.flex / math.max(1, flexTotal);
      blocks.add(
        Positioned(
          left: pad,
          top: y,
          width: g.left,
          height: h,
          child: LcarsBlock(s),
        ),
      );
      y += h + gap;
    }

    final panel = d.panel;
    final columnBlocks = <Widget>[];
    if (panel != null && g.panelX != null) {
      final colTop = g.bandY + g.elbowH + gap;
      final colH = size.height - pad - colTop;
      final n = panel.column.length;
      final flexTotal = panel.column.fold<int>(0, (t, s) => t + s.flex);
      var cy = colTop;
      for (final s in panel.column) {
        final h = (colH - gap * (n - 1)) * s.flex / math.max(1, flexTotal);
        columnBlocks.add(
          Positioned(
            left: g.panelX,
            top: cy,
            width: g.column,
            height: h,
            child: LcarsBlock(s),
          ),
        );
        cy += h + gap;
      }
    }

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _DisplayPainter(g, d))),
        // BACK, top left.
        Positioned(
          left: pad,
          top: 0,
          width: g.left,
          height: g.backH,
          child: LcarsBlock(
            back,
            borderRadius: d.top == null
                ? BorderRadius.horizontal(left: Radius.circular(g.backH / 2))
                : null,
          ),
        ),
        // The title, top right.
        Positioned(
          right: pad,
          top: 0,
          left: g.contentLeft,
          height: g.titleH,
          child: Semantics(
            header: true,
            label: d.title,
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: Text(
                d.title.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: theme.headingFont,
                  color: LcarsColours.orange,
                  fontSize: g.titleH * 0.95,
                  height: 1,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (d.top != null)
          Positioned(
            left: g.contentLeft,
            right: pad,
            top: g.titleH + gap,
            height: g.topH - g.bar - g.titleH - gap * 3,
            child: d.top!,
          ),
        ...blocks,
        ...columnBlocks,
        Positioned(
          left: g.contentLeft,
          right: size.width - g.contentRight,
          top: g.bodyY,
          bottom: pad,
          child: d.child,
        ),
        if (panel?.child != null && !g.narrow)
          Positioned(
            left: g.panelX! + g.column + gap * 4,
            right: pad,
            top: g.bodyY,
            bottom: pad,
            child: panel!.child!,
          ),
      ],
    );
  }
}

class _DisplayPainter extends CustomPainter {
  _DisplayPainter(this.g, this.d);

  final _Geometry g;
  final LcarsDisplay d;

  void _bar(Canvas canvas, double x0, double x1, double y, double h, Color c) {
    if (x1 > x0) {
      canvas.drawRect(Rect.fromLTRB(x0, y, x1, y + h), Paint()..color = c);
    }
  }

  /// Bars from [x0] to [x1], in pieces of the given [fractions] and colours.
  void _pieces(
    Canvas canvas,
    double x0,
    double x1,
    double y,
    List<double> fractions,
    List<Color> colours,
  ) {
    const gap = _Geometry.gap;
    final room = x1 - x0 - gap * (fractions.length - 1);
    var x = x0;
    for (var i = 0; i < fractions.length; i++) {
      final w = room * fractions[i];
      _bar(canvas, x, x + w, y, g.bar, colours[i % colours.length]);
      x += w + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = _Geometry.pad, gap = _Geometry.gap;
    final right = size.width - pad;
    final tc = d.topColours, bc = d.bandColours;

    // Top section: the elbow under BACK, sweeping into the top bar.
    if (d.top != null) {
      final ey = g.backH + gap;
      paintLcarsElbow(
        canvas,
        Rect.fromLTWH(pad, ey, g.elbowW, g.topH - ey),
        arm: g.left,
        bar: g.bar,
        outer: g.outer,
        inner: g.inner,
        colour: tc[1 % tc.length],
        flipY: true,
      );
      _pieces(
        canvas,
        pad + g.elbowW + gap,
        right,
        g.topH - g.bar,
        const [0.5, 0.06, 0.28, 0.16],
        [tc[0], tc[2 % tc.length], tc[3 % tc.length], tc[1 % tc.length]],
      );
    }

    // The band: an elbow down into the sidebar, a bar across, and the panel's
    // own elbow down into its column.
    paintLcarsElbow(
      canvas,
      Rect.fromLTWH(pad, g.bandY, g.elbowW, g.elbowH),
      arm: g.left,
      bar: g.bar,
      outer: g.outer,
      inner: g.inner,
      colour: bc[0],
    );
    final bandEnd = g.panelX == null ? right : g.panelX! - gap;
    _pieces(
      canvas,
      pad + g.elbowW + gap,
      bandEnd,
      g.bandY,
      const [0.82, 0.18],
      [bc[0], LcarsColours.orange],
    );
    if (g.panelX != null) {
      final pw = g.column + g.inner + g.column * 0.4;
      paintLcarsElbow(
        canvas,
        Rect.fromLTWH(
          g.panelX!,
          g.bandY,
          math.min(pw, right - g.panelX!),
          g.elbowH,
        ),
        arm: g.column,
        bar: g.bar,
        outer: g.column * 0.5,
        inner: g.inner,
        colour: bc[2 % bc.length],
      );
      if (g.panelX! + pw + gap < right) {
        _pieces(
          canvas,
          g.panelX! + pw + gap,
          right,
          g.bandY,
          const [0.7, 0.3],
          [bc[1 % bc.length], LcarsColours.orange],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DisplayPainter old) =>
      old.g.width != g.width || old.g.height != g.height || old.d != d;
}

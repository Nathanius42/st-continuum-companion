import 'package:flutter/material.dart';

/// A trapezoid: the Cardassian interface's favourite shape after the ellipse
/// ("ellipses, triangles and trapezoids rather than squares and rectangles",
/// Herman Zimmerman). Each end can slant in by [slant] times the height.
class TrapezoidBorder extends OutlinedBorder {
  const TrapezoidBorder({
    super.side,
    this.left = true,
    this.right = true,
    this.slant = 0.45,
  });

  final bool left;
  final bool right;
  final double slant;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final inset = rect.height * slant;
    return Path()
      ..moveTo(rect.left + (left ? inset : 0), rect.top)
      ..lineTo(rect.right - (right ? inset : 0), rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(getOuterPath(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => TrapezoidBorder(
    side: side.scale(t),
    left: left,
    right: right,
    slant: slant,
  );

  @override
  TrapezoidBorder copyWith({BorderSide? side}) => TrapezoidBorder(
    side: side ?? this.side,
    left: left,
    right: right,
    slant: slant,
  );
}

/// A parallelogram leaning right: the Romulan interface's slanted bars and
/// buttons. The top edge is shifted right by [slant] times the height.
class ParallelogramBorder extends OutlinedBorder {
  const ParallelogramBorder({super.side, this.slant = 0.45});

  final double slant;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final shift = rect.height * slant;
    return Path()
      ..moveTo(rect.left + shift, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right - shift, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(getOuterPath(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) =>
      ParallelogramBorder(side: side.scale(t), slant: slant);

  @override
  ParallelogramBorder copyWith({BorderSide? side}) =>
      ParallelogramBorder(side: side ?? this.side, slant: slant);
}

/// Straight lines on a square grid: cuts Borg frame blocks into cells (drawn in
/// black over them) or lays a faint grid behind content.
class GridPainter extends CustomPainter {
  const GridPainter({required this.colour, this.cell = 8, this.width = 1});

  final Color colour;
  final double cell;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = width;
    for (var x = cell; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = cell; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.colour != colour || old.cell != cell || old.width != width;
}

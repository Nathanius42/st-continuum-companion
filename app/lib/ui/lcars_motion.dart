import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/dex_theme.dart';

/// Small LCARS animations for the front page and its sections (#941): lamps
/// that blink, readouts that tick over, a scan line and the stardate. Each
/// holds still when the system asks for reduced motion.
bool motionAllowed(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// Rebuilds [builder] every [period] while motion is allowed, passing the tick
/// count; one fixed frame otherwise.
class LcarsTicker extends StatefulWidget {
  const LcarsTicker({super.key, required this.period, required this.builder});

  final Duration period;
  final Widget Function(BuildContext context, int tick) builder;

  @override
  State<LcarsTicker> createState() => _LcarsTickerState();
}

class _LcarsTickerState extends State<LcarsTicker> {
  Timer? _timer;
  int _tick = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed = motionAllowed(context);
    if (allowed && _timer == null) {
      _timer = Timer.periodic(widget.period, (_) => setState(() => _tick++));
    } else if (!allowed) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _tick);
}

/// A lamp: a small rounded block that blinks on and off.
class LcarsLamp extends StatelessWidget {
  const LcarsLamp({
    super.key,
    required this.colour,
    this.width = 28,
    this.height = 12,
    this.period = const Duration(milliseconds: 900),
    this.phase = 0,
  });

  final Color colour;
  final double width;
  final double height;
  final Duration period;

  /// Offsets this lamp's blinking from its neighbours'.
  final int phase;

  @override
  Widget build(BuildContext context) => LcarsTicker(
    period: period,
    builder: (context, tick) {
      // Held still, a lamp stays lit.
      final on = !motionAllowed(context) || (tick + phase) % 3 != 0;
      return AnimatedOpacity(
        opacity: on ? 1 : 0.25,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      );
    },
  );
}

/// A column of figures, as the panels beside an LCARS display show, some of
/// which change on each tick.
class LcarsReadout extends StatelessWidget {
  const LcarsReadout({
    super.key,
    required this.seed,
    this.lines = 6,
    this.digits = 5,
    this.colour,
    this.period = const Duration(milliseconds: 700),
  });

  final int seed;
  final int lines;
  final int digits;
  final Color? colour;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final style = theme
        .heading(Theme.of(context).textTheme.labelMedium)
        ?.copyWith(
          color: colour ?? theme.data.first,
          height: 1.15,
          letterSpacing: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return ExcludeSemantics(
      child: LcarsTicker(
        period: period,
        builder: (context, tick) {
          final rows = <String>[];
          for (var i = 0; i < lines; i++) {
            // Each line keeps its value for a few ticks, so the column flickers
            // rather than churning.
            final r = Random(seed * 131 + i * 17 + (tick + i) ~/ (2 + i % 3));
            final n = r.nextInt(pow(10, digits).toInt());
            rows.add(n.toString().padLeft(digits, '0'));
          }
          return Text(rows.join('\n'), style: style);
        },
      ),
    );
  }
}

/// A thin bar with a brighter band sweeping along it.
class LcarsScanBar extends StatefulWidget {
  const LcarsScanBar({
    super.key,
    required this.colour,
    this.height = 6,
    this.period = const Duration(milliseconds: 2600),
  });

  final Color colour;
  final double height;
  final Duration period;

  @override
  State<LcarsScanBar> createState() => _LcarsScanBarState();
}

class _LcarsScanBarState extends State<LcarsScanBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionAllowed(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _ScanPainter(widget.colour, _c.value),
      ),
    ),
  );
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.colour, this.t);

  final Color colour;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(r, Paint()..color = colour.withValues(alpha: 0.35));
    final band = size.width * 0.18;
    final x = -band + (size.width + band) * t;
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Rect.fromLTWH(x, 0, band, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            colour.withValues(alpha: 0),
            colour,
            colour.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x, 0, band, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t || old.colour != colour;
}

/// Today's stardate in the Kelvin films' format, which keeps real dates positive:
/// the year, then the day of the year ("Stardate 2258.42" is the 42nd day of
/// 2258), so 18 October 2026 is 2026.291.
String stardateFor(DateTime now) {
  final day = now.difference(DateTime(now.year)).inDays + 1;
  return '${now.year}.$day';
}

/// The stardate, ticking over.
class Stardate extends StatelessWidget {
  const Stardate({super.key, this.style, this.clock});

  final TextStyle? style;

  /// Supplied by tests.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) => LcarsTicker(
    // The stardate changes once a day; a minute is plenty.
    period: const Duration(minutes: 1),
    builder: (context, _) => Text(
      stardateFor((clock ?? DateTime.now)()),
      style: style,
      semanticsLabel: 'Stardate ${stardateFor((clock ?? DateTime.now)())}',
    ),
  );
}

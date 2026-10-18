import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/models.dart';

/// A pre-rendered turntable (#491): the ship turns slowly on its own, and dragging
/// sideways spins it by hand, one full turn per width of the view. The arrow keys
/// step it a frame at a time when it has focus, shown by a ring.
///
/// The mouse wheel turns it too (#546), a frame a notch: always with Shift held
/// or a sideways trackpad scroll, and with the plain wheel once it has focus
/// (clicked or tabbed to). Otherwise the wheel scrolls the page, so scrolling
/// doesn't catch on the turntable at the top of it.
///
/// The frames come from one sprite sheet ([Turntable]), cut out as they're painted,
/// so the whole turn is a single decoded image. Auto-rotation stops while the user
/// drags, resumes a few seconds after, and is off when the platform asks for
/// reduced motion.
class TurntableView extends StatefulWidget {
  const TurntableView({
    super.key,
    required this.turntable,
    required this.name,
    this.width = 320,
    this.fallback,
  });

  final Turntable turntable;
  final String name;
  final double width;

  /// Shown while the sheet loads, or if it can't be loaded.
  final Widget? fallback;

  @override
  State<TurntableView> createState() => _TurntableViewState();
}

class _TurntableViewState extends State<TurntableView>
    with SingleTickerProviderStateMixin {
  /// Seconds for one unattended turn.
  static const _secondsPerTurn = 14.0;
  static const _resumeAfter = Duration(seconds: 3);

  ui.Image? _sheet;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _failed = false;

  /// Position in the turn, in frames; fractional while auto-rotating.
  double _position = 0;
  late final Ticker _ticker;
  Duration? _lastTick;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);
  bool _dragging = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
    _updateTicker();
  }

  /// The ticker runs only while there's a sheet to turn and motion is allowed, so a
  /// still turntable costs no frames.
  void _updateTicker() {
    final run = _sheet != null && !MediaQuery.of(context).disableAnimations;
    if (run && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(TurntableView old) {
    super.didUpdateWidget(old);
    if (old.turntable.sheet != widget.turntable.sheet) {
      _position = 0;
      _load();
    }
  }

  void _load() {
    final stream = AssetImage(widget.turntable.sheet)
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _unlisten();
    _listener = ImageStreamListener((info, _) {
      setState(() {
        _sheet = info.image;
        _failed = false;
      });
      _updateTicker();
    }, onError: (_, _) => setState(() => _failed = true));
    _stream = stream..addListener(_listener!);
  }

  void _unlisten() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _unlisten();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null || _sheet == null || _dragging) return;
    if (DateTime.now().difference(_lastTouch) < _resumeAfter) return;
    final seconds = (elapsed - last).inMicroseconds / 1e6;
    final frames = widget.turntable.frames;
    setState(() {
      _position = (_position + seconds * frames / _secondsPerTurn) % frames;
    });
  }

  void _turnBy(double frames) {
    final n = widget.turntable.frames;
    setState(() {
      _position = (_position + frames) % n;
      if (_position < 0) _position += n;
    });
    _lastTouch = DateTime.now();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dx = event.scrollDelta.dx, dy = event.scrollDelta.dy;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    // Shift+wheel arrives as a vertical delta on Windows and a sideways one elsewhere.
    final delta = dx.abs() > dy.abs() ? dx : (shift || _focused ? dy : 0.0);
    if (delta == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _turnBy(delta.sign);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Alt+Left is the app's back key, not a turn.
    if (HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _turnBy(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _turnBy(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.turntable;
    // Fit the frame in a box as wide as asked and at most 60% as tall, so a tall
    // station doesn't fill the page when ships are wide and flat.
    final scale = math.min(
      widget.width / t.frameWidth,
      widget.width * 0.6 / t.frameHeight,
    );
    final width = t.frameWidth * scale;
    final height = t.frameHeight * scale;
    final sheet = _sheet;
    if (sheet == null) {
      return _failed || widget.fallback == null
          ? SizedBox(width: width, height: height)
          : widget.fallback!;
    }
    return Semantics(
      label: '${widget.name}, turning. Drag sideways to turn it by hand.',
      image: true,
      child: Focus(
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: MouseRegion(
            cursor: _dragging
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab,
            child: GestureDetector(
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragUpdate: (d) =>
                  _turnBy(-d.delta.dx * t.frames / width),
              onHorizontalDragEnd: (_) => setState(() {
                _dragging = false;
                _lastTouch = DateTime.now();
              }),
              onTap: () => Focus.of(context).requestFocus(),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: _focused
                      ? Border.all(color: const Color(0xAAFFFFFF), width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  size: Size(width, height),
                  painter: _FramePainter(
                    sheet,
                    t,
                    _position.floor() % t.frames,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.sheet, this.turntable, this.frame);

  final ui.Image sheet;
  final Turntable turntable;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final t = turntable;
    final col = frame % t.columns;
    final row = frame ~/ t.columns;
    final src = Rect.fromLTWH(
      col * t.frameWidth.toDouble(),
      row * t.frameHeight.toDouble(),
      t.frameWidth.toDouble(),
      t.frameHeight.toDouble(),
    );
    canvas.drawImageRect(
      sheet,
      src,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.sheet != sheet;
}

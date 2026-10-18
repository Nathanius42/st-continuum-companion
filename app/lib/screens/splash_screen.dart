import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/dex_theme.dart';
import '../ui/faction_logo.dart';
import '../ui/lcars_motion.dart';
import '../ui/sound.dart';
import 'front_page.dart';

/// The splash (#941), from the STC website's front door: "LCARS online",
/// the library database, access restricted, and a button to request access,
/// which beeps, grants it, and opens the front page. The website's own colours.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.data});

  final FrontPageData data;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _lavender = Color(0xFFA59AFF);
  static const _gold = Color(0xFFFCCE00);
  static const _red = Color(0xFFE02020);
  static const _granted = Color(0xFF66CC66);

  bool _granted0 = false;
  Timer? _timer;

  void _request() {
    if (_granted0) return;
    Sounds.play(Beep.login);
    setState(() => _granted0 = true);
    if (motionAllowed(context)) {
      _timer = Timer(const Duration(milliseconds: 1600), _enter);
    } else {
      // No scan to watch, so no wait.
      WidgetsBinding.instance.addPostFrameCallback((_) => _enter());
    }
  }

  void _enter() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => FrontPage(data: widget.data),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: motionAllowed(context)
            ? const Duration(milliseconds: 500)
            : Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DexThemeScope(
      child: Builder(
        builder: (context) {
          final theme = DexTheme.of(context);
          TextStyle? h(TextStyle? base, Color colour) =>
              theme.heading(base)?.copyWith(color: colour, letterSpacing: 2);
          final text = Theme.of(context).textTheme;
          final fed = widget.data.repository.data.factions
              .where((f) => f.id == 'federation')
              .firstOrNull;
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      children: [
                        _BarRow(
                          left: _lavender,
                          bar: _lavender,
                          right: _gold,
                          label: Text(
                            'LCARS ONLINE',
                            style: h(text.headlineMedium, _gold),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (fed != null)
                          FactionLogo(
                            path: fed.logoFor('TNG'),
                            name: fed.name,
                            size: 120,
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'STARFLEET COMMAND LIBRARY DATABASE',
                          textAlign: TextAlign.center,
                          style: h(text.headlineMedium, _lavender),
                        ),
                        const SizedBox(height: 20),
                        _granted0
                            ? Text(
                                'ACCESS GRANTED',
                                style: h(text.headlineSmall, _granted),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const LcarsLamp(
                                    colour: _red,
                                    width: 30,
                                    height: 26,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: LcarsTicker(
                                      period: const Duration(milliseconds: 500),
                                      builder: (context, tick) => Opacity(
                                        opacity: tick % 3 == 2 ? 0.15 : 1,
                                        // One line between the lamps, shrinking
                                        // rather than wrapping at large text sizes.
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'ACCESS RESTRICTED',
                                            maxLines: 1,
                                            style: h(text.headlineSmall, _red),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const LcarsLamp(
                                    colour: _red,
                                    width: 30,
                                    height: 26,
                                    phase: 1,
                                  ),
                                ],
                              ),
                        const SizedBox(height: 20),
                        if (_granted0)
                          const SizedBox(
                            width: 320,
                            child: LcarsScanBar(
                              colour: _granted,
                              height: 10,
                              period: Duration(milliseconds: 900),
                            ),
                          )
                        else
                          Semantics(
                            button: true,
                            label: 'Request access',
                            onTap: _request,
                            excludeSemantics: true,
                            child: Material(
                              color: _red,
                              shape: const StadiumBorder(),
                              child: InkWell(
                                customBorder: const StadiumBorder(),
                                onTap: _request,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    'REQUEST ACCESS',
                                    style: h(text.titleMedium, Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        Text(
                          'COMMAND AUTHORIZATION REQUIRED',
                          textAlign: TextAlign.center,
                          style: h(text.titleLarge, _lavender),
                        ),
                        const SizedBox(height: 16),
                        _BarRow(left: _gold, bar: _lavender, right: _gold),
                        const SizedBox(height: 12),
                        Text(
                          'All creative content related to Star Trek is copyright Paramount Pictures.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The website's bar: a rounded cap at each end and a long bar between.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.left,
    required this.bar,
    required this.right,
    this.label,
  });

  final Color left;
  final Color bar;
  final Color right;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    const h = 32.0;
    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            Container(
              width: 22,
              decoration: BoxDecoration(
                color: left,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(h / 2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (label != null) ...[
              // At most half the row; it shrinks rather than squeeze the bar out.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth / 2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(fit: BoxFit.scaleDown, child: label),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Container(color: bar)),
            const SizedBox(width: 8),
            Container(
              width: 22,
              decoration: BoxDecoration(
                color: right,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(h / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

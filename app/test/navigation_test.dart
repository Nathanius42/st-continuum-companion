import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:continuum_dex/app.dart';
import 'package:continuum_dex/data/models.dart';
import 'package:continuum_dex/data/ship_repository.dart';
import 'package:continuum_dex/screens/ship_browser_screen.dart';
import 'package:continuum_dex/screens/ship_detail.dart';
import 'package:continuum_dex/theme/dex_theme.dart';
import 'package:continuum_dex/ui/faction_logo.dart';
import 'package:continuum_dex/ui/lcars.dart';
import 'package:continuum_dex/ui/turntable_view.dart';

void main() {
  late ShipRepository repository;
  late ThemeLibrary themes;

  setUpAll(() {
    final json = jsonDecode(
      File('assets/data/ships.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    repository = ShipRepository(
      DexData.fromJson(json),
      clock: () => DateTime(2026, 10, 17),
    );
    themes = ThemeLibrary(
      jsonDecode(File('assets/data/themes.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  /// Reduced motion, so the turntables stay still and the tests can settle.
  void stillMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// From launch: the splash, the front page, then the Starship Database's eras.
  Future<void> openLibrary(WidgetTester tester) async {
    stillMotion(tester);
    await tester.pumpWidget(DexApp(repository: repository, themes: themes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('STARSHIP\nDATABASE'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('STARSHIP\nDATABASE'));
    await tester.pumpAndSettle();
  }

  Future<void> openGalaxy(WidgetTester tester) async {
    await openLibrary(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^The Next Generation,')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FEDERATION'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Galaxy'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Galaxy'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone: era → faction → ship page, and the variant toggle swaps stats',
    (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openGalaxy(tester);
      expect(find.text('Heavy Explorer'), findsWidgets);
      expect(find.text('GAME SPECS', skipOffstage: false), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('111,700'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('111,700'), findsOneWidget);
      final research = find.text(
        'Capital Sized Chassis, or Capital Sized Reinforcements',
      );
      await tester.scrollUntilVisible(
        research,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(research, findsOneWidget);
      // Canon (#423) and credits (#425) close the page.
      await tester.scrollUntilVisible(
        find.text('Read on Memory Alpha'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Seen on screen'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Major Stress'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      final saucer = find.widgetWithText(ChoiceChip, 'Saucer');
      await tester.scrollUntilVisible(
        saucer,
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(saucer);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('65,100'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('65,100'), findsOneWidget);
      expect(find.text('111,700'), findsNothing);
    },
  );

  testWidgets('wide window: list and ship page side by side (#542)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openGalaxy(tester);
    // Still on the browser screen: the Galaxy is in the list and on the page beside it.
    expect(
      find.descendant(of: find.byType(ShipList), matching: find.text('Galaxy')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ShipDetail),
        matching: find.text('Galaxy'),
      ),
      findsWidgets,
    );
    expect(find.text('111,700', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'sidebar switches between sibling screens, and HOME returns to the front page',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openLibrary(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^The Next Generation,')));
      await tester.pumpAndSettle();

      // The faction list's sidebar lists the eras.
      await tester.tap(find.text('TOS'));
      await tester.pumpAndSettle();
      expect(find.text('THE ORIGINAL SERIES'), findsOneWidget);

      // The ship list's sidebar lists that era's factions.
      await tester.tap(find.text('FEDERATION').first);
      await tester.pumpAndSettle();
      final other = repository.factionsIn('TOS')[1];
      // The ship list's sidebar shows the factions by their badges alone.
      expect(
        find.descendant(
          of: find.byType(LcarsFrame),
          matching: find.text(other.name.toUpperCase()),
        ),
        findsNothing,
      );
      await tester.tap(find.bySemanticsLabel(other.name));
      await tester.pumpAndSettle();
      expect(find.text(other.name.toUpperCase()), findsWidgets);

      // Back goes up a level, not back through the siblings.
      await tester.tap(find.text('BACK'));
      await tester.pumpAndSettle();
      expect(find.text('THE ORIGINAL SERIES'), findsOneWidget);

      await tester.tap(find.text('FEDERATION').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('STARSHIP\nDATABASE'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    },
  );

  testWidgets('the ship page shows the turntable and turns by drag (#491)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openGalaxy(tester);
    final galaxy = repository.data.ships.firstWhere(
      (s) => s.id == 'fed_TNG_galaxy',
    );
    expect(galaxy.turntable, isNotNull);
    expect(find.byType(TurntableView), findsOneWidget);

    // Decode the sheet outside the fake clock, then let the view pick it up.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(TurntableView));
      await precacheImage(AssetImage(galaxy.turntable!.sheet), context);
    });
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Drag sideways')), findsOneWidget);
    await tester.drag(find.byType(TurntableView), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('front page (#941)', () {
    Future<void> openFrontPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      stillMotion(tester);
      await tester.pumpWidget(DexApp(repository: repository, themes: themes));
      await tester.pumpAndSettle();
      expect(find.text('ACCESS RESTRICTED'), findsOneWidget);
      await tester.tap(find.text('REQUEST ACCESS'));
      await tester.pumpAndSettle();
    }

    testWidgets('the splash grants access and opens the front page', (
      tester,
    ) async {
      await openFrontPage(tester);
      expect(find.text('STARSHIP\nDATABASE'), findsOneWidget);
      expect(find.bySemanticsLabel('Star Trek: Continuum'), findsOneWidget);
      // HOME has nowhere further to go: the front page is the first screen.
      expect(find.text('HOME'), findsNothing);
      expect(find.text('BACK'), findsNothing);
    });

    testWidgets('each section opens, and the sidebar moves between them', (
      tester,
    ) async {
      await openFrontPage(tester);
      await tester.tap(find.text('ABOUT'));
      await tester.pumpAndSettle();
      expect(find.text('CONTINUUM CORP · PERSONNEL FILES'), findsOneWidget);
      expect(
        find.text('STC-001: NATHANIUS', findRichText: true),
        findsOneWidget,
      );

      for (final (section, heading) in [
        ('COMMS', 'SUBSPACE COMMUNICATIONS NET'),
        ('ACCESS', 'ONLINE RECORDS ACCESS'),
        ('MEDIA', 'HOLODECK PROGRAMMING'),
      ]) {
        await tester.tap(find.text(section).first);
        await tester.pumpAndSettle();
        expect(find.text(heading), findsOneWidget);
      }
      expect(find.text('GORN RELEASE TRAILER · YOUTUBE'), findsOneWidget);
      // A program opens its thumbnail, which plays the trailer.
      expect(find.bySemanticsLabel(RegExp('^Play Gorn')), findsNothing);
      await tester.tap(find.text('GORN RELEASE TRAILER · YOUTUBE'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Play Gorn release trailer on YouTube'),
        findsOneWidget,
      );

      // Siblings don't stack: BACK returns to the front page.
      await tester.tap(find.text('BACK'));
      await tester.pumpAndSettle();
      expect(find.text('STARSHIP\nDATABASE'), findsOneWidget);
      expect(find.text('BACK'), findsNothing);
    });

    testWidgets('the logo is its still image on returning (no black frame)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Motion allowed, so the logo animates.
      await tester.pumpWidget(DexApp(repository: repository, themes: themes));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('REQUEST ACCESS'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      ImageProvider logo() => tester
          .widget<Image>(
            find.descendant(
              of: find.bySemanticsLabel('Star Trek: Continuum'),
              matching: find.byType(Image),
            ),
          )
          .image;
      expect((logo() as AssetImage).assetName, 'assets/home/stc_logo.webp');
      // Leave before it finishes, then come back.
      await tester.tap(find.text('ABOUT'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('BACK'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        (logo() as AssetImage).assetName,
        'assets/home/stc_logo_still.webp',
      );
      // Let the timers and tickers wind down before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('Credits is reached from About', (tester) async {
      await openFrontPage(tester);
      await tester.tap(find.text('ABOUT'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('CREDITS'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('CREDITS'));
      await tester.pumpAndSettle();
      expect(find.text('MOD DATABASE ARCHIVE · CREDITS'), findsOneWidget);
      expect(find.text('SCRIPTS:'), findsOneWidget);
    });

    testWidgets('Factions: the map picks a faction, the eras change the map', (
      tester,
    ) async {
      await openFrontPage(tester);
      await tester.tap(find.text('FACTIONS'));
      await tester.pumpAndSettle();
      // TNG to begin with: the Dominion stands in the Gamma Quadrant.
      expect(find.text('DOMINION'), findsWidgets);
      // No faction badges; the chosen faction's homeworld scene instead.
      expect(find.byType(FactionLogo), findsNothing);
      expect(find.bySemanticsLabel('Federation homeworld'), findsOneWidget);
      await tester.tap(find.text('KLINGON EMPIRE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SHIPS IN'), findsOneWidget);
      // The blurb follows the era: the civil war in TNG, first contact in ENT.
      expect(find.textContaining('CIVIL WAR'), findsOneWidget);
      // ENT has no Dominion, and the Klingons stay chosen.
      await tester.tap(find.bySemanticsLabel('Show ENT, 2160'));
      await tester.pumpAndSettle();
      expect(find.text('DOMINION'), findsNothing);
      expect(find.text('ENTERPRISE · 2160'), findsOneWidget);
      expect(find.textContaining('MEETS EARTH IN 2151'), findsOneWidget);
      // The fleet evaluation opens that faction's ships.
      await tester.ensureVisible(find.text('OPEN FLEET RECORDS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN FLEET RECORDS'));
      await tester.pumpAndSettle();
      expect(find.byType(ShipList), findsOneWidget);
      expect(find.text('KLINGON EMPIRE'), findsWidgets);
    });
  });

  testWidgets('a carrier titles its craft "Carrier and complement" (#931)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openLibrary(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^The Next Generation,')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CARDASSIAN UNION'));
    await tester.pumpAndSettle();
    final hutet = find.descendant(
      of: find.byType(ShipList),
      matching: find.text('Hutet'),
    );
    await tester.scrollUntilVisible(
      hutet,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(hutet);
    await tester.pumpAndSettle();
    expect(find.text('CARRIER AND COMPLEMENT'), findsOneWidget);
    expect(find.text('VARIANTS'), findsNothing);
  });

  group('keyboard and mouse (#546, #547)', () {
    testWidgets('Escape goes back and Alt+Home returns to the front page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openGalaxy(tester);
      expect(find.byType(ShipList), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('FEDERATION'), findsWidgets);
      expect(find.byType(ShipList), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(find.text('STARSHIP\nDATABASE'), findsOneWidget);
      expect(find.text('BACK'), findsNothing);
      // On the first screen there's nowhere to go back to.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('STARSHIP\nDATABASE'), findsOneWidget);
    });

    testWidgets('the wheel turns a focused turntable, Shift+wheel any time', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openGalaxy(tester);
      final galaxy = repository.data.ships.firstWhere(
        (s) => s.id == 'fed_TNG_galaxy',
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(TurntableView));
        await precacheImage(AssetImage(galaxy.turntable!.sheet), context);
      });
      await tester.pump();
      final view = find.byType(TurntableView);
      int frame() =>
          (tester
                          .widget<CustomPaint>(
                            find
                                .descendant(
                                  of: view,
                                  matching: find.byType(CustomPaint),
                                )
                                .last,
                          )
                          .painter!
                      as dynamic)
                  .frame
              as int;
      final centre = tester.getCenter(view);
      final start = frame();

      // Unfocused, the plain wheel is the page's.
      await tester.sendEventToBinding(
        PointerScrollEvent(position: centre, scrollDelta: const Offset(0, 40)),
      );
      await tester.pump();
      expect(frame(), start);

      // Shift+wheel turns it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: centre, scrollDelta: const Offset(0, 40)),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(frame(), (start + 1) % galaxy.turntable!.frames);
    });
  });
}

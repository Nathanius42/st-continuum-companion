import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:continuum_dex/app.dart';
import 'package:continuum_dex/data/models.dart';
import 'package:continuum_dex/data/ship_repository.dart';
import 'package:continuum_dex/theme/dex_theme.dart';

/// The accessibility pass (#503): screen readers, touch targets and large text.
void main() {
  late ShipRepository repository;
  late ThemeLibrary themes;

  setUpAll(() {
    repository = ShipRepository(
      DexData.fromJson(
        jsonDecode(File('assets/data/ships.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
      clock: () => DateTime(2026, 10, 17),
    );
    themes = ThemeLibrary(
      jsonDecode(File('assets/data/themes.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  /// A phone with reduced motion, and [textScale] for the user's text size.
  Future<void> openFrontPage(
    WidgetTester tester, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(DexApp(repository: repository, themes: themes));
    await tester.pumpAndSettle();
    // At large text sizes the splash scrolls to its button.
    await tester.ensureVisible(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();
  }

  Future<void> openGalaxy(WidgetTester tester) async {
    await tester.tap(find.text('SEARCH'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'galaxy');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galaxy').first);
    await tester.pumpAndSettle();
  }

  Future<void> meetsGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('touch targets are big enough and labelled, and text reads', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openFrontPage(tester);
    await meetsGuidelines(tester);
    await openGalaxy(tester);
    await meetsGuidelines(tester);
    handle.dispose();
  });

  testWidgets('a screen reader can press every frame button', (tester) async {
    final handle = tester.ensureSemantics();
    await openFrontPage(tester);
    // Each menu row is one button, read as its name and caption.
    for (final label in [
      'Search, 4 eras',
      'Factions, 14 powers',
      'About, Mission',
      'Media, 7 trailers',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    // The first row reads its count of entries.
    expect(
      find.bySemanticsLabel(RegExp(r'^Starship Database, \d+ entries$')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Audio on')),
      matchesSemantics(
        label: 'Audio on',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    // The stardate is read once.
    expect(find.bySemanticsLabel(RegExp('^Stardate ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('STARDATE')), findsNothing);
    handle.dispose();
  });

  testWidgets('the ship page has headings, one Back, and tiles read as pairs', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openFrontPage(tester);
    await openGalaxy(tester);
    final back = tester.getSemantics(find.bySemanticsLabel('Back'));
    expect(back.label, 'Back');
    expect(back.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    for (final heading in ['Galaxy', 'Variants', 'Specifications']) {
      final headers = find
          .bySemanticsLabel(heading)
          .evaluate()
          .where(
            (e) => tester
                .getSemantics(find.byWidget(e.widget))
                .getSemanticsData()
                .flagsCollection
                .isHeader,
          );
      expect(headers, isNotEmpty, reason: heading);
    }
    expect(find.bySemanticsLabel('Length: 652'), findsOneWidget);
    handle.dispose();
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('at ${scale}x text, the main screens lay out without overflow', (
      tester,
    ) async {
      // A RenderFlex overflow fails the test by itself.
      await openFrontPage(tester, textScale: scale);
      for (final section in ['ABOUT', 'FACTIONS', 'MEDIA']) {
        await tester.tap(find.text(section).first);
        await tester.pumpAndSettle();
      }
      await openGalaxy(tester);
      // Down to the end of the ship page, laying out every section on the way.
      await tester.scrollUntilVisible(
        find.text('CREDITS'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
    });
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:continuum_dex/app.dart';
import 'package:continuum_dex/data/models.dart';
import 'package:continuum_dex/data/search.dart';
import 'package:continuum_dex/data/ship_repository.dart';
import 'package:continuum_dex/theme/dex_theme.dart';

void main() {
  final repository = ShipRepository(
    DexData.fromJson(
      jsonDecode(File('assets/data/ships.json').readAsStringSync())
          as Map<String, dynamic>,
    ),
    clock: () => DateTime(2026, 10, 18),
  );
  List<SearchHit> search(ShipQuery q) => searchShips(repository, q);

  group('search (#496)', () {
    test('a name starting with the text comes first', () {
      final hits = search(const ShipQuery(text: 'galaxy'));
      expect(hits.first.ship.id, 'fed_TNG_galaxy');
      expect(hits.first.reason, isNull);
    });

    test('a named ship finds its class, and says so', () {
      final hits = search(const ShipQuery(text: 'Yamato'));
      final galaxy = hits.firstWhere((h) => h.ship.id == 'fed_TNG_galaxy');
      expect(galaxy.reason, 'U.S.S. Yamato · NCC-71807');
    });

    test('a registry finds its class, however it is typed', () {
      for (final text in ['NCC-1764', 'ncc 1764', 'ncc1764']) {
        final ids = search(ShipQuery(text: text)).map((h) => h.ship.id);
        expect(ids, contains('fed_TOS_constitution'), reason: text);
      }
    });

    test('accents and punctuation are ignored', () {
      final ids = search(const ShipQuery(text: 'hammarskjold'))
          .map((h) => h.ship.id);
      expect(ids, contains('fed_TMP_ambassador'));
    });

    test('nothing matching gives nothing', () {
      expect(search(const ShipQuery(text: 'zzzqqq')), isEmpty);
    });
  });

  group('filters (#497)', () {
    test('no query lists every ship listed today', () {
      expect(
        search(const ShipQuery()).length,
        repository.visibleShips().length,
      );
    });

    test('filters combine: any choice within one, all across them', () {
      final hits = search(
        const ShipQuery(
          eras: {'TNG'},
          factions: {'klingon', 'romulan'},
          families: {'Capital'},
        ),
      );
      expect(hits, isNotEmpty);
      for (final h in hits) {
        expect(h.ship.era, 'TNG');
        expect(['klingon', 'romulan'], contains(h.ship.faction));
        expect(familyOf(h.ship), 'Capital');
      }
      expect(hits.map((h) => h.ship.faction).toSet(), {'klingon', 'romulan'});
    });

    test('flagships filter as their own class', () {
      final hits = search(const ShipQuery(families: {flagshipFamily}));
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.ship.id.endsWith('_flagship')), isTrue);
    });

    test('text and filters together', () {
      final hits = search(const ShipQuery(text: 'bird', eras: {'ENT'}));
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.ship.era == 'ENT'), isTrue);
    });
  });

  testWidgets('the Search section finds a ship by a named ship and opens it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final themes = ThemeLibrary(
      jsonDecode(File('assets/data/themes.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(DexApp(repository: repository, themes: themes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEARCH'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'yamato');
    await tester.pumpAndSettle();
    expect(find.text('U.S.S. Yamato · NCC-71807'), findsOneWidget);
    // Wide: the first match's page is beside the list.
    expect(find.text('Heavy Explorer'), findsWidgets);

    // The panel shows the era options to begin with.
    expect(find.text('ERA FILTER'), findsOneWidget);
    await tester.tap(find.text('ENT · 2160'));
    await tester.pumpAndSettle();
    expect(find.text('NO MATCHING RECORDS'), findsOneWidget);
    expect(find.bySemanticsLabel('Era filter, 1 set'), findsOneWidget);
  });

  testWidgets('on a phone, a filter category opens over the results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final themes = ThemeLibrary(
      jsonDecode(File('assets/data/themes.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(DexApp(repository: repository, themes: themes));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEARCH'));
    await tester.pumpAndSettle();

    // Just the column on a phone: the options open when a category is tapped.
    expect(find.text('ERA FILTER'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Size filter'));
    await tester.pumpAndSettle();
    expect(find.text('SIZE FILTER'), findsOneWidget);
    await tester.tap(find.text('CAPITAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('SIZE FILTER'), findsNothing);
    expect(find.bySemanticsLabel('Size filter, 1 set'), findsOneWidget);
    expect(find.textContaining('1 FILTER'), findsOneWidget);
  });

  testWidgets('Compare (#498): pick a second ship, swap, and go back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final themes = ThemeLibrary(
      jsonDecode(File('assets/data/themes.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(DexApp(repository: repository, themes: themes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();
    // Find the Galaxy through Search, then open its page.
    await tester.tap(find.text('SEARCH'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'galaxy');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galaxy').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('COMPARE'));
    await tester.pumpAndSettle();
    expect(find.text('COMPARE WITH'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sovereign');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sovereign').first);
    await tester.pumpAndSettle();

    expect(find.text('COMPARE'), findsWidgets);
    expect(find.text('Galaxy'), findsOneWidget);
    expect(find.text('Sovereign'), findsOneWidget);
    await tester.tap(find.text('SWAP'));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('Sovereign'));
    final second = tester.getTopLeft(find.text('Galaxy'));
    expect(first.dx, lessThan(second.dx));
    await tester.scrollUntilVisible(
      find.text('BUILD TIME'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('HULL'), findsOneWidget);

    // The picker gave way to the comparison: BACK returns to the Galaxy's page.
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();
    expect(find.text('Heavy Explorer'), findsWidgets);
    expect(find.text('COMPARE WITH'), findsNothing);
  });
}

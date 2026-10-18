import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:continuum_dex/app.dart';
import 'package:continuum_dex/data/models.dart';
import 'package:continuum_dex/data/settings.dart';
import 'package:continuum_dex/data/ship_repository.dart';
import 'package:continuum_dex/screens/ship_browser_screen.dart';
import 'package:continuum_dex/theme/dex_theme.dart';
import 'package:continuum_dex/version.dart';

void main() {
  test('the app version matches pubspec.yaml (#528)', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line.trim(), 'version: $appVersion+$appBuild');
  });

  testWidgets('classic LCARS everywhere restyles the era screens (#592)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(() => Settings.classicLcars.value = false);

    final repository = ShipRepository(
      DexData.fromJson(
        jsonDecode(File('assets/data/ships.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
    final themes = ThemeLibrary(
      jsonDecode(File('assets/data/themes.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(DexApp(repository: repository, themes: themes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();

    // The Klingon ship list, reached through the Factions map.
    DexShape klingonShape() =>
        DexTheme.of(tester.element(find.byType(ShipList))).shape;

    await tester.tap(find.text('FACTIONS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KLINGON EMPIRE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('OPEN FLEET RECORDS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN FLEET RECORDS'));
    await tester.pumpAndSettle();
    final own = klingonShape();
    expect(own, isNot(DexTheme.classic.shape));

    Settings.classicLcars.value = true;
    await tester.pumpAndSettle();
    expect(klingonShape(), DexTheme.classic.shape);
    // The versions are shown on the front page.
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('CONTINUUM COMPANION $appVersion'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.textContaining('SHIP DATA R${repository.data.modRevision}'),
      findsOneWidget,
    );
  });
}

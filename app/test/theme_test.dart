import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:continuum_dex/theme/dex_theme.dart';

void main() {
  final library = ThemeLibrary(
    jsonDecode(File('assets/data/themes.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('TNG Federation is classic LCARS (#568)', () {
    final t = library.resolve(era: 'TNG', faction: 'federation');
    expect(t.structure, DexTheme.classic.structure);
    expect(t.accent, DexTheme.classic.accent);
    expect(t.shape, DexShape.lcars);
  });

  test('the era sets the frame; a faction with its own interface replaces it (#569)', () {
    final klingon = library.resolve(era: 'TNG', faction: 'klingon');
    expect(klingon.structure, isNot(DexTheme.classic.structure));
    expect(klingon.shape, DexShape.angular);
    // The Klingon frame is the same whatever the era.
    expect(
      library.resolve(era: 'TMP', faction: 'klingon').structure,
      klingon.structure,
    );

    final tmp = library.resolve(era: 'TMP', faction: 'federation');
    expect(tmp.shape, DexShape.film);
    expect(tmp.structure, library.resolve(era: 'TMP').structure);

    final tos = library.resolve(era: 'TOS', faction: 'federation');
    expect(tos.shape, DexShape.console);

    // Each faction family from the on-screen research (#578-#584).
    for (final (era, faction, shape) in [
      ('ENT', 'federation', DexShape.panel),
      ('TNG', 'romulan', DexShape.slanted),
      ('TNG', 'dominion', DexShape.arched),
      ('TMP', 'gorn', DexShape.stone),
      ('TNG', 'ferengi', DexShape.bezel),
      ('TNG', 'voth', DexShape.rounded),
    ]) {
      expect(
        library.resolve(era: era, faction: faction).shape,
        shape,
        reason: '$era $faction',
      );
    }
    expect(
      library.resolve(era: 'TNG', faction: 'cardassian').shape,
      DexShape.elliptical,
    );
    expect(library.resolve(era: 'TNG', faction: 'borg').shape, DexShape.radial);
  });

  test('each era and faction has its heading font and script (#586)', () {
    expect(library.resolve(era: 'TNG').headingFont, 'LeagueGothic');
    expect(library.resolve(era: 'ENT').headingFont, 'PathwayGothic');
    expect(library.resolve(era: 'TOS').headingFont, 'TrekClassic');
    expect(library.resolve(era: 'TMP').headingFont, 'TrekMovie');
    final klingon = library.resolve(era: 'TNG', faction: 'klingon');
    expect(klingon.headingFont, 'KlingonDagger');
    expect(klingon.scriptFont, 'KlingonGlyphs');
    // A faction that shares its era's frame keeps the era's heading font.
    final tholian = library.resolve(era: 'TNG', faction: 'tholian');
    expect(tholian.headingFont, 'LeagueGothic');
    expect(tholian.scriptFont, 'TholianGlyphs');
    final terran = library.resolve(era: 'TOS', faction: 'terran');
    expect(terran.headingFont, 'TrekClassic');
    expect(terran.scriptFont, isNull);
    expect(
      library.resolve(era: 'TNG', faction: 'federation').scriptFont,
      isNull,
    );
  });

  test('a faction without its own interface changes only the accent', () {
    final era = library.resolve(era: 'TOS');
    final terran = library.resolve(era: 'TOS', faction: 'terran');
    expect(terran.structure, era.structure);
    expect(terran.shape, era.shape);
    expect(terran.accent, isNot(era.accent));
  });

  test(
    'no era means classic, and an unknown faction leaves the era theme alone',
    () {
      expect(library.resolve().structure, DexTheme.classic.structure);
      final tmp = library.resolve(era: 'TMP');
      expect(library.resolve(era: 'TMP', faction: 'nobody').accent, tmp.accent);
      expect(
        library.resolve(era: 'TNG', faction: 'federation').structure,
        DexTheme.classic.structure,
      );
    },
  );

  test('every text colour reads on its background (WCAG AA, #573)', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final era in ['ENT', 'TOS', 'TMP', 'TNG']) {
      for (final faction in [
        null,
        'federation',
        'klingon',
        'romulan',
        'cardassian',
        'dominion',
        'borg',
        'voth',
        'terran',
        'ferengi',
      ]) {
        final t = library.resolve(era: era, faction: faction);
        for (var i = 0; i < t.structure.length; i++) {
          expect(
            contrast(t.textOnStructure[i], t.structure[i]),
            greaterThanOrEqualTo(4.5),
            reason: '$era/$faction structure $i',
          );
        }
        expect(
          contrast(t.textOnAccent, t.accent),
          greaterThanOrEqualTo(4.5),
          reason: '$era/$faction accent',
        );
      }
    }
  });
}

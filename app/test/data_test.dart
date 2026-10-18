import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:continuum_dex/data/home_content.dart';
import 'package:continuum_dex/data/models.dart';
import 'package:continuum_dex/data/ship_repository.dart';
import 'package:continuum_dex/data/ship_view.dart';
import 'package:continuum_dex/screens/factions_screen.dart';
import 'package:continuum_dex/ui/format.dart';

/// Reads a data file from disk. `flutter test` runs from the app folder.
DexData readData(String path) => DexData.fromJson(
  jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
);

void main() {
  group('parsing (#478)', () {
    test('the hand-checked sample ships parse with their values', () {
      final data = readData('../data/samples/ships.sample.json');
      expect(data.ships.map((s) => s.id), contains('fed_TNG_galaxy'));
      final galaxy = data.ships.firstWhere((s) => s.id == 'fed_TNG_galaxy');
      expect(galaxy.subtitle, 'Heavy Explorer');
      expect(
        galaxy.weapons.total,
        galaxy.weapons.beam +
            galaxy.weapons.pulse +
            galaxy.weapons.torpedo +
            galaxy.weapons.other,
      );
      expect(galaxy.research!.anyOf.first.name, 'Capital Sized Chassis');
      final crystalline = data.ships.firstWhere(
        (s) => s.id == 'zzz_TNG_crystallineentity',
      );
      expect(crystalline.description, isNull);
      expect(crystalline.stats.length, isNull);
    });

    test('the bundled data file parses completely', () {
      final data = readData('assets/data/ships.json');
      expect(data.ships.length, greaterThan(300));
      expect(data.eras.map((e) => e.id), ['ENT', 'TOS', 'TMP', 'TNG']);
    });

    test('notable ships carry the registry painted on the hull (#934)', () {
      final data = readData('assets/data/ships.json');
      final excelsior = data.ships.firstWhere(
        (s) => s.id == 'fed_TMP_excelsior',
      );
      expect(excelsior.notableShips.first.name, 'U.S.S. Excelsior');
      expect(excelsior.notableShips.first.registry, 'NCC-2000');
      // Placeholder lists ("Vector Alpha" for every ship) name no ships.
      final brisbane = data.ships.firstWhere((s) => s.id == 'fed_TNG_brisbane');
      expect(brisbane.notableShips, isEmpty);
    });
  });

  group('repository (#477)', () {
    final data = readData('assets/data/ships.json');

    test('ships are grouped by class in a fixed order, A–Z within each', () {
      final groups = ShipRepository(data).shipsByClass('TNG', 'federation');
      final families = groups.map((g) => g.family).toList();
      // The fleet's flagship heads the list in a group of its own (#931).
      expect(families.take(2), ['Flagship', 'Capital']);
      expect(groups.first.ships.map((s) => s.id), ['fed_TNG_flagship']);
      expect(groups.skip(1).expand((g) => g.ships).any(isFlagship), isFalse);
      expect(
        families.indexOf('Frigate'),
        lessThan(families.indexOf('Platform')),
      );
      final capitals = groups[1].ships.map((s) => s.name).toList();
      expect(capitals, [...capitals]..sort());
    });

    test('the Brisbane is listed only on 28 July (#635)', () {
      bool listed(DateTime day) => ShipRepository(data, clock: () => day)
          .shipsByClass('TNG', 'federation')
          .any((g) => g.ships.any((s) => s.id == 'fed_TNG_brisbane'));
      expect(listed(DateTime(2026, 7, 28)), isTrue);
      expect(listed(DateTime(2026, 7, 27)), isFalse);
      expect(listed(DateTime(2026, 10, 17)), isFalse);
    });

    test(
      'factions in an era are only those with ships there, playable first',
      () {
        final ids = ShipRepository(data)
            .factionsIn('TMP')
            .map((f) => f.id)
            .toList();
        expect(ids, containsAll(['federation', 'klingon', 'romulan', 'gorn']));
        expect(ids, isNot(contains('borg')));
      },
    );
  });

  test(
    'every faction with a homeworld has its scene, for each era it is in',
    () {
      final data = readData('assets/data/ships.json');
      for (final era in data.eras) {
        for (final f in data.factions) {
          final scene = homeworldScene(f.id, era.id);
          if (scene == null) continue;
          expect(File(scene).existsSync(), isTrue, reason: '${f.id} ${era.id}');
        }
      }
    },
  );

  test('a variant overrides only the stats it records (#616)', () {
    final data = readData('assets/data/ships.json');
    final galaxy = ShipRepository(data).byId('TNG', 'fed_TNG_galaxy')!;
    final saucer = galaxy.variants.firstWhere((v) => v.id == 'saucer');
    final view = ShipView(galaxy, saucer);
    expect(view.stats.maxHealth, saucer.stats!.maxHealth);
    expect(view.changes((s) => s.maxHealth), isTrue);
    expect(ShipView(galaxy).changes((s) => s.maxHealth), isFalse);
  });

  test('a mode names both states on the toggle', () {
    final data = readData('assets/data/ships.json');
    String base(String id) =>
        baseToggleLabel(data.ships.firstWhere((s) => s.id == id));
    expect(base('kng_TNG_fighter'), 'Flight Mode');
    expect(base('car_TNG_turret'), 'Stand-By Mode');
    expect(base('fed_TNG_galaxy'), 'Galaxy');
    // Stations without a render of their own show their TNG counterparts'.
    final outpost = data.ships.firstWhere((s) => s.id == 'fed_TMP_outpost');
    expect(outpost.turntable?.sheet, 'assets/turntables/fed_TNG_outpost.webp');
  });

  test('each weapon carries its figures from the .wepn file (#428)', () {
    final data = readData('../data/samples/ships.sample.json');
    final galaxy = data.ships.firstWhere((s) => s.id == 'fed_TNG_galaxy');
    final phasers = galaxy.weapons.details.firstWhere(
      (w) => w.name == 'Phaser Beams Mk 11',
    );
    expect(phasers.count, 6);
    expect(
      weaponFigures(phasers),
      '676 damage a hit · every 5 s · 135.1 per second · range 5,500',
    );
    expect(galaxy.weapons.dps, 950);
    expect(
      galaxy.weapons.details.fold<int>(0, (n, w) => n + w.count),
      galaxy.weapons.total,
    );
  });

  test(
    'a burst says how many shots, and short intervals keep their decimals',
    () {
      const pulses = WeaponDetail(
        name: 'Disruptor Pulses',
        kind: 'pulse',
        count: 2,
        damage: 1364,
        cycle: 10,
        shotsPerCycle: 2,
        dps: 272.8,
      );
      expect(weaponFigures(pulses), contains('2 shots every 10 s'));
      expect(seconds(0.4), '0.4 s');
      expect(seconds(1.25), '1.25 s');
      expect(seconds(15), '15 s');
    },
  );

  test('every trailer on Media has a bundled thumbnail', () {
    final content = HomeContent.fromJson(
      jsonDecode(File('assets/data/home.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final l in content.media) {
      final uri = Uri.parse(l.url);
      final id = uri.queryParameters['v'] ?? uri.pathSegments.last;
      expect(
        File('assets/media/$id.webp').existsSync(),
        isTrue,
        reason: l.title,
      );
    }
  });
}

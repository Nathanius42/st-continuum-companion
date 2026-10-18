import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Where the bundled data file lives (written by pipeline/build_data.py).
const shipDataAsset = 'assets/data/ships.json';

/// The order classes appear in on a ship list; anything else goes last, A–Z.
/// The ship-list group for a fleet's flagship, shown above Capital.
const flagshipFamily = 'Flagship';

/// A faction's starting flagship. The mod names every one `<race>_<era>_flagship`.
bool isFlagship(Ship ship) => ship.id.endsWith('_flagship');

const familyOrder = [
  flagshipFamily,
  'Capital',
  'Frigate',
  'Corvette',
  'Fighter',
  'Utility',
  'Platform',
];

/// Lookups the screens use. Everything is held in memory: the whole file is
/// well under a megabyte, so there's no need for a database.
class ShipRepository {
  ShipRepository(this.data, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _byId = {for (final s in data.ships) '${s.era}/${s.id}': s};

  final DexData data;

  /// Supplies "today" for date-gated entries; tests pass a fixed date.
  final DateTime Function() _clock;
  final Map<String, Ship> _byId;

  static Future<ShipRepository> load(
    AssetBundle bundle, {
    DateTime Function()? clock,
  }) async {
    final text = await bundle.loadString(shipDataAsset);
    return ShipRepository(
      DexData.fromJson(jsonDecode(text) as Map<String, dynamic>),
      clock: clock,
    );
  }

  List<EraInfo> get eras => data.eras;

  /// Factions with at least one ship listed in [era] today, playable ones first.
  List<Faction> factionsIn(String era) {
    final present = {for (final s in _visible(era)) s.faction};
    return [
      ...data.factions.where((f) => f.playable && present.contains(f.id)),
      ...data.factions.where((f) => !f.playable && present.contains(f.id)),
    ];
  }

  /// The ships of [faction] in [era], grouped by class in [familyOrder] and
  /// sorted by name within each group. The fleet's flagship heads the list in a
  /// group of its own, whatever class the engine gives it.
  List<({String family, List<Ship> ships})> shipsByClass(
    String era,
    String faction,
  ) {
    final groups = <String, List<Ship>>{};
    for (final ship in _visible(era).where((s) => s.faction == faction)) {
      groups
          .putIfAbsent(
            isFlagship(ship) ? flagshipFamily : ship.displayFamily,
            () => [],
          )
          .add(ship);
    }
    final families = groups.keys.toList()
      ..sort((a, b) {
        final ia = familyOrder.indexOf(a), ib = familyOrder.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
    return [
      for (final f in families)
        (
          family: f,
          ships: groups[f]!..sort((a, b) => a.name.compareTo(b.name)),
        ),
    ];
  }

  Ship? byId(String era, String id) => _byId['$era/$id'];

  EraInfo era(String id) => data.eras.firstWhere((e) => e.id == id);

  Faction faction(String id) => data.factions.firstWhere((f) => f.id == id);

  /// Every ship that should be listed today, all eras: date-gated entries only
  /// on their day.
  Iterable<Ship> visibleShips() {
    final today = _clock();
    return data.ships.where((s) => s.showOnlyOn?.matches(today) ?? true);
  }

  /// Ships in [era] that should be listed today: date-gated entries only on their day.
  Iterable<Ship> _visible(String era) {
    final today = _clock();
    return data.ships.where(
      (s) => s.era == era && (s.showOnlyOn?.matches(today) ?? true),
    );
  }
}

import 'models.dart';
import 'ship_repository.dart';

/// Search and filters across every era (#495).
///
/// The text is matched against a ship's name, subtitle and hull id, its class,
/// its variants (a saucer, a refit), and the ships the game names for its class
/// with their registries, so "Yamato" and "NCC-1701" both find their class.
/// Filters narrow by era, faction, class, role, size and how the ship appears in
/// the game; within one filter any choice matches, and across filters all must.
class ShipQuery {
  const ShipQuery({
    this.text = '',
    this.eras = const {},
    this.factions = const {},
    this.families = const {},
    this.roles = const {},
    this.sizes = const {},
    this.availability = const {},
  });

  final String text;
  final Set<String> eras;
  final Set<String> factions;

  /// Ship-list classes, with [flagshipFamily] for the fleets' flagships.
  final Set<String> families;
  final Set<String> roles;
  final Set<String> sizes;
  final Set<String> availability;

  bool get isEmpty =>
      normalise(text).isEmpty &&
      eras.isEmpty &&
      factions.isEmpty &&
      families.isEmpty &&
      roles.isEmpty &&
      sizes.isEmpty &&
      availability.isEmpty;

  /// How many filters are set, for a badge on the filter button.
  int get filterCount => [
    eras,
    factions,
    families,
    roles,
    sizes,
    availability,
  ].fold(0, (n, s) => n + s.length);

  ShipQuery copyWith({
    String? text,
    Set<String>? eras,
    Set<String>? factions,
    Set<String>? families,
    Set<String>? roles,
    Set<String>? sizes,
    Set<String>? availability,
  }) => ShipQuery(
    text: text ?? this.text,
    eras: eras ?? this.eras,
    factions: factions ?? this.factions,
    families: families ?? this.families,
    roles: roles ?? this.roles,
    sizes: sizes ?? this.sizes,
    availability: availability ?? this.availability,
  );
}

/// A ship that matched, and what matched when it wasn't the ship's own name
/// ("U.S.S. Yamato · NCC-71807", "Variant: Saucer").
class SearchHit {
  const SearchHit(this.ship, {this.reason});

  final Ship ship;
  final String? reason;
}

/// The ship-list class a ship sits under: [flagshipFamily] for a flagship.
String familyOf(Ship ship) =>
    isFlagship(ship) ? flagshipFamily : ship.displayFamily;

/// Lower case, accents and punctuation gone, so "Hammarskjöld" finds
/// "hammarskjold" and "ncc 1701" finds "NCC-1701".
String normalise(String s) {
  const accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ý': 'y',
  };
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final c = accents[ch] ?? ch;
    if (RegExp(r'[a-z0-9]').hasMatch(c)) out.write(c);
  }
  return out.toString();
}

/// Ships matching [query], best matches first: the name starting with the
/// text, then containing it, then the subtitle, class or hull id, then a
/// variant, then a named ship or registry. Ties go by name, then era order.
List<SearchHit> searchShips(ShipRepository repository, ShipQuery query) {
  final needle = normalise(query.text);
  final eraOrder = [for (final e in repository.eras) e.id];
  final scored = <(int, SearchHit)>[];
  for (final ship in repository.visibleShips()) {
    if (!_passesFilters(ship, query)) continue;
    final match = needle.isEmpty ? (0, null) : _match(ship, needle);
    if (match == null) continue;
    scored.add((match.$1, SearchHit(ship, reason: match.$2)));
  }
  scored.sort((a, b) {
    final byScore = a.$1.compareTo(b.$1);
    if (byScore != 0) return byScore;
    final byName = a.$2.ship.name.compareTo(b.$2.ship.name);
    if (byName != 0) return byName;
    return eraOrder
        .indexOf(a.$2.ship.era)
        .compareTo(eraOrder.indexOf(b.$2.ship.era));
  });
  return [for (final s in scored) s.$2];
}

bool _passesFilters(Ship ship, ShipQuery q) =>
    (q.eras.isEmpty || q.eras.contains(ship.era)) &&
    (q.factions.isEmpty || q.factions.contains(ship.faction)) &&
    (q.families.isEmpty || q.families.contains(familyOf(ship))) &&
    (q.roles.isEmpty || ship.roles.any(q.roles.contains)) &&
    (q.sizes.isEmpty || q.sizes.contains(ship.sizeCategory)) &&
    (q.availability.isEmpty || ship.availability.any(q.availability.contains));

/// (rank, reason) for the best way [ship] matches [needle], or null.
(int, String?)? _match(Ship ship, String needle) {
  final name = normalise(ship.name);
  if (name.startsWith(needle)) return (0, null);
  if (name.contains(needle)) return (1, null);
  if (normalise(ship.subtitle ?? '').contains(needle) ||
      normalise(familyOf(ship)).contains(needle) ||
      normalise(ship.id).contains(needle)) {
    return (2, null);
  }
  for (final v in ship.variants) {
    if (normalise(v.label).contains(needle)) {
      return (3, 'Variant: ${v.label}');
    }
  }
  for (final n in ship.notableShips) {
    final reg = n.registry;
    // "U.S.S." and the like aren't worth matching on their own.
    final bare = n.name.replaceFirst(RegExp(r'^[A-Z]\.(?:[A-Z]\.)+\s*'), '');
    if (normalise(bare).contains(needle) ||
        (reg != null && normalise(reg).contains(needle))) {
      return (4, reg == null ? n.name : '${n.name} · $reg');
    }
  }
  return null;
}

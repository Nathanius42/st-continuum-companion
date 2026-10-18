/// The Dex's ship data, read from the JSON file the pipeline writes
/// (`pipeline/build_data.py`). Field names and meanings follow
/// `data/schema/ships.schema.json`; see the Ship Data Schema wiki page.
///
/// Each class has a `fromJson` factory written by hand rather than generated:
/// the schema is small and stable, and hand-written parsing keeps the app free
/// of a build_runner step and easy to read.
library;

/// The whole data file.
class DexData {
  const DexData({
    required this.modRevision,
    required this.generatedAt,
    required this.eras,
    required this.factions,
    required this.ships,
  });

  factory DexData.fromJson(Map<String, dynamic> json) {
    final version = json['dataVersion'] as Map<String, dynamic>;
    return DexData(
      modRevision: version['modRevision'] as int,
      generatedAt: DateTime.parse(version['generatedAt'] as String),
      eras: _list(json['eras'], EraInfo.fromJson),
      factions: _list(json['factions'], Faction.fromJson),
      ships: _list(json['ships'], Ship.fromJson),
    );
  }

  /// SVN revision of the mod the data was read from.
  final int modRevision;
  final DateTime generatedAt;
  final List<EraInfo> eras;
  final List<Faction> factions;
  final List<Ship> ships;
}

class EraInfo {
  const EraInfo({required this.id, required this.title, required this.year});

  factory EraInfo.fromJson(Map<String, dynamic> json) => EraInfo(
    id: json['id'] as String,
    title: json['title'] as String,
    year: json['year'] as int,
  );

  /// "ENT", "TOS", "TMP" or "TNG".
  final String id;
  final String title;

  /// The year the era is set in, which is also its mod folder ("STC - 2380").
  final int year;
}

class Faction {
  const Faction({
    required this.id,
    required this.name,
    required this.playable,
    required this.eras,
    this.logos = const {},
  });

  factory Faction.fromJson(Map<String, dynamic> json) => Faction(
    id: json['id'] as String,
    name: json['name'] as String,
    playable: json['playable'] as bool,
    eras: List<String>.from(json['eras'] as List),
    logos: Map<String, String>.from(json['logos'] as Map? ?? const {}),
  );

  final String id;
  final String name;

  /// False for factions that only appear as Keepers, allies or neutrals.
  final bool playable;

  /// Era ids this faction has entries in.
  final List<String> eras;

  /// Era id → asset path of the faction's emblem in that era (from the mod's
  /// badges). Missing where the mod has no badge.
  final Map<String, String> logos;

  String? logoFor(String era) => logos[era];
}

/// A month and day on which a date-gated entry is shown (the Brisbane easter egg).
class MonthDay {
  const MonthDay(this.month, this.day);

  factory MonthDay.fromJson(Map<String, dynamic> json) =>
      MonthDay(json['month'] as int, json['day'] as int);

  final int month;
  final int day;

  bool matches(DateTime date) => date.month == month && date.day == day;
}

class Ship {
  const Ship({
    required this.id,
    required this.era,
    required this.faction,
    required this.name,
    required this.subtitle,
    required this.availability,
    required this.displayFamily,
    required this.sizeCategory,
    required this.stats,
    required this.roles,
    required this.weapons,
    required this.abilities,
    required this.description,
    required this.research,
    required this.variants,
    required this.showOnlyOn,
    this.icon,
    this.credits = Credits.none,
    this.canon,
    this.turntable,
    this.notableShips = const [],
  });

  factory Ship.fromJson(Map<String, dynamic> json) {
    final classification = json['classification'] as Map<String, dynamic>;
    return Ship(
      id: json['id'] as String,
      era: json['era'] as String,
      faction: json['faction'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String?,
      availability: List<String>.from(json['availability'] as List),
      displayFamily: classification['displayFamily'] as String,
      sizeCategory: classification['sizeCategory'] as String?,
      stats: ShipStats.fromJson(json['stats'] as Map<String, dynamic>),
      roles: List<String>.from(json['roles'] as List),
      weapons: Weapons.fromJson(json['weapons'] as Map<String, dynamic>),
      abilities: _list(json['abilities'], Ability.fromJson),
      description: _optional(json['description'], ShipDescription.fromJson),
      research: _optional(json['research'], Research.fromJson),
      variants: _list(json['variants'], Variant.fromJson),
      showOnlyOn: _optional(json['showOnlyOn'], MonthDay.fromJson),
      icon: _icon(json['media']),
      credits: _optional(json['credits'], Credits.fromJson) ?? Credits.none,
      canon: _optional(json['canon'], Canon.fromJson),
      turntable: _turntable(json['media']),
      notableShips: _list(json['notableShips'], NotableShip.fromJson),
    );
  }

  /// Hull id from the mod, e.g. "fed_TNG_galaxy".
  final String id;
  final String era;
  final String faction;
  final String name;

  /// The build-menu subtitle, e.g. "Heavy Explorer".
  final String? subtitle;

  /// How the ship appears in the game: buildable, starting-fleet, keeper, special.
  final List<String> availability;

  /// The engine's class (Capital, Frigate, Corvette, Fighter, Utility, Platform...).
  /// The ship list groups by it.
  final String displayFamily;
  final String? sizeCategory;
  final ShipStats stats;
  final List<String> roles;
  final Weapons weapons;
  final List<Ability> abilities;
  final ShipDescription? description;
  final Research? research;
  final List<Variant> variants;

  /// When set, the ship is listed only on this day of the year.
  final MonthDay? showOnlyOn;

  /// Asset path of the game's icon, e.g. "assets/icons/TNG/fed_TNG_galaxy.webp";
  /// null when the mod has none (the game shows a generic icon for those).
  final String? icon;

  /// Who made the model and its textures (#425).
  final Credits credits;

  /// Where the class comes from (#423); null for structures with no class,
  /// such as shipyards and miners.
  final Canon? canon;

  /// The model turning, when it has been rendered (#491).
  final Turntable? turntable;

  /// Ships of the class the game names as they're built, in that order (#934).
  final List<NotableShip> notableShips;
}

/// A ship the game names, e.g. U.S.S. Excelsior, NCC-2000.
class NotableShip {
  const NotableShip({required this.name, this.registry});

  factory NotableShip.fromJson(Map<String, dynamic> json) => NotableShip(
    name: json['name'] as String,
    registry: json['registry'] as String?,
  );

  final String name;

  /// As painted on the hull; null where the game shows none.
  final String? registry;
}

/// A pre-rendered turn of a ship's model: [frames] cells of [frameWidth] by
/// [frameHeight] pixels in one sprite sheet, [columns] to a row.
class Turntable {
  const Turntable({
    required this.sheet,
    required this.frames,
    required this.columns,
    required this.frameWidth,
    required this.frameHeight,
  });

  factory Turntable.fromJson(Map<String, dynamic> json) {
    final frames = json['frames'] as int;
    return Turntable(
      sheet: json['sheet'] as String,
      frames: frames,
      columns: json['columns'] as int? ?? frames,
      frameWidth: json['frameWidth'] as int,
      frameHeight: json['frameHeight'] as int,
    );
  }

  final String sheet;
  final int frames;
  final int columns;
  final int frameWidth;
  final int frameHeight;
}

/// How firmly a class is sourced, best first.
enum CanonTier {
  /// Seen on screen; Memory Alpha.
  screen,

  /// Licensed books, games and comics; Memory Beta.
  licensed,

  /// Fan works and Star Trek Online; Memory Gamma or the STO wiki.
  fan,

  /// The mod's own design.
  none,
}

class Canon {
  const Canon({required this.tier, this.url, this.note});

  factory Canon.fromJson(Map<String, dynamic> json) => Canon(
    tier: switch (json['tier'] as String) {
      'A' => CanonTier.screen,
      'B' => CanonTier.licensed,
      'G' => CanonTier.fan,
      _ => CanonTier.none,
    },
    url: json['url'] as String?,
    note: json['note'] as String?,
  );

  final CanonTier tier;

  /// The wiki page for the class or vessel.
  final String? url;
  final String? note;
}

/// The model's makers, from the readmes in the mod's source files.
class Credits {
  const Credits({required this.authors, this.note, this.links = const {}});

  factory Credits.fromJson(Map<String, dynamic> json) => Credits(
    authors: List<String>.from(json['authors'] as List? ?? const []),
    note: json['note'] as String?,
    links: Map<String, String>.from(json['links'] as Map? ?? const {}),
  );

  static const none = Credits(authors: []);

  /// Each with their part, e.g. "Aad Moerman (model, textures)".
  final List<String> authors;

  /// Anything more the readme says, or why there are no names.
  final String? note;

  /// Authors' sites, by name: a credit line starting with the name links there.
  final Map<String, String> links;

  /// The site for a credit line, if its author has one.
  String? linkFor(String author) {
    for (final e in links.entries) {
      if (author.startsWith(e.key)) return e.value;
    }
    return null;
  }
}

/// Numbers straight from the mod. Any of them can be missing.
class ShipStats {
  const ShipStats({
    this.maxHealth,
    this.maxSpeed,
    this.buildCost,
    this.buildTime,
    this.length,
    this.width,
  });

  factory ShipStats.fromJson(Map<String, dynamic> json) => ShipStats(
    maxHealth: json['maxHealth'] as int?,
    maxSpeed: (json['maxSpeed'] as num?)?.toDouble(),
    buildCost: json['buildCost'] as int?,
    buildTime: (json['buildTime'] as num?)?.toDouble(),
    length: (json['length'] as num?)?.toDouble(),
    width: (json['width'] as num?)?.toDouble(),
  );

  final int? maxHealth;
  final double? maxSpeed;

  /// In RU.
  final int? buildCost;

  /// In seconds.
  final double? buildTime;
  final double? length;
  final double? width;

  /// These stats with any non-null value in [override] taking its place.
  ShipStats overriddenBy(ShipStats? override) {
    if (override == null) return this;
    return ShipStats(
      maxHealth: override.maxHealth ?? maxHealth,
      maxSpeed: override.maxSpeed ?? maxSpeed,
      buildCost: override.buildCost ?? buildCost,
      buildTime: override.buildTime ?? buildTime,
      length: override.length ?? length,
      width: override.width ?? width,
    );
  }
}

class Weapons {
  const Weapons({
    required this.total,
    required this.beam,
    required this.pulse,
    required this.torpedo,
    required this.other,
    this.details = const [],
    this.dps,
  });

  factory Weapons.fromJson(Map<String, dynamic> json) => Weapons(
    total: json['total'] as int,
    beam: json['beam'] as int,
    pulse: json['pulse'] as int,
    torpedo: json['torpedo'] as int,
    other: json['other'] as int? ?? 0,
    details: [
      for (final d in json['details'] as List? ?? const [])
        WeaponDetail.fromJson(d as Map<String, dynamic>),
    ],
    dps: (json['dps'] as num?)?.toDouble(),
  );

  final int total;
  final int beam;
  final int pulse;
  final int torpedo;
  final int other;

  /// One row per kind of weapon, with how many the ship mounts.
  final List<WeaponDetail> details;

  /// The ship's total damage per second, special attacks left out.
  final double? dps;
}

/// One kind of weapon on a ship, with its figures from the .wepn file.
class WeaponDetail {
  const WeaponDetail({
    required this.name,
    required this.kind,
    required this.count,
    this.damage,
    this.cycle,
    this.shotsPerCycle = 1,
    this.dps,
    this.range,
    this.special = false,
    this.disables = false,
    this.area = false,
  });

  factory WeaponDetail.fromJson(Map<String, dynamic> json) => WeaponDetail(
    name: json['name'] as String,
    kind: json['kind'] as String,
    count: json['count'] as int,
    damage: (json['damage'] as num?)?.toDouble(),
    cycle: (json['cycle'] as num?)?.toDouble(),
    shotsPerCycle: json['shotsPerCycle'] as int? ?? 1,
    dps: (json['dps'] as num?)?.toDouble(),
    range: (json['range'] as num?)?.toDouble(),
    special: json['special'] as bool? ?? false,
    disables: json['disables'] as bool? ?? false,
    area: json['area'] as bool? ?? false,
  );

  final String name;
  final String kind;
  final int count;

  /// Average damage of one hit.
  final double? damage;

  /// Seconds between shots, or between the starts of bursts.
  final double? cycle;
  final int shotsPerCycle;

  /// Damage per second of one mount.
  final double? dps;
  final double? range;
  final bool special;
  final bool disables;
  final bool area;
}

class Ability {
  const Ability({required this.id, required this.name, this.detail});

  factory Ability.fromJson(Map<String, dynamic> json) => Ability(
    id: json['id'] as String,
    name: json['name'] as String,
    detail: json['detail'] as String?,
  );

  final String id;
  final String name;
  final String? detail;
}

/// The build-list description, already split into its sections.
class ShipDescription {
  const ShipDescription({
    required this.lead,
    required this.crew,
    required this.armament,
    required this.defences,
    required this.prerequisites,
    required this.summary,
    required this.other,
  });

  factory ShipDescription.fromJson(Map<String, dynamic> json) =>
      ShipDescription(
        lead: json['lead'] as String?,
        crew: json['crew'] as int?,
        armament: List<String>.from(json['armament'] as List),
        defences: List<String>.from(json['defences'] as List),
        prerequisites: List<String>.from(json['prerequisites'] as List),
        summary: json['summary'] as String?,
        other: [
          for (final s in (json['other'] as List? ?? const []))
            (
              title: (s as Map<String, dynamic>)['title'] as String,
              items: List<String>.from(s['items'] as List),
            ),
        ],
      );

  final String? lead;

  /// 0 for unmanned craft; null when the description doesn't say.
  final int? crew;
  final List<String> armament;
  final List<String> defences;
  final List<String> prerequisites;
  final String? summary;

  /// Extra sections such as Subsystems or Air Wing.
  final List<({String title, List<String> items})> other;
}

/// RequiredResearch: any one of [anyOf] unlocks the ship.
class Research {
  const Research({required this.anyOf});

  factory Research.fromJson(Map<String, dynamic> json) =>
      Research(anyOf: _list(json['anyOf'], ResearchOption.fromJson));

  final List<ResearchOption> anyOf;

  /// True when every alternative is a tree the game grants at the start.
  bool get availableFromStart => anyOf.every((o) => o.startingTree != null);
}

class ResearchOption {
  const ResearchOption({required this.id, this.name, this.startingTree});

  factory ResearchOption.fromJson(Map<String, dynamic> json) => ResearchOption(
    id: json['id'] as String,
    name: json['name'] as String?,
    startingTree: json['startingTree'] as String?,
  );

  final String id;
  final String? name;

  /// "standard" or "flagship" when this is a tree granted at the start of a match.
  final String? startingTree;
}

/// Another version of a ship, shown with a toggle on its page. It records only
/// what differs from the parent ship.
class Variant {
  const Variant({
    required this.id,
    required this.label,
    required this.kind,
    this.hullId,
    this.subsystemId,
    this.description,
    this.baseLabel,
    this.stats,
    this.count,
    this.icon,
    this.turntable,
  });

  factory Variant.fromJson(Map<String, dynamic> json) => Variant(
    id: json['id'] as String,
    label: json['label'] as String,
    kind: json['kind'] as String,
    hullId: json['hullId'] as String?,
    subsystemId: json['subsystemId'] as String?,
    description: json['description'] as String?,
    baseLabel: json['baseLabel'] as String?,
    stats: _optional(json['stats'], ShipStats.fromJson),
    count: json['count'] as int?,
    icon: _icon(json['media']),
    turntable: _turntable(json['media']),
  );

  final String id;

  /// Text on the toggle, e.g. "Saucer".
  final String label;

  /// subsystem, separation, escort, refit or loadout.
  final String kind;
  final String? hullId;
  final String? subsystemId;
  final String? description;

  /// For a mode: the name of the ship's own state on the toggle ("Flight Mode"
  /// beside "Attack Mode"), shown instead of the ship's name.
  final String? baseLabel;

  /// Only the stats that differ from the parent.
  final ShipStats? stats;

  /// For escorts: how many travel with the ship.
  final int? count;

  /// The variant's own icon, when it differs from the parent's.
  final String? icon;

  /// The variant's own turntable, when its model differs from the parent's.
  final Turntable? turntable;
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) => [
  for (final item in (raw as List? ?? const []))
    parse(item as Map<String, dynamic>),
];

Turntable? _turntable(Object? media) => _optional(
  (media as Map<String, dynamic>?)?['turntable'],
  Turntable.fromJson,
);

String? _icon(Object? media) =>
    (media as Map<String, dynamic>?)?['icon'] as String?;

T? _optional<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
    raw == null ? null : parse(raw as Map<String, dynamic>);

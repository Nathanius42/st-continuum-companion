import '../ui/format.dart';
import 'models.dart';

/// A ship as shown with one of its variants selected (or none: the ship itself).
///
/// Variants only record what differs, so this merges the variant over its
/// parent for the screens.
class ShipView {
  const ShipView(this.ship, [this.variant]);

  final Ship ship;

  /// The selected variant; null for the ship itself.
  final Variant? variant;

  bool get isBase => variant == null;

  /// True when the variant is a hull of its own (separation part, escort,
  /// loadout). The data holds only its stats, not its weapons or abilities.
  /// A refit counts as the same ship even when the mod builds it as a separate
  /// hull (the TMP Ambassador's), so it keeps the ship's name like any refit.
  bool get isOtherHull => variant?.hullId != null && variant?.kind != 'refit';

  /// A variant that's a hull of its own is titled with its own name ("Saucer");
  /// a refit or subsystem is still the same ship, so it keeps the ship's name.
  String get title => isOtherHull ? variant!.label : ship.name;

  /// For a refit or subsystem: its label and what it does, e.g.
  /// "Sensor Suite: Refit into the Soyuz sub-class". Otherwise the variant's
  /// own text when it has one, or the ship's subtitle.
  String? get subtitle {
    final v = variant;
    if (v != null && !isOtherHull) {
      return v.description == null || v.description == v.label
          ? v.label
          : '${v.label}: ${v.description}';
    }
    return v?.description ?? ship.subtitle;
  }

  /// The variant's own icon if it has one, otherwise the ship's.
  String? get icon => variant?.icon ?? ship.icon;

  /// The variant's own turntable if it has one, otherwise the ship's (#616).
  Turntable? get turntable => variant?.turntable ?? ship.turntable;

  ShipStats get stats => ship.stats.overriddenBy(variant?.stats);

  /// Whether the selected variant changes [stat] from the ship's own value.
  bool changes(Object? Function(ShipStats s) stat) =>
      variant?.stats != null &&
      stat(variant!.stats!) != null &&
      stat(stats) != stat(ship.stats);
}

/// Text for the toggle that shows the ship itself, before its variants.
String baseToggleLabel(Ship ship) =>
    ship.variants.where((v) => v.baseLabel != null).firstOrNull?.baseLabel ??
    ship.name;

/// A short note on what kind of variant this is, for under the toggle.
String variantKindNote(Variant v) => switch (v.kind) {
  'separation' => 'Separated section',
  'escort' =>
    v.count != null && v.count! > 1
        ? 'Escort craft ×${v.count}'
        : 'Escort craft',
  'refit' => v.subsystemId != null ? 'Refit (built as a subsystem)' : 'Refit',
  'subsystem' => 'Subsystem fitted',
  'loadout' => 'Alternative version',
  'upgrade' => 'Research upgrade',
  'mode' => 'Combat stance',
  _ => v.kind,
};

/// How a ship appears in the game, for tags and filters.
String availabilityLabel(String a) => switch (a) {
  'buildable' => 'Buildable',
  'starting-fleet' => 'Starting fleet',
  'keeper' => 'Keeper',
  'special' => 'Special',
  _ => a,
};

/// The game's AI role, for filters: "AntiFrigate" → "Anti-frigate".
String roleLabel(String role) => switch (role) {
  'Generic' => 'General purpose',
  'Capture' => 'Capture',
  'Support' => 'Support',
  'Scout' => 'Scout',
  _ when role.startsWith('Anti') => 'Anti-${role.substring(4).toLowerCase()}',
  _ => role,
};

/// The game's size category, for filters: "SuperCapital" → "Super capital".
String sizeLabel(String size) =>
    size == 'SuperCapital' ? 'Super capital' : size;

/// The ship's class and size, "Frigate · Small"; once when they're the same
/// word ("Capital", not "Capital · Capital").
String classLabel(Ship ship) {
  final size = ship.sizeCategory;
  if (size == null || size == ship.displayFamily) return ship.displayFamily;
  return '${ship.displayFamily} · ${sizeLabel(size)}';
}

/// "676 damage a hit · every 5 s · 135 per second · range 5,500", with the
/// burst, the special attack, a disable or an area hit said where they apply.
String weaponFigures(WeaponDetail w) => [
  if (w.special) 'special attack',
  if (w.damage != null) '${thousands(w.damage!)} damage a hit',
  if (w.disables) 'disables the target',
  if (w.area) 'area blast',
  if (w.cycle != null)
    w.shotsPerCycle > 1
        ? '${w.shotsPerCycle} shots every ${seconds(w.cycle!)}'
        : 'every ${seconds(w.cycle!)}',
  if (w.dps != null) '${trimmed(w.dps!)} per second',
  if (w.range != null) 'range ${thousands(w.range!)}',
].join(' · ');

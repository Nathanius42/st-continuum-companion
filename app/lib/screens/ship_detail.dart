import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/search.dart';
import '../data/ship_view.dart';
import '../theme/dex_theme.dart';
import '../ui/format.dart';
import '../ui/lcars.dart';
import '../ui/open_link.dart';
import '../ui/ship_icon.dart';
import '../ui/turntable_view.dart';
import 'compare_screen.dart';
import 'front_page.dart';
import 'search_screen.dart';

/// A ship's page on its own screen, as on a phone.
class ShipDetailScreen extends StatelessWidget {
  const ShipDetailScreen({super.key, required this.ship});

  final Ship ship;

  @override
  Widget build(BuildContext context) {
    return DexThemeScope(
      era: ship.era,
      faction: ship.faction,
      child: Builder(
        builder: (context) {
          final data = FrontPageScope.maybeOf(context);
          return LcarsFrame(
            title: ship.name,
            // The back button returns to the list; the sidebar holds Compare.
            sidebarNav: [
              if (data != null)
                LcarsNavItem(
                  label: 'Compare',
                  onTap: () => startCompare(context, ship, data),
                ),
            ],
            footer: ship.subtitle,
            child: ShipDetail(ship: ship, showCompare: false),
          );
        },
      ),
    );
  }
}

/// The ship page (#487): turntable (#491), variant toggle (#605), stats,
/// research, description, notable ships, canon and credits.
class ShipDetail extends StatefulWidget {
  const ShipDetail({super.key, required this.ship, this.showCompare = true});

  final Ship ship;

  /// Whether the page carries its own Compare button; false where the
  /// screen's sidebar has it.
  final bool showCompare;

  @override
  State<ShipDetail> createState() => _ShipDetailState();
}

class _ShipDetailState extends State<ShipDetail> {
  /// The selected variant; null shows the ship itself.
  Variant? _variant;

  @override
  Widget build(BuildContext context) {
    final ship = widget.ship;
    final view = ShipView(ship, _variant);
    final theme = Theme.of(context);
    final dex = DexTheme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Center(
          child:
              dex.shape == DexShape.radial ||
                  dex.shape == DexShape.film ||
                  dex.shape == DexShape.elliptical
              ? CustomPaint(
                  // Film-era and Borg displays framed readouts in concentric rings;
                  // Cardassian ones in nested ellipses.
                  painter: _RingsPainter(
                    dex.data.first,
                    oval: dex.shape == DexShape.elliptical,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: _ShipImage(view: view, width: 300),
                  ),
                )
              : _ShipImage(view: view, width: 320),
        ),
        const SizedBox(height: 8),
        Text(
          view.title,
          style: dex
              .heading(theme.textTheme.headlineMedium)
              ?.copyWith(color: dex.highlight),
        ),
        if (view.subtitle != null)
          Text(
            view.subtitle!,
            style: theme.textTheme.titleMedium?.copyWith(
              color: dex.structureAt(1),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in ship.availability)
              _Tag(
                availabilityLabel(a),
                // A tag opens Search showing every ship with it.
                onTap: switch (FrontPageScope.maybeOf(context)) {
                  final data? => () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SearchScreen(
                        data: data,
                        initialQuery: ShipQuery(availability: {a}),
                      ),
                    ),
                  ),
                  null => null,
                },
              ),
          ],
        ),
        if (widget.showCompare)
          if (FrontPageScope.maybeOf(context) case final data?)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: 160,
                  child: LcarsButton(
                    label: 'Compare',
                    index: 3,
                    onPressed: () => startCompare(context, ship, data),
                  ),
                ),
              ),
            ),
        if (ship.variants.isNotEmpty) ...[
          // A carrier's variants are the craft it carries.
          LcarsSectionTitle(
            ship.variants.every((v) => v.kind == 'escort')
                ? 'Carrier and complement'
                : 'Variants',
          ),
          _VariantToggle(
            ship: ship,
            selected: _variant,
            onChanged: (v) => setState(() => _variant = v),
          ),
          if (_variant != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                variantKindNote(_variant!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: dex.data.first,
                ),
              ),
            ),
        ],
        const LcarsSectionTitle('Specifications'),
        _StatsPanel(view: view, game: false),
        const LcarsSectionTitle('Game specs'),
        _StatsPanel(view: view, game: true),
        if (view.isOtherHull)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Weapons, abilities and the description below are for the ${ship.name}.',
              style: theme.textTheme.bodySmall?.copyWith(color: dex.accent),
            ),
          ),
        // The summary leads, so the page opens with what the ship is for.
        if (ship.description?.summary != null) ...[
          const LcarsSectionTitle('Summary'),
          Text(ship.description!.summary!),
        ],
        // Armaments are the weapons with their figures, so the description's
        // own armament list only shows for a ship without any; defences
        // follow them.
        if (ship.weapons.total > 0) ...[
          const LcarsSectionTitle('Armaments'),
          Text(_weaponSummary(ship.weapons)),
          if (ship.weapons.details.isNotEmpty)
            _WeaponTable(weapons: ship.weapons),
        ] else if (ship.description?.armament.isNotEmpty ?? false) ...[
          const LcarsSectionTitle('Armaments'),
          for (final item in ship.description!.armament) Text('• $item'),
        ],
        if (ship.description?.defences.isNotEmpty ?? false) ...[
          const LcarsSectionTitle('Defences'),
          for (final item in ship.description!.defences) Text('• $item'),
        ],
        if (ship.research != null) ...[
          const LcarsSectionTitle('Research needed'),
          Text(_researchText(ship.research!)),
        ],
        if (ship.abilities.isNotEmpty) ...[
          const LcarsSectionTitle('Abilities'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in ship.abilities)
                Tooltip(message: a.detail ?? a.id, child: _Tag(a.name)),
            ],
          ),
        ],
        if (ship.description != null)
          ..._descriptionSections(ship.description!, ship),
        if (ship.notableShips.isNotEmpty) ...[
          const LcarsSectionTitle('Notable ships'),
          _NotableShips(ships: ship.notableShips),
        ],
        if (ship.canon != null) ...[
          const LcarsSectionTitle('Canon'),
          _CanonPanel(canon: ship.canon!),
        ],
        const LcarsSectionTitle('Credits'),
        for (final a in ship.credits.authors)
          if (ship.credits.linkFor(a) case final url?)
            _LinkText('• $a', url: url)
          else
            Text('• $a'),
        if (ship.credits.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _NoteWithLinks(
              ship.credits.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(
                  alpha: 0.75,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _descriptionSections(ShipDescription d, Ship ship) {
    final sections = <({String title, List<String> items})>[
      (title: 'Prerequisites', items: d.prerequisites),
      ...d.other,
    ];
    return [
      for (final s in sections)
        if (s.items.isNotEmpty) ...[
          LcarsSectionTitle(s.title),
          for (final item in s.items) Text('• $item'),
        ],
    ];
  }
}

/// One choice per variant, plus the ship itself first. Only one is shown at a
/// time: the mod's subsystem options exclude each other.
class _VariantToggle extends StatelessWidget {
  const _VariantToggle({
    required this.ship,
    required this.selected,
    required this.onChanged,
  });

  final Ship ship;
  final Variant? selected;
  final ValueChanged<Variant?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(baseToggleLabel(ship)),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final v in ship.variants)
          ChoiceChip(
            label: Text(
              v.count != null && v.count! > 1
                  ? '${v.label} ×${v.count}'
                  : v.label,
            ),
            selected: selected?.id == v.id,
            onSelected: (_) => onChanged(v),
          ),
      ],
    );
  }
}

/// Label and value tiles. Values the selected variant changes are highlighted.
/// One set of stat tiles: the ship's real-world measures, or (with [game])
/// the numbers that only matter in play.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.view, required this.game});

  final ShipView view;
  final bool game;

  @override
  Widget build(BuildContext context) {
    final s = view.stats;
    final ship = view.ship;
    final tiles = <(String, String?, bool)>[
      if (game) ...[
        (
          'Hull',
          s.maxHealth == null ? null : thousands(s.maxHealth!),
          view.changes((x) => x.maxHealth),
        ),
        (
          'Speed',
          s.maxSpeed == null ? null : trimmed(s.maxSpeed!),
          view.changes((x) => x.maxSpeed),
        ),
        (
          'Cost',
          s.buildCost == null ? null : '${thousands(s.buildCost!)} RU',
          view.changes((x) => x.buildCost),
        ),
        (
          'Build time',
          s.buildTime == null ? null : duration(s.buildTime!),
          view.changes((x) => x.buildTime),
        ),
      ] else ...[
        (
          'Length',
          s.length == null ? null : trimmed(s.length!),
          view.changes((x) => x.length),
        ),
        (
          'Width',
          s.width == null ? null : trimmed(s.width!),
          view.changes((x) => x.width),
        ),
        if (view.isBase && ship.description?.crew != null)
          (
            'Crew',
            ship.description!.crew == 0
                ? 'Unmanned'
                : thousands(ship.description!.crew!),
            false,
          ),
        ('Class', classLabel(ship), false),
      ],
    ];
    // As many columns as fit at about 150 px each, never fewer than two, so a
    // phone shows the specifications two to a row.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = ((constraints.maxWidth + gap) / (150 + gap))
            .floor()
            .clamp(2, 8);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value, changed) in tiles)
              _StatTile(
                label: label,
                value: value ?? 'Unknown',
                changed: changed,
                width: width,
              ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.changed,
    required this.width,
  });

  final String label;
  final String value;
  final bool changed;
  final double width;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dex = DexTheme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: _tile(dex, text),
    );
  }

  Widget _tile(DexTheme dex, TextTheme text) {
    return AnimatedContainer(
      duration: dex.transition,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: changed ? dex.highlight : dex.data.first,
            width: 6,
          ),
        ),
        color: Color.alphaBlend(
          dex.data.first.withValues(alpha: 0.08),
          dex.background,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: dex
                .heading(text.labelSmall)
                ?.copyWith(color: dex.data.first, letterSpacing: 1.2),
          ),
          Text(
            value,
            style: text.titleMedium?.copyWith(
              color: changed ? dex.highlight : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.colour, {this.oval = false});

  final Color colour;

  /// Nested ellipses (Cardassian) instead of rings with ticks (film era).
  final bool oval;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.height / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = colour.withValues(alpha: 0.5);
    if (oval) {
      for (final (f, w) in [(1.0, 2.0), (0.8, 1.0), (0.6, 1.0)]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: centre,
            width: size.width * 0.9 * f,
            height: size.height * f,
          ),
          ring..strokeWidth = w,
        );
      }
      return;
    }
    for (final (f, w) in [(1.0, 2.0), (0.82, 1.0), (0.64, 1.0)]) {
      canvas.drawCircle(centre, r * f, ring..strokeWidth = w);
    }
    // Tick marks round the outer ring, as on the film-era tactical displays.
    final tick = Paint()
      ..color = colour.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    for (var i = 0; i < 24; i++) {
      final a = i * 3.14159265 / 12;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        centre + dir * r,
        centre + dir * (r - (i % 6 == 0 ? 10 : 5)),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.colour != colour || old.oval != oval;
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.onTap});

  final String text;

  /// Opens the ships that share the tag; null keeps it a plain label.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dex = DexTheme.of(context);
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: dex.accent,
        shape: endShape(dex.shape, 24, left: true, right: true),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: dex.textOnAccent),
      ),
    );
    if (onTap == null) return tag;
    return Semantics(
      button: true,
      label: '$text, shows every $text ship',
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: 'Show every $text ship',
        child: InkWell(
          onTap: onTap,
          customBorder: endShape(dex.shape, 24, left: true, right: true),
          child: tag,
        ),
      ),
    );
  }
}

/// "8 weapons: 6 beam, 2 torpedo".
String _weaponSummary(Weapons w) {
  final kinds = [
    if (w.beam > 0) '${w.beam} beam',
    if (w.pulse > 0) '${w.pulse} pulse',
    if (w.torpedo > 0) '${w.torpedo} torpedo',
    if (w.other > 0) '${w.other} other',
  ];
  return '${w.total} weapon${w.total == 1 ? '' : 's'}: ${kinds.join(', ')}';
}

/// Each kind of weapon with its figures, then the ship's total damage per
/// second. One row per weapon rather than a grid, so it reads on a phone.
class _WeaponTable extends StatelessWidget {
  const _WeaponTable({required this.weapons});

  final Weapons weapons;

  @override
  Widget build(BuildContext context) {
    final dex = DexTheme.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(
      color: text.bodySmall?.color?.withValues(alpha: 0.8),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in weapons.details)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 36,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  color: dex.accent,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${w.count} × ${w.name}', style: text.titleSmall),
                      Text(weaponFigures(w), style: small),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (weapons.dps != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Total: ${thousands(weapons.dps!)} damage per second'
              '${weapons.details.any((w) => w.special) ? ', special attacks left out' : ''}',
              style: text.titleSmall?.copyWith(color: dex.accent),
            ),
          ),
      ],
    );
  }
}

/// "Capital Sized Chassis, or Capital Sized Reinforcements in flagship modes",
/// or "Available from the start".
String _researchText(Research r) {
  if (r.availableFromStart) return 'Available from the start';
  final parts = [
    for (final o in r.anyOf)
      if (o.startingTree == 'flagship')
        'available from the start in flagship modes'
      else if (o.startingTree != null)
        'available from the start'
      else
        o.name ?? o.id,
  ];
  // Standard and flagship research sometimes share a name; say it once.
  return parts.toSet().join(', or ');
}

/// Where the class comes from: the tier in words, the note, and a link to the
/// wiki page.
class _CanonPanel extends StatelessWidget {
  const _CanonPanel({required this.canon});

  final Canon canon;

  static String _tierText(CanonTier tier) => switch (tier) {
    CanonTier.screen => 'Seen on screen',
    CanonTier.licensed => 'From licensed books, games or comics',
    CanonTier.fan => 'From fan works or Star Trek Online',
    CanonTier.none => "The mod's own design",
  };

  static String _site(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.startsWith('memory-alpha')) return 'Memory Alpha';
    if (host.startsWith('memory-beta')) return 'Memory Beta';
    if (host.startsWith('memory-gamma')) return 'Memory Gamma';
    if (host.contains('stowiki')) return 'the STO wiki';
    return host;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = canon.url;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_tierText(canon.tier), style: theme.textTheme.titleSmall),
        if (canon.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(canon.note!),
          ),
        if (url != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('Read on ${_site(url)}'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (!await openLink(url)) {
                  messenger.showSnackBar(
                    SnackBar(content: SelectableText(url)),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}

/// The ship turning when it has been rendered (#491), otherwise its game icon.
class _ShipImage extends StatelessWidget {
  const _ShipImage({required this.view, required this.width});

  final ShipView view;
  final double width;

  @override
  Widget build(BuildContext context) {
    final icon = ShipIcon(path: view.icon, name: view.title, width: width);
    final turntable = view.turntable;
    if (turntable == null) return icon;
    return TurntableView(
      // A new state per sheet, so a variant's turn starts from the front.
      key: ValueKey(turntable.sheet),
      turntable: turntable,
      name: view.title,
      width: width,
      fallback: icon,
    );
  }
}

/// The class's named ships, name over registry, flowing into as many columns
/// as the width allows.
class _NotableShips extends StatelessWidget {
  const _NotableShips({required this.ships});

  final List<NotableShip> ships;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dex = DexTheme.of(context);
    // At least two columns, even on a phone, to save scrolling.
    return LayoutBuilder(
      builder: (context, c) {
        final columns = math.max(2, (c.maxWidth / 200).floor());
        final width = (c.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in ships)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: theme.textTheme.bodyMedium),
                    if (s.registry != null)
                      Text(
                        s.registry!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dex.data.first,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Text that opens a link: underlined in the data colour, a link for screen
/// readers.
class _LinkText extends StatelessWidget {
  const _LinkText(this.text, {required this.url, this.style});

  final String text;
  final String url;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final dex = DexTheme.of(context);
    return Semantics(
      link: true,
      label: text,
      onTap: () => openLink(url),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openLink(url),
        child: Text(
          text,
          style: (style ?? DefaultTextStyle.of(context).style).copyWith(
            color: dex.data.first,
            decoration: TextDecoration.underline,
            decorationColor: dex.data.first,
          ),
        ),
      ),
    );
  }
}

/// A credit note with any web addresses in it as links (a Sketchfab source).
class _NoteWithLinks extends StatelessWidget {
  const _NoteWithLinks(this.note, {this.style});

  final String note;
  final TextStyle? style;

  static final _url = RegExp(r'https?://[^\s)]+');

  @override
  Widget build(BuildContext context) {
    final matches = _url.allMatches(note).toList();
    if (matches.isEmpty) return Text(note, style: style);
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in matches) {
      spans
        ..add(TextSpan(text: note.substring(at, m.start)))
        ..add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _LinkText(m.group(0)!, url: m.group(0)!, style: style),
          ),
        );
      at = m.end;
    }
    spans.add(TextSpan(text: note.substring(at)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/dex_theme.dart';
import '../ui/lcars_display.dart';
import '../ui/sound.dart';
import '../ui/territory_map.dart';
import 'front_page.dart';
import 'ship_browser_screen.dart';

/// Factions (#941) on a tactical cartography display (DS9 "Apocalypse Rising"):
/// the eras as buttons along the top change the galaxy chart, its powers pick
/// a faction, and the fleet evaluation beside it gives that faction's ships in
/// the era, with the button that opens them. On a phone the evaluation sits under
/// the chart.
class FactionsScreen extends StatefulWidget {
  const FactionsScreen({super.key, required this.data});

  final FrontPageData data;

  @override
  State<FactionsScreen> createState() => _FactionsScreenState();
}

class _FactionsScreenState extends State<FactionsScreen> {
  late String _era = widget.data.repository.eras.last.id;
  String? _faction = 'federation';

  @override
  Widget build(BuildContext context) {
    final repository = widget.data.repository;
    final present = repository.factionsIn(_era);
    final mapped = [
      for (final f in present)
        if (powers.containsKey(f.id)) (id: f.id, name: f.name),
    ];
    final others = [
      for (final f in present)
        if (!powers.containsKey(f.id)) f,
    ];
    final selected = present.any((f) => f.id == _faction)
        ? _faction
        : present.firstOrNull?.id;
    final narrow = MediaQuery.sizeOf(context).width < LcarsDisplay.narrowWidth;

    final map = TerritoryMap(
      era: _era,
      factions: mapped,
      selected: selected,
      onSelect: (id) => setState(() => _faction = id),
    );
    final evaluation = selected == null
        ? const SizedBox.shrink()
        : _FleetEvaluation(
            data: widget.data,
            era: _era,
            faction: present.firstWhere((f) => f.id == selected),
          );
    final unaligned = [
      for (final f in others)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            width: 200,
            child: LcarsPill(
              label: f.name,
              colour: f.id == selected
                  ? LcarsColours.orange
                  : LcarsColours.lilac,
              height: 40,
              onTap: () => setState(() => _faction = f.id),
            ),
          ),
        ),
    ];

    return DexThemeScope(
      child: LcarsDisplay(
        title: 'Tactical Cartography',
        topHeight: narrow ? 150 : 150,
        top: _EraButtons(
          eras: [for (final e in repository.eras) (id: e.id, year: e.year)],
          selected: _era,
          onSelect: (id) => setState(() => _era = id),
        ),
        sidebar: sectionItems(context, widget.data, current: Section.factions),
        panel: narrow
            ? null
            : LcarsPanel(
                width: 340,
                column: const [
                  LcarsItem(label: 'Fleet eval', colour: LcarsColours.gold),
                  LcarsItem(label: '7347', colour: LcarsColours.periwinkle),
                  LcarsItem(label: 'Mode', colour: LcarsColours.lilac, flex: 2),
                ],
                child: SingleChildScrollView(child: evaluation),
              ),
        child: narrow
            ? ListView(
                padding: EdgeInsets.zero,
                children: [
                  AspectRatio(aspectRatio: 1.05, child: map),
                  ...unaligned,
                  const SizedBox(height: 16),
                  Container(height: 8, color: LcarsColours.gold),
                  const SizedBox(height: 10),
                  evaluation,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: map),
                  Wrap(spacing: 10, children: unaligned),
                ],
              ),
      ),
    );
  }
}

/// The eras as pills along the top: the one shown is lit.
class _EraButtons extends StatelessWidget {
  const _EraButtons({
    required this.eras,
    required this.selected,
    required this.onSelect,
  });

  final List<({String id, int year})> eras;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final e in eras)
            SizedBox(
              width: 120,
              child: LcarsPill(
                label: '${e.id} ${e.year}',
                semanticLabel: e.id == selected
                    ? '${e.id}, ${e.year}, shown'
                    : 'Show ${e.id}, ${e.year}',
                colour: e.id == selected
                    ? LcarsColours.orange
                    : LcarsColours.periwinkle,
                height: 44,
                beep: Beep.select,
                onTap: () => onSelect(e.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// The selected faction in the era: how many ships, of which classes, and the
/// button that opens them.
class _FleetEvaluation extends StatelessWidget {
  const _FleetEvaluation({
    required this.data,
    required this.era,
    required this.faction,
  });

  final FrontPageData data;
  final String era;
  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final repository = data.repository;
    final font = DexTheme.of(context).headingFont;
    final groups = repository.shipsByClass(era, faction.id);
    final count = groups.fold<int>(0, (n, g) => n + g.ships.length);
    final colour = powers[faction.id]?.colour ?? LcarsColours.lilac;
    TextStyle style(double size, Color c) => TextStyle(
      fontFamily: font,
      fontSize: size,
      color: c,
      height: 1.2,
      letterSpacing: 0.8,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (homeworldScene(faction.id, era) case final scene?)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Homeworld(asset: scene, name: faction.name, colour: colour),
          ),
        Semantics(
          header: true,
          child: Text(faction.name.toUpperCase(), style: style(30, colour)),
        ),
        // The name in the faction's own script, as decoration only.
        if (ThemeLibraryScope.of(context)
                .resolve(era: era, faction: faction.id)
                .scriptFont
            case final script?)
          ExcludeSemantics(
            child: Text(
              faction.name.toUpperCase(),
              style: TextStyle(
                fontFamily: script,
                fontSize: 22,
                color: colour.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
          ),
        Text(
          '${repository.era(era).title} · ${repository.era(era).year}'
              .toUpperCase(),
          style: style(17, LcarsColours.periwinkle),
        ),
        if (data.content.factionBlurb(faction.id, era) case final blurb?)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              blurb.toUpperCase(),
              style: style(16, LcarsColours.lavender).copyWith(height: 1.35),
            ),
          ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'FLEET: ',
                style: style(20, LcarsColours.periwinkle),
              ),
              TextSpan(
                text:
                    '$count ${count == 1 ? 'SHIP' : 'SHIPS'} IN '
                    '${groups.length} ${groups.length == 1 ? 'CLASS' : 'CLASSES'}',
                style: style(20, LcarsColours.orange),
              ),
            ],
          ),
        ),
        if (!faction.playable)
          Text('NON-PLAYABLE', style: style(17, LcarsColours.coral)),
        const SizedBox(height: 12),
        SizedBox(
          width: 260,
          child: LcarsPill(
            label: 'Open fleet records',
            semanticLabel:
                'Open the ${faction.name} ships of ${repository.era(era).title}',
            colour: LcarsColours.orange,
            height: 48,
            beep: Beep.processing,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShipBrowserScreen(
                  repository: repository,
                  eraId: era,
                  factionId: faction.id,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 8),
        for (final g in groups)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${g.family.toUpperCase()}: ',
                  style: style(17, LcarsColours.periwinkle),
                ),
                TextSpan(
                  text: '${g.ships.length}',
                  style: style(17, LcarsColours.orange),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// The factions whose homeworld changes across the eras, with a scene for each.
const _scenesByEra = {'federation', 'klingon', 'romulan'};

/// The factions with one homeworld scene for every era.
const _scenes = {
  'gorn',
  'tholian',
  'terran',
  'cardassian',
  'dominion',
  'borg',
  'voth',
  'ferengi',
  'breen',
  'undine',
};

/// A faction's homeworld scene for [era], or null when it has none (Unaligned).
/// The scenes are the Dex's own, after SFC2's empire cityscapes.
String? homeworldScene(String faction, String era) {
  if (_scenesByEra.contains(faction)) {
    return 'assets/factions/${faction}_$era.webp';
  }
  return _scenes.contains(faction) ? 'assets/factions/$faction.webp' : null;
}

/// The homeworld scene, framed as a personnel file frames its photograph.
class _Homeworld extends StatelessWidget {
  const _Homeworld({
    required this.asset,
    required this.name,
    required this.colour,
  });

  final String asset;
  final String name;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$name homeworld',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 768 / 597,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colour, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

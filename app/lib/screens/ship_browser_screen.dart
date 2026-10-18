import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/ship_repository.dart';
import '../theme/dex_theme.dart';
import '../ui/faction_logo.dart';
import '../ui/lcars.dart';
import '../ui/ship_icon.dart';
import 'compare_screen.dart';
import 'front_page.dart';
import 'ship_detail.dart';

/// Window width at and above which the ship list and the ship page sit side by
/// side (#542). Below it, as on a phone, tapping a ship opens its page.
/// Measured on the window rather than the frame's content area, so the
/// sidebar's width doesn't move the breakpoint.
const wideLayoutWidth = 840.0;

/// A faction's ships in one era: the list (#484) and, in a wide window, the
/// selected ship's page beside it.
class ShipBrowserScreen extends StatefulWidget {
  const ShipBrowserScreen({
    super.key,
    required this.repository,
    required this.eraId,
    required this.factionId,
  });

  final ShipRepository repository;
  final String eraId;
  final String factionId;

  @override
  State<ShipBrowserScreen> createState() => _ShipBrowserScreenState();
}

class _ShipBrowserScreenState extends State<ShipBrowserScreen> {
  /// The ship shown beside the list in the wide layout.
  Ship? _selected;

  @override
  Widget build(BuildContext context) {
    final faction = widget.repository.faction(widget.factionId);
    final groups = widget.repository.shipsByClass(
      widget.eraId,
      widget.factionId,
    );

    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final selected = _selected ?? (wide ? groups.first.ships.first : null);
    final list = ShipList(
      groups: groups,
      selectedId: wide ? selected?.id : null,
      onTap: (ship) {
        if (wide) {
          setState(() => _selected = ship);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShipDetailScreen(ship: ship),
            ),
          );
        }
      },
    );
    final count = groups.fold<int>(0, (n, g) => n + g.ships.length);

    return DexThemeScope(
      era: widget.eraId,
      faction: widget.factionId,
      child: LcarsFrame(
        title: faction.name,
        // The era's factions, so another faction is one tap away.
        sidebarNav: [
          for (final f in widget.repository.factionsIn(widget.eraId))
            LcarsNavItem(
              label: f.name,
              selected: f.id == widget.factionId,
              icon: (size) => FactionLogo(
                path: f.logoFor(widget.eraId),
                name: f.name,
                size: size,
              ),
              onTap: () => replaceWithSibling(
                context,
                (_) => ShipBrowserScreen(
                  repository: widget.repository,
                  eraId: widget.eraId,
                  factionId: f.id,
                ),
              ),
            ),
          // With a ship's page beside the list, Compare is in the sidebar.
          if (wide && selected != null)
            if (FrontPageScope.maybeOf(context) case final data?)
              LcarsNavItem(
                label: 'Compare',
                onTap: () => startCompare(context, selected, data),
              ),
        ],
        footer: wide && selected != null ? selected.name : '$count entries',
        child: !wide
            ? list
            : Builder(
                builder: (context) => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 340, child: list),
                    VerticalDivider(
                      width: 24,
                      color: DexTheme.of(context).data.first
                          .withValues(alpha: 0.4),
                    ),
                    Expanded(
                      // A new key per ship resets the variant toggle when the ship changes.
                      child: ShipDetail(
                        key: ValueKey(selected!.id),
                        ship: selected,
                        showCompare: false,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Ships grouped by class, with name, subtitle and how each appears in game.
class ShipList extends StatelessWidget {
  const ShipList({
    super.key,
    required this.groups,
    required this.onTap,
    this.selectedId,
  });

  final List<({String family, List<Ship> ships})> groups;
  final ValueChanged<Ship> onTap;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    // Headings and ships in one flat list, built as they scroll into view.
    final rows = <Object>[
      for (final group in groups) ...[group.family, ...group.ships],
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) => switch (rows[i]) {
        final String family => LcarsSectionTitle(family),
        final Ship ship => ListTile(
          selected: ship.id == selectedId,
          leading: ShipIcon(path: ship.icon, name: ship.name),
          title: Text(ship.name),
          subtitle: ship.subtitle == null ? null : Text(ship.subtitle!),
          trailing: ship.variants.isEmpty
              ? null
              : Tooltip(
                  message:
                      '${ship.variants.length} variant${ship.variants.length == 1 ? '' : 's'}',
                  child: Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color: DexTheme.of(context).data.first,
                  ),
                ),
          onTap: () => onTap(ship),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

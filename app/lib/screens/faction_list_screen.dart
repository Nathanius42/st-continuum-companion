import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/ship_repository.dart';
import '../theme/dex_theme.dart';
import '../ui/faction_logo.dart';
import '../ui/lcars.dart';
import 'ship_browser_screen.dart';

/// The factions present in one era (#482), in that era's theme. Each button
/// takes its faction's accent. Logos come with the faction art (#442).
class FactionListScreen extends StatelessWidget {
  const FactionListScreen({
    super.key,
    required this.repository,
    required this.eraId,
  });

  final ShipRepository repository;
  final String eraId;

  @override
  Widget build(BuildContext context) {
    final era = repository.era(eraId);
    final factions = repository.factionsIn(eraId);
    final eraTheme = ThemeLibraryScope.of(context).resolve(era: eraId);
    return DexThemeScope(
      era: eraId,
      child: LcarsFrame(
        title: era.title,
        // The eras, so another era is one tap away.
        sidebarNav: [
          for (final e in repository.eras)
            LcarsNavItem(
              label: e.id,
              selected: e.id == eraId,
              onTap: () => replaceWithSibling(
                context,
                (_) => FactionListScreen(repository: repository, eraId: e.id),
              ),
            ),
        ],
        footer: 'Select a faction',
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final faction in factions) ...[
              DexThemeScope(
                era: eraId,
                faction: faction.id,
                child: Builder(
                  builder: (context) {
                    final theme = DexTheme.of(context);
                    // A faction with an interface of its own shows its main
                    // frame colour (Klingon red-orange, Romulan cyan); the
                    // others share the era's frame, so they show their accent.
                    final colour =
                        listEquals(theme.structure, eraTheme.structure)
                        ? theme.accent
                        : theme.structureAt(0);
                    return LcarsButton(
                      label: faction.name,
                      leading: FactionLogo(
                        path: faction.logoFor(eraId),
                        name: faction.name,
                        size: 36,
                      ),
                      caption: faction.playable ? null : 'Non-playable',
                      colour: faction.playable
                          ? colour
                          : colour.withValues(alpha: 0.55),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ShipBrowserScreen(
                            repository: repository,
                            eraId: eraId,
                            factionId: faction.id,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

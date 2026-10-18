import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/search.dart';
import '../data/ship_repository.dart';
import '../data/ship_view.dart';
import '../theme/dex_theme.dart';
import '../ui/lcars_display.dart';
import '../ui/ship_icon.dart';
import '../ui/sound.dart';
import 'front_page.dart';
import 'ship_detail.dart';

/// Search and filters across every era (#495), on a TNG command display: the
/// search box and its buttons in the top section, the results below, and the
/// filters in the framed panel on the right, one category at a time, chosen
/// from the panel's column. On a phone the panel is just its column, and a
/// category's options open over the results. In a wide window the selected
/// ship's page sits beside the results, in its own era's look.
///
/// [onPick], when given, turns the screen into a picker: tapping a ship hands it
/// back instead of opening it (Compare uses this).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.data,
    this.onPick,
    this.title = 'Search',
  });

  final FrontPageData data;
  final ValueChanged<Ship>? onPick;
  final String title;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

/// A filter category: its options, which are chosen, and how to apply a choice.
class _Category {
  const _Category({
    required this.title,
    required this.values,
    required this.chosen,
    required this.label,
    required this.apply,
  });

  final String title;
  final List<String> values;
  final Set<String> chosen;
  final String Function(String) label;
  final ShipQuery Function(Set<String>) apply;
}

List<_Category> _categories(ShipRepository repository, ShipQuery query) {
  final ships = repository.visibleShips().toList();
  final families = {for (final s in ships) familyOf(s)}.toList()
    ..sort((a, b) {
      final ia = familyOrder.indexOf(a), ib = familyOrder.indexOf(b);
      return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
    });
  const roleOrder = [
    'AntiFighter',
    'AntiCorvette',
    'AntiFrigate',
    'AntiCapital',
    'Support',
    'Capture',
    'Scout',
    'Generic',
  ];
  final roles = {for (final s in ships) ...s.roles}.toList()
    ..sort((a, b) => roleOrder.indexOf(a).compareTo(roleOrder.indexOf(b)));
  const sizes = ['Tiny', 'Small', 'Medium', 'Capital', 'SuperCapital'];
  return [
    _Category(
      title: 'Era',
      values: [for (final e in repository.eras) e.id],
      chosen: query.eras,
      label: (id) => '$id · ${repository.era(id).year}',
      apply: (s) => query.copyWith(eras: s),
    ),
    _Category(
      title: 'Faction',
      values: [
        for (final f in repository.data.factions)
          if (ships.any((s) => s.faction == f.id)) f.id,
      ],
      chosen: query.factions,
      label: (id) => repository.faction(id).name,
      apply: (s) => query.copyWith(factions: s),
    ),
    _Category(
      title: 'Class',
      values: families,
      chosen: query.families,
      label: (f) => f,
      apply: (s) => query.copyWith(families: s),
    ),
    _Category(
      title: 'Role',
      values: roles,
      chosen: query.roles,
      label: roleLabel,
      apply: (s) => query.copyWith(roles: s),
    ),
    _Category(
      title: 'Size',
      values: [
        for (final z in sizes)
          if (ships.any((s) => s.sizeCategory == z)) z,
      ],
      chosen: query.sizes,
      label: sizeLabel,
      apply: (s) => query.copyWith(sizes: s),
    ),
    _Category(
      title: 'In game',
      values: const ['buildable', 'starting-fleet', 'keeper', 'special'],
      chosen: query.availability,
      label: availabilityLabel,
      apply: (s) => query.copyWith(availability: s),
    ),
  ];
}

class _SearchScreenState extends State<SearchScreen> {
  final _text = TextEditingController();
  ShipQuery _query = const ShipQuery();
  Ship? _selected;

  /// The filter category shown in the panel.
  int _category = 0;

  /// On a phone: whether the category's options are open over the results.
  bool _filtersOpen = false;

  ShipRepository get _repo => widget.data.repository;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _open(Ship ship, bool beside) {
    if (widget.onPick != null) {
      widget.onPick!(ship);
    } else if (beside) {
      setState(() => _selected = ship);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ShipDetailScreen(ship: ship)),
      );
    }
  }

  void _clear() => setState(() {
    _text.clear();
    _query = const ShipQuery();
  });

  static const _columnColours = [
    LcarsColours.coral,
    LcarsColours.lilac,
    LcarsColours.periwinkle,
    LcarsColours.gold,
    LcarsColours.coral,
    LcarsColours.lilac,
  ];

  @override
  Widget build(BuildContext context) {
    final hits = searchShips(_repo, _query);
    final total = _repo.visibleShips().length;
    final narrow = MediaQuery.sizeOf(context).width < LcarsDisplay.narrowWidth;
    final categories = _categories(_repo, _query);
    final category = categories[_category];

    final column = [
      for (final (i, c) in categories.indexed)
        LcarsItem(
          label: c.chosen.isEmpty ? c.title : '${c.title} ${c.chosen.length}',
          semanticLabel: c.chosen.isEmpty
              ? '${c.title} filter'
              : '${c.title} filter, ${c.chosen.length} set',
          colour: narrow && _filtersOpen && i == _category
              ? LcarsColours.orange
              : _columnColours[i % _columnColours.length],
          selected: !narrow && i == _category,
          onTap: () => setState(() {
            if (narrow) {
              _filtersOpen = !(_filtersOpen && i == _category);
            }
            _category = i;
          }),
        ),
    ];

    final options = _FilterOptions(
      category: category,
      onChanged: (s) => setState(() => _query = category.apply(s)),
      onDone: narrow ? () => setState(() => _filtersOpen = false) : null,
    );

    return DexThemeScope(
      child: LcarsDisplay(
        title: widget.title,
        // Taller for large text, so the search box and buttons still fit.
        topHeight:
            (narrow ? 172 : 196) +
            60 * (MediaQuery.textScalerOf(context).scale(20) / 20 - 1),
        top: _SearchTop(
          controller: _text,
          shown: hits.length,
          total: total,
          filters: _query.filterCount,
          onChanged: (t) => setState(() => _query = _query.copyWith(text: t)),
          onClear: _query.isEmpty ? null : _clear,
        ),
        sidebar: widget.onPick != null
            ? const [
                LcarsItem(label: 'Compare', colour: LcarsColours.periwinkle),
                LcarsItem(label: 'Select', colour: LcarsColours.gold),
              ]
            : sectionItems(context, widget.data, current: Section.search),
        panel: LcarsPanel(column: column, child: options, width: 360),
        child: LayoutBuilder(
          builder: (context, c) {
            final beside = widget.onPick == null && c.maxWidth >= 760;
            final selected = beside
                ? (hits.any((h) => h.ship == _selected)
                      ? _selected
                      : hits.firstOrNull?.ship)
                : null;
            final results = hits.isEmpty
                ? Center(
                    child: Text(
                      'NO MATCHING RECORDS',
                      style: TextStyle(
                        fontFamily: DexTheme.of(context).headingFont,
                        fontSize: 24,
                        color: LcarsColours.coral,
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      _Results(
                        hits: hits,
                        repository: _repo,
                        selectedId: selected?.id,
                        onTap: (s) => _open(s, beside),
                      ),
                    ],
                  );
            final body = selected == null
                ? results
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 330, child: results),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DexThemeScope(
                          era: selected.era,
                          faction: selected.faction,
                          child: ShipDetail(
                            key: ValueKey('${selected.era}/${selected.id}'),
                            ship: selected,
                          ),
                        ),
                      ),
                    ],
                  );
            if (!narrow || !_filtersOpen) return body;
            return Stack(
              children: [
                body,
                Positioned.fill(child: _FilterSheet(child: options)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The top section: the search box, then CLEAR and the count of matches.
class _SearchTop extends StatelessWidget {
  const _SearchTop({
    required this.controller,
    required this.shown,
    required this.total,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final int shown;
  final int total;
  final int filters;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final font = DexTheme.of(context).headingFont;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: LcarsColours.periwinkle, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Name, class, ship or registry',
              prefixIcon: const Icon(
                Icons.search,
                color: LcarsColours.periwinkle,
              ),
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(
                  color: LcarsColours.orange,
                  width: 2,
                ),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 150,
              child: LcarsPill(
                label: 'Clear',
                semanticLabel: 'Clear the search and filters',
                colour: LcarsColours.orange,
                onTap: onClear,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$shown OF $total ENTRIES'
                  '${filters == 0 ? '' : ' · $filters FILTER${filters == 1 ? '' : 'S'}'}',
                  style: TextStyle(
                    fontFamily: font,
                    color: LcarsColours.lavender,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One filter category's options as LCARS pills, chosen or not.
class _FilterOptions extends StatelessWidget {
  const _FilterOptions({
    required this.category,
    required this.onChanged,
    this.onDone,
  });

  final _Category category;
  final ValueChanged<Set<String>> onChanged;

  /// On a phone: closes the options.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final font = DexTheme.of(context).headingFont;
    final chosen = category.chosen;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '${category.title} filter'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: font,
                    color: LcarsColours.periwinkle,
                    fontSize: 24,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            if (chosen.isNotEmpty)
              SizedBox(
                width: 110,
                child: LcarsPill(
                  label: 'None',
                  semanticLabel: 'Clear the ${category.title} filter',
                  colour: LcarsColours.coral,
                  height: 36,
                  onTap: () => onChanged(<String>{}),
                ),
              ),
            if (onDone != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: LcarsPill(
                  label: 'Done',
                  colour: LcarsColours.orange,
                  height: 36,
                  onTap: onDone,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in category.values)
              _OptionPill(
                label: category.label(v),
                chosen: chosen.contains(v),
                onTap: () => onChanged(
                  chosen.contains(v)
                      ? ({...chosen}..remove(v))
                      : {...chosen, v},
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// An option: an outlined pill, filled in orange when chosen.
class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final font = DexTheme.of(context).headingFont;
    return Semantics(
      button: true,
      selected: chosen,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: chosen ? LcarsColours.orange : Colors.black,
        shape: StadiumBorder(
          side: BorderSide(
            color: chosen ? LcarsColours.orange : LcarsColours.lilac,
            width: 2,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            Sounds.play(Beep.tap);
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: font,
                fontSize: 18,
                letterSpacing: 1,
                color: chosen ? Colors.black : LcarsColours.lilac,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// On a phone: the options over the results, framed by a bar along the top.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black,
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 8, color: LcarsColours.coral),
        const SizedBox(height: 12),
        Expanded(child: child),
      ],
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({
    required this.hits,
    required this.repository,
    required this.selectedId,
    required this.onTap,
  });

  final List<SearchHit> hits;
  final ShipRepository repository;
  final String? selectedId;
  final ValueChanged<Ship> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final text = Theme.of(context).textTheme;
    return SliverList.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final hit = hits[i];
        final s = hit.ship;
        final where = '${s.era} · ${repository.faction(s.faction).name}';
        return ListTile(
          selected: s.id == selectedId,
          leading: ShipIcon(path: s.icon, name: s.name),
          title: Text(s.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.subtitle == null ? where : '${s.subtitle} · $where'),
              if (hit.reason != null)
                Text(
                  hit.reason!,
                  style: text.bodySmall?.copyWith(color: theme.data.first),
                ),
            ],
          ),
          onTap: () => onTap(s),
        );
      },
    );
  }
}

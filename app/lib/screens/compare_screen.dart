import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/ship_view.dart';
import '../theme/dex_theme.dart';
import '../ui/format.dart';
import '../ui/lcars.dart';
import '../ui/ship_icon.dart';
import 'front_page.dart';
import 'search_screen.dart';

/// Opens the search screen as a picker for a ship to set beside [ship], then
/// the comparison (#498). The picker gives way to the comparison, so BACK from
/// it returns to [ship]'s page.
void startCompare(BuildContext context, Ship ship, FrontPageData data) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (pickerContext) => SearchScreen(
        data: data,
        title: 'Compare with',
        onPick: (other) => Navigator.of(pickerContext).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => CompareScreen(data: data, left: ship, right: other),
          ),
        ),
      ),
    ),
  );
}

/// Two ships side by side (#498), in classic TNG LCARS: their measures, game
/// figures and weapons, each figure with a bar against the other's and the
/// better one lit (more hull, speed and weapons; less cost and build time).
class CompareScreen extends StatefulWidget {
  const CompareScreen({
    super.key,
    required this.data,
    required this.left,
    required this.right,
  });

  final FrontPageData data;
  final Ship left;
  final Ship right;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

/// Which way is better for a figure, if either is.
enum _Better { higher, lower, neither }

class _CompareScreenState extends State<CompareScreen> {
  late Ship _left = widget.left;
  late Ship _right = widget.right;

  void _change({required bool left}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pickerContext) => SearchScreen(
          data: widget.data,
          title: 'Compare with',
          onPick: (s) {
            Navigator.of(pickerContext).pop();
            setState(() => left ? _left = s : _right = s);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.data.repository;
    String where(Ship s) => '${s.era} · ${repo.faction(s.faction).name}';
    final a = _left, b = _right;

    num? crew(Ship s) => s.description?.crew;
    String? crewText(Ship s) => s.description?.crew == null
        ? null
        : (s.description!.crew == 0
              ? 'Unmanned'
              : thousands(s.description!.crew!));

    return DexThemeScope(
      child: Builder(
        builder: (context) {
          final theme = DexTheme.of(context);
          return LcarsFrame(
            title: 'Compare',
            footer: '${a.name} · ${b.name}',
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: _labelWidth),
                    Expanded(
                      child: _Header(
                        ship: a,
                        where: where(a),
                        onChange: () => _change(left: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Header(
                        ship: b,
                        where: where(b),
                        onChange: () => _change(left: false),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      final t = _left;
                      _left = _right;
                      _right = t;
                    }),
                    icon: Icon(Icons.swap_horiz, color: theme.structureAt(2)),
                    label: Text(
                      'SWAP',
                      style: theme
                          .heading(Theme.of(context).textTheme.labelLarge)
                          ?.copyWith(color: theme.structureAt(2)),
                    ),
                  ),
                ),
                const LcarsSectionTitle('Specifications'),
                _row(
                  'Length',
                  a.stats.length,
                  b.stats.length,
                  (v) => trimmed(v.toDouble()),
                ),
                _row(
                  'Width',
                  a.stats.width,
                  b.stats.width,
                  (v) => trimmed(v.toDouble()),
                ),
                _row(
                  'Crew',
                  crew(a),
                  crew(b),
                  (_) => '',
                  textA: crewText(a),
                  textB: crewText(b),
                ),
                _textRow('Class', _classOf(a), _classOf(b)),
                const LcarsSectionTitle('Game specs'),
                _row(
                  'Hull',
                  a.stats.maxHealth,
                  b.stats.maxHealth,
                  thousands,
                  better: _Better.higher,
                ),
                _row(
                  'Speed',
                  a.stats.maxSpeed,
                  b.stats.maxSpeed,
                  (v) => trimmed(v.toDouble()),
                  better: _Better.higher,
                ),
                _row(
                  'Cost',
                  a.stats.buildCost,
                  b.stats.buildCost,
                  (v) => '${thousands(v)} RU',
                  better: _Better.lower,
                ),
                _row(
                  'Build time',
                  a.stats.buildTime,
                  b.stats.buildTime,
                  (v) => duration(v.toDouble()),
                  better: _Better.lower,
                ),
                const LcarsSectionTitle('Weapons'),
                _row(
                  'Damage per second',
                  a.weapons.dps,
                  b.weapons.dps,
                  thousands,
                  better: _Better.higher,
                ),
                _row(
                  'Total',
                  a.weapons.total,
                  b.weapons.total,
                  thousands,
                  better: _Better.higher,
                ),
                _row(
                  'Beam',
                  a.weapons.beam,
                  b.weapons.beam,
                  thousands,
                  better: _Better.higher,
                ),
                _row(
                  'Pulse',
                  a.weapons.pulse,
                  b.weapons.pulse,
                  thousands,
                  better: _Better.higher,
                ),
                _row(
                  'Torpedo',
                  a.weapons.torpedo,
                  b.weapons.torpedo,
                  thousands,
                  better: _Better.higher,
                ),
                _row(
                  'Other',
                  a.weapons.other,
                  b.weapons.other,
                  thousands,
                  better: _Better.higher,
                ),
                const LcarsSectionTitle('Roles and abilities'),
                _textRow(
                  'Roles',
                  a.roles.map(roleLabel).join(', '),
                  b.roles.map(roleLabel).join(', '),
                ),
                _textRow(
                  'Abilities',
                  a.abilities.isEmpty
                      ? 'None'
                      : a.abilities.map((x) => x.name).join(', '),
                  b.abilities.isEmpty
                      ? 'None'
                      : b.abilities.map((x) => x.name).join(', '),
                ),
                const SizedBox(height: 12),
                Text(
                  'Each ship as built; variants are on its own page.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: theme.data.first),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _classOf(Ship s) => classLabel(s);

  Widget _row(
    String label,
    num? a,
    num? b,
    String Function(num) format, {
    _Better better = _Better.neither,
    String? textA,
    String? textB,
  }) => _CompareRow(
    label: label,
    a: a,
    b: b,
    textA: textA ?? (a == null ? null : format(a)),
    textB: textB ?? (b == null ? null : format(b)),
    better: better,
  );

  Widget _textRow(String label, String a, String b) =>
      _CompareRow(label: label, textA: a, textB: b);
}

const _labelWidth = 92.0;

class _Header extends StatelessWidget {
  const _Header({
    required this.ship,
    required this.where,
    required this.onChange,
  });

  final Ship ship;
  final String where;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShipIcon(path: ship.icon, name: ship.name, width: 128),
        const SizedBox(height: 6),
        Text(
          ship.name,
          style: theme
              .heading(text.titleLarge)
              ?.copyWith(color: theme.highlight),
        ),
        if (ship.subtitle != null) Text(ship.subtitle!, style: text.bodySmall),
        Text(where, style: text.bodySmall?.copyWith(color: theme.data.first)),
        const SizedBox(height: 6),
        SizedBox(
          width: 160,
          child: LcarsButton(label: 'Change', index: 3, onPressed: onChange),
        ),
      ],
    );
  }
}

/// One figure for both ships: the label, then each value with a bar scaled to
/// the larger of the two, the better one in the highlight colour.
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    this.a,
    this.b,
    required this.textA,
    required this.textB,
    this.better = _Better.neither,
  });

  final String label;
  final num? a;
  final num? b;
  final String? textA;
  final String? textB;
  final _Better better;

  @override
  Widget build(BuildContext context) {
    final theme = DexTheme.of(context);
    final text = Theme.of(context).textTheme;
    final top = math.max(a ?? 0, b ?? 0);
    bool wins(num? x, num? y) =>
        x != null &&
        y != null &&
        x != y &&
        switch (better) {
          _Better.higher => x > y,
          _Better.lower => x < y,
          _Better.neither => false,
        };

    Widget cell(num? v, String? t, bool win) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t ?? '—',
          style: text.titleMedium?.copyWith(
            color: win ? theme.highlight : null,
            fontWeight: win ? FontWeight.w700 : null,
          ),
        ),
        if (v != null && top > 0) ...[
          const SizedBox(height: 3),
          LayoutBuilder(
            builder: (context, c) => Container(
              width: math.max(4, c.maxWidth * v / top),
              height: 6,
              decoration: BoxDecoration(
                color: win
                    ? theme.highlight
                    : theme.data.first.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      label: '$label: ${textA ?? 'unknown'} against ${textB ?? 'unknown'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelWidth,
              child: Text(
                label.toUpperCase(),
                style: theme
                    .heading(text.labelLarge)
                    ?.copyWith(color: theme.structureAt(2)),
              ),
            ),
            Expanded(child: cell(a, textA, wins(a, b))),
            const SizedBox(width: 12),
            Expanded(child: cell(b, textB, wins(b, a))),
          ],
        ),
      ),
    );
  }
}

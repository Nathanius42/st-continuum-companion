import 'package:flutter/material.dart';

import '../data/home_content.dart';
import '../theme/dex_theme.dart';
import '../ui/format.dart';
import '../ui/lcars_display.dart';
import '../ui/lcars_motion.dart';
import '../ui/open_link.dart';
import '../ui/sound.dart';
import 'front_page.dart';

/// The front page's information sections (#941) on TNG displays. About, Comms,
/// Access and Credits follow the Starfleet personnel files: facts down the
/// left as "KEY: value" lines, and a framed panel on the right with a large
/// heading over the long text, which on a phone folds in under the facts.
/// Media is a holodeck programming display ("The Outrageous Okona"): a grid of
/// programs, one per trailer.
class _FileScreen extends StatelessWidget {
  const _FileScreen({
    required this.data,
    required this.section,
    required this.title,
    required this.facts,
    required this.heading,
    required this.file,
    this.pills = const [],
  });

  final FrontPageData data;

  /// Null for a page reached from a section, such as Credits.
  final Section? section;
  final String title;

  /// The left-hand side: facts, buttons, lists.
  final List<Widget> facts;

  /// The panel's large heading, top right.
  final String heading;

  /// The panel's text, under its heading.
  final List<Widget> file;

  /// Buttons in the top section, beside the figures.
  final List<Widget> pills;

  static const _columnColours = [
    LcarsColours.coral,
    LcarsColours.orange,
    LcarsColours.coral,
    LcarsColours.lilac,
  ];

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < LcarsDisplay.narrowWidth;
    final panel = [
      Semantics(
        header: true,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            heading.toUpperCase(),
            textAlign: TextAlign.right,
            style: _FileText.heading(context),
          ),
        ),
      ),
      const SizedBox(height: 8),
      ...file,
    ];
    return DexThemeScope(
      child: LcarsDisplay(
        title: title,
        topHeight: narrow ? 150 : 170,
        top: _FileTop(pills: pills, narrow: narrow),
        sidebar: sectionItems(context, data, current: section),
        panel: narrow
            ? null
            : LcarsPanel(
                width: 620,
                column: [
                  for (final (i, code) in const [
                    '3452',
                    '3299',
                    '0198',
                    '1006',
                  ].indexed)
                    LcarsItem(
                      label: code,
                      colour: _columnColours[i],
                      flex: i == 3 ? 3 : 2,
                    ),
                ],
                child: ListView(padding: EdgeInsets.zero, children: panel),
              ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ...facts,
            if (narrow) ...[
              const SizedBox(height: 20),
              Container(height: 10, color: LcarsColours.lilac),
              const SizedBox(height: 12),
              ...panel,
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// The top section: figures ticking over, then the pills.
class _FileTop extends StatelessWidget {
  const _FileTop({required this.pills, required this.narrow});

  final List<Widget> pills;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    const colours = [
      LcarsColours.periwinkle,
      LcarsColours.lavender,
      LcarsColours.gold,
      LcarsColours.periwinkle,
    ];
    final figures = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < (narrow ? 4 : 6); i++) ...[
            if (i > 0) const SizedBox(width: 14),
            LcarsReadout(
              seed: 70 + i,
              lines: 2,
              digits: i.isEven ? 9 : 4,
              colour: colours[i % colours.length],
            ),
          ],
        ],
      ),
    );
    final buttons = Wrap(spacing: 10, runSpacing: 10, children: pills);
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(height: 26, child: figures),
          const SizedBox(height: 8),
          buttons,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: SizedBox(height: 44, child: figures)),
        const SizedBox(width: 16),
        Flexible(child: buttons),
      ],
    );
  }
}

/// The personnel files' type: condensed capitals, keys in periwinkle and
/// values in orange.
abstract final class _FileText {
  static TextStyle key(BuildContext context) => TextStyle(
    fontFamily: DexTheme.of(context).headingFont,
    color: LcarsColours.periwinkle,
    fontSize: 21,
    height: 1.25,
    letterSpacing: 0.6,
  );

  static TextStyle value(BuildContext context) =>
      key(context).copyWith(color: LcarsColours.orange);

  static TextStyle body(BuildContext context) =>
      key(context)
          .copyWith(color: LcarsColours.orange, fontSize: 18, height: 1.35);

  static TextStyle heading(BuildContext context) =>
      key(context)
          .copyWith(color: LcarsColours.orange, fontSize: 38, height: 1.05);
}

/// "KEY: value", as the personnel files list their facts.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${label.toUpperCase()}: ',
            style: _FileText.key(context),
          ),
          TextSpan(text: value.toUpperCase(), style: _FileText.value(context)),
        ],
      ),
    ),
  );
}

/// A sub-heading in the file, such as "PERSONAL BIOGRAPHY:".
class _FileHeading extends StatelessWidget {
  const _FileHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Semantics(
      header: true,
      child: Text(
        '${text.toUpperCase()}:',
        style: _FileText.key(context).copyWith(fontSize: 24),
      ),
    ),
  );
}

/// Running text in the file.
class _FileBody extends StatelessWidget {
  const _FileBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: _FileText.body(context)),
  );
}

/// A wide pill that opens a link.
Widget _linkPill(
  Link link, {
  required Color colour,
  String? caption,
  Beep beep = Beep.select,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: LcarsPill(
    label: caption == null ? link.title : '${link.title} · $caption',
    semanticLabel: link.title,
    colour: colour,
    height: 48,
    beep: beep,
    onTap: () => openLink(link.url),
  ),
);

String _host(String url) {
  final host = Uri.parse(url).host.replaceFirst('www.', '');
  return switch (host) {
    'steamcommunity.com' => 'Steam',
    'moddb.com' => 'ModDB',
    'youtube.com' => 'YouTube',
    'discord.gg' => 'Discord',
    _ => host,
  };
}

const _pillColours = [
  LcarsColours.periwinkle,
  LcarsColours.lavender,
  LcarsColours.orange,
  LcarsColours.coral,
  LcarsColours.gold,
];

/// About: the mod's facts, the team and its Steam releases down the left, and
/// the mission and what the mod is about in the file.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.data});

  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    final c = data.content;
    return _FileScreen(
      data: data,
      section: Section.about,
      title: 'Continuum Corp · Personnel Files',
      pills: [
        SizedBox(
          width: 170,
          child: LcarsPill(
            label: 'Credits',
            semanticLabel: 'Credits: scripts, effects, music and maps',
            colour: LcarsColours.lavender,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreditsScreen(data: data),
              ),
            ),
          ),
        ),
      ],
      facts: [
        const _Fact('Mod', 'Star Trek: Continuum'),
        const _Fact('Engine', 'Homeworld Remastered'),
        const _Fact('Eras', '2160 · 2250 · 2310 · 2380'),
        _Fact('Subscribers', '${thousands(c.eraSubscribers)} across the eras'),
        const _FileHeading('Crew'),
        for (final (i, name) in c.team.indexed)
          _Fact('STC-${(i + 1).toString().padLeft(3, '0')}', name),
        const _FileHeading('Steam Workshop'),
        for (final s in c.steam) _SteamEntry(item: s),
        Text(
          'FIGURES AS OF ${c.steamAsOf}',
          style: _FileText.key(context).copyWith(fontSize: 15),
        ),
      ],
      heading: 'Star Trek: Continuum',
      file: [
        const _FileHeading('Mission'),
        _FileBody('"${c.mission.quote}" — ${c.mission.attribution}'),
        const _FileHeading('Service record'),
        for (final p in c.mission.about) _FileBody(p),
        const SizedBox(height: 8),
        Text(
          c.mission.disclaimer,
          style: _FileText.key(context).copyWith(fontSize: 14, height: 1.3),
        ),
      ],
    );
  }
}

/// One Steam release: its rating and subscribers, and the awards players gave.
class _SteamEntry extends StatelessWidget {
  const _SteamEntry({required this.item});

  final SteamItem item;

  @override
  Widget build(BuildContext context) {
    final title = item.title.replaceFirst('Star Trek: Continuum', 'STC');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            link: true,
            label:
                '$title, ${item.stars} stars, ${item.subscribers} subscribers',
            onTap: () => openLink(item.url),
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                Sounds.play(Beep.select);
                openLink(item.url);
              },
              child: _Fact(
                title,
                // Rated in words: the LCARS font has no star glyphs.
                'rating ${item.stars}/5 · '
                '${thousands(item.subscribers)} subscribers',
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (j, a) in item.awards.indexed)
                _AwardBadge(name: a.name, count: a.count, index: j),
            ],
          ),
        ],
      ),
    );
  }
}

/// A Steam award as an LCARS pill: its name, and how many players gave it.
class _AwardBadge extends StatelessWidget {
  const _AwardBadge({
    required this.name,
    required this.count,
    required this.index,
  });

  final String name;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: DexTheme.of(context).headingFont,
      color: Colors.black,
      fontSize: 14,
      letterSpacing: 1,
    );
    return Semantics(
      label: '$name award, given $count ${count == 1 ? 'time' : 'times'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 3, 4, 3),
        decoration: BoxDecoration(
          color: _pillColours[index % _pillColours.length],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name.toUpperCase(), style: style),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '×$count',
                style: style.copyWith(color: LcarsColours.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Credits beyond the ships: scripts, effects and shaders, music and maps, from
/// the mod's ReadMe.docx. Reached from About.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key, required this.data});

  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    final credits = data.content.credits;
    final half = (credits.length / 2).ceil();
    List<Widget> sections(Iterable<CreditSection> list) => [
      for (final s in list) ...[
        _FileHeading(s.heading),
        for (final line in s.lines) _FileBody(line),
      ],
    ];
    return _FileScreen(
      data: data,
      section: null,
      title: 'Mod Database Archive · Credits',
      facts: [
        const _Fact('File', 'Continuum credits'),
        const _Fact('Source', 'ReadMe.docx'),
        const _Fact('Ships', 'credited on each ship\'s page'),
        ...sections(credits.take(half)),
      ],
      heading: 'Credits',
      file: sections(credits.skip(half)),
    );
  }
}

/// Comms: the Discord, where help is given, and how to report a bug.
class CommsScreen extends StatelessWidget {
  const CommsScreen({super.key, required this.data});

  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    final c = data.content;
    return _FileScreen(
      data: data,
      section: Section.comms,
      title: 'Subspace Communications Net',
      pills: [
        SizedBox(
          width: 220,
          child: LcarsPill(
            label: 'Hail · Discord',
            semanticLabel: 'Open hailing frequencies: the Discord',
            colour: LcarsColours.orange,
            beep: Beep.hail,
            onTap: () => openLink(c.discord),
          ),
        ),
      ],
      facts: [
        const _Fact('Help', 'through the Discord'),
        const _Fact('Bug reports', 'through the Discord'),
        const SizedBox(height: 12),
        _linkPill(
          Link(title: 'Open hailing frequencies', url: c.discord),
          caption: 'Discord',
          colour: LcarsColours.orange,
          beep: Beep.hail,
        ),
        _linkPill(
          Link(title: 'Steam group', url: c.steamGroup),
          colour: LcarsColours.periwinkle,
        ),
        const _FileHeading('Guides'),
        for (final (i, l) in c.help.indexed)
          _linkPill(
            l,
            caption: _host(l.url),
            colour: _pillColours[(i + 1) % _pillColours.length],
          ),
      ],
      heading: 'Reporting a bug',
      file: [
        for (final (i, step) in c.reporting.indexed)
          _FileBody('${i + 1}. $step'),
      ],
    );
  }
}

/// Access: where to get the mod.
class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key, required this.data});

  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    final links = data.content.access;
    final steam = links.where((l) => _host(l.url) == 'Steam').toList();
    final other = links.where((l) => _host(l.url) != 'Steam').toList();
    return _FileScreen(
      data: data,
      section: Section.access,
      title: 'Online Records Access',
      facts: [
        const _Fact('Records', 'mod download locations'),
        const _Fact('Steam Workshop', 'one release per era'),
        const SizedBox(height: 12),
        for (final (i, l) in steam.indexed)
          _linkPill(l, colour: _pillColours[i % _pillColours.length]),
      ],
      heading: 'ModDB',
      file: [
        const _FileBody(
          'Subscribe on the Steam Workshop for each era, or download the '
          'Remastered installer from ModDB. Classic Continuum, for '
          'Homeworld 2, is on ModDB too.',
        ),
        const SizedBox(height: 8),
        for (final (i, l) in other.indexed)
          _linkPill(l, colour: _pillColours[(i + 2) % _pillColours.length]),
      ],
    );
  }
}

/// Media: the trailers, as programs on a holodeck programming display.
class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key, required this.data});

  final FrontPageData data;

  @override
  Widget build(BuildContext context) {
    final media = data.content.media;
    return DexThemeScope(
      child: LcarsDisplay(
        title: 'Holodeck Programming',
        topColours: const [
          LcarsColours.peach,
          LcarsColours.coral,
          LcarsColours.gold,
          LcarsColours.periwinkle,
        ],
        bandColours: const [
          LcarsColours.coral,
          LcarsColours.peach,
          LcarsColours.periwinkle,
        ],
        topHeight: 150,
        top: _FileTop(
          pills: const [],
          narrow: MediaQuery.sizeOf(context).width < LcarsDisplay.narrowWidth,
        ),
        sidebar: sectionItems(context, data, current: Section.media),
        child: LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 900 ? 2 : 1;
            final w = (c.maxWidth - (columns - 1) * 16) / columns;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final (i, l) in media.indexed)
                      SizedBox(
                        width: w,
                        child: _Program(link: l, number: i + 1),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A holodeck program: its number in a block, then its name on a pill.
/// The bundled thumbnail for a trailer: `assets/media/<YouTube id>.webp`, or the
/// video page's last path segment for one hosted elsewhere (ModDB).
String thumbnailFor(String url) {
  final uri = Uri.parse(url);
  final id = uri.queryParameters['v'] ?? uri.pathSegments.lastOrNull ?? '';
  return 'assets/media/$id.webp';
}

/// A holodeck program: its number and name on a pill. Tapping it opens its
/// thumbnail underneath, with a play mark; tapping that plays the trailer on
/// YouTube (or ModDB).
class _Program extends StatefulWidget {
  const _Program({required this.link, required this.number});

  final Link link;
  final int number;

  @override
  State<_Program> createState() => _ProgramState();
}

class _ProgramState extends State<_Program> {
  bool _open = false;

  Link get link => widget.link;
  int get number => widget.number;

  static const _blocks = [
    LcarsColours.periwinkle,
    LcarsColours.gold,
    LcarsColours.coral,
  ];
  static const _pills = [
    LcarsColours.peach,
    LcarsColours.lavender,
    LcarsColours.gold,
  ];

  @override
  Widget build(BuildContext context) {
    final code = number.toString().padLeft(2, '0');
    final font = DexTheme.of(context).headingFont;
    void toggle() => setState(() => _open = !_open);
    final program = Semantics(
      button: true,
      expanded: _open,
      label: 'Program $code: ${link.title}',
      onTap: toggle,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            Sounds.play(Beep.select);
            toggle();
          },
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Container(
                  width: 70,
                  color: _blocks[number % _blocks.length],
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 30,
                      height: 1,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    decoration: ShapeDecoration(
                      color: _pills[number % _pills.length],
                      shape: const StadiumBorder(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 4, 22, 6),
                    alignment: Alignment.bottomRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomRight,
                      child: Text(
                        // The mod's name is the same on every program.
                        '${link.title.replaceFirst(RegExp(r'^Star Trek: Continuum( - )?'), '')}'
                                ' · ${_host(link.url)}'
                            .toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: 20,
                          height: 1,
                          color: Colors.black,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        program,
        AnimatedSize(
          duration: DexTheme.of(context).transition,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 76, top: 8, bottom: 4),
                  child: _Thumbnail(link: link),
                ),
        ),
      ],
    );
  }
}

/// A trailer's thumbnail with a play mark: tapping it plays the trailer where
/// it's hosted.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context) {
    final host = _host(link.url);
    return Semantics(
      button: true,
      label: 'Play ${link.title} on $host',
      onTap: () => openLink(link.url),
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Material(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: LcarsColours.periwinkle, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Sounds.play(Beep.processing);
                  openLink(link.url);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      thumbnailFor(link.url),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    Center(
                      child: Container(
                        width: 72,
                        height: 50,
                        decoration: ShapeDecoration(
                          color: LcarsColours.orange.withValues(alpha: 0.92),
                          shape: const StadiumBorder(),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 40,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 8,
                      child: Text(
                        'PLAY ON ${host.toUpperCase()}',
                        style: TextStyle(
                          fontFamily: DexTheme.of(context).headingFont,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 1,
                          shadows: const [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

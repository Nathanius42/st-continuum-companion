import 'dart:convert';

import 'package:flutter/services.dart';

/// What the front page and its sections show (#941), from assets/data/home.json.
class HomeContent {
  const HomeContent({
    required this.mission,
    required this.team,
    required this.steamAsOf,
    required this.steam,
    required this.discord,
    required this.steamGroup,
    required this.help,
    required this.reporting,
    required this.access,
    required this.media,
    required this.credits,
    this.factions = const {},
  });

  factory HomeContent.fromJson(Map<String, dynamic> json) {
    final steam = json['steam'] as Map<String, dynamic>;
    final comms = json['comms'] as Map<String, dynamic>;
    return HomeContent(
      mission: Mission.fromJson(json['mission'] as Map<String, dynamic>),
      team: List<String>.from(json['team'] as List),
      steamAsOf: steam['asOf'] as String,
      steam: [
        for (final s in steam['items'] as List)
          SteamItem.fromJson(s as Map<String, dynamic>),
      ],
      discord: comms['discord'] as String,
      steamGroup: comms['steamGroup'] as String,
      help: _links(comms['help']),
      reporting: List<String>.from(comms['reporting'] as List),
      access: _links(json['access']),
      media: _links(json['media']),
      credits: [
        for (final c in json['credits'] as List)
          CreditSection.fromJson(c as Map<String, dynamic>),
      ],
      factions: {
        for (final e
            in (json['factions'] as Map<String, dynamic>? ?? {}).entries)
          if (!e.key.startsWith(r'$'))
            e.key: Map<String, String>.from(e.value as Map),
      },
    );
  }

  static Future<HomeContent> load(AssetBundle bundle) async =>
      HomeContent.fromJson(
        // Read once at start-up, so there's nothing to gain from the bundle's cache.
        jsonDecode(
          await bundle.loadString('assets/data/home.json', cache: false),
        ) as Map<String, dynamic>,
      );

  final Mission mission;
  final List<String> team;

  /// The date the Steam figures were taken, e.g. "2026-10-18".
  final String steamAsOf;
  final List<SteamItem> steam;
  final String discord;
  final String steamGroup;
  final List<Link> help;

  /// How to report a bug, step by step.
  final List<String> reporting;
  final List<Link> access;
  final List<Link> media;
  final List<CreditSection> credits;

  /// A blurb per faction, keyed by era where it changes over time, or by '*'.
  final Map<String, Map<String, String>> factions;

  /// The faction's blurb for [era], if there is one.
  String? factionBlurb(String faction, String era) =>
      factions[faction]?[era] ?? factions[faction]?['*'];

  /// Subscribers to the four era releases together.
  int get eraSubscribers =>
      steam.where((s) => s.era != null).fold(0, (n, s) => n + s.subscribers);
}

List<Link> _links(Object? json) => [
  for (final l in json as List) Link.fromJson(l as Map<String, dynamic>),
];

class Mission {
  const Mission({
    required this.quote,
    required this.attribution,
    required this.about,
    required this.disclaimer,
  });

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
    quote: json['quote'] as String,
    attribution: json['attribution'] as String,
    about: List<String>.from(json['about'] as List),
    disclaimer: json['disclaimer'] as String,
  );

  final String quote;
  final String attribution;
  final List<String> about;
  final String disclaimer;
}

class Link {
  const Link({required this.title, required this.url});

  factory Link.fromJson(Map<String, dynamic> json) =>
      Link(title: json['title'] as String, url: json['url'] as String);

  final String title;
  final String url;
}

/// One of the mod's Steam Workshop releases, with its awards.
class SteamItem {
  const SteamItem({
    required this.title,
    required this.era,
    required this.url,
    required this.subscribers,
    required this.favourites,
    required this.ratings,
    required this.stars,
    required this.awards,
  });

  factory SteamItem.fromJson(Map<String, dynamic> json) => SteamItem(
    title: json['title'] as String,
    era: json['era'] as String?,
    url: json['url'] as String,
    subscribers: json['subscribers'] as int,
    favourites: json['favourites'] as int,
    ratings: json['ratings'] as int,
    stars: json['stars'] as int,
    awards: [
      for (final a in json['awards'] as List)
        (name: (a as List)[0] as String, count: a[1] as int),
    ],
  );

  final String title;

  /// The era id for an era release; null for the original single release.
  final String? era;
  final String url;
  final int subscribers;
  final int favourites;
  final int ratings;

  /// Steam's star rating, out of five.
  final int stars;
  final List<({String name, int count})> awards;
}

class CreditSection {
  const CreditSection({required this.heading, required this.lines});

  factory CreditSection.fromJson(Map<String, dynamic> json) => CreditSection(
    heading: json['heading'] as String,
    lines: List<String>.from(json['lines'] as List),
  );

  final String heading;
  final List<String> lines;
}

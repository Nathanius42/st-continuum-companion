import 'package:flutter/material.dart';

import '../theme/dex_theme.dart';

/// A faction's emblem from the mod's badges (#442), decoded at the size it's
/// drawn. Factions without a badge get an outlined circle with their initial.
class FactionLogo extends StatelessWidget {
  const FactionLogo({
    super.key,
    required this.path,
    required this.name,
    this.size = 40,
  });

  final String? path;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colour = DexTheme.of(context).data.first;
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colour.withValues(alpha: 0.7), width: 2),
      ),
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(
          color: colour,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );
    if (path == null) return placeholder;
    return Image.asset(
      path!,
      width: size,
      height: size,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      semanticLabel: '$name emblem',
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

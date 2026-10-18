import 'package:flutter/material.dart';

import '../theme/dex_theme.dart';

/// A ship's icon from the game: a glowing outline, twice as wide as it is tall.
///
/// Images are decoded at the size they're drawn ([Image.cacheWidth]), so a long
/// list of icons doesn't hold full-size bitmaps in memory (#486). Ships without
/// an icon get a placeholder with the first letter of their name.
class ShipIcon extends StatelessWidget {
  const ShipIcon({
    super.key,
    required this.path,
    required this.name,
    this.width = 64,
  });

  final String? path;
  final String name;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width / 2;
    final placeholder = _Placeholder(name: name, width: width, height: height);
    if (path == null) return placeholder;
    return Image.asset(
      path!,
      width: width,
      height: height,
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      fit: BoxFit.contain,
      semanticLabel: '$name icon',
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.name,
    required this.width,
    required this.height,
  });

  final String name;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colour = DexTheme.of(context).data.first;
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Container(
          width: height * 1.4,
          height: height * 0.8,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: colour.withValues(alpha: 0.7), width: 2),
            ),
          ),
          child: Text(
            name.characters.first.toUpperCase(),
            style: TextStyle(
              color: colour,
              fontWeight: FontWeight.bold,
              fontSize: height * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:continuum_dex/app.dart';
import 'package:continuum_dex/screens/ship_browser_screen.dart';

/// Runs the real app on a device or desktop (#506, #544): the bundled data,
/// themes, fonts and icons load through the asset bundle exactly as in a
/// release, and each window size walks era → faction → ship page.
///
///   flutter test integration_test/app_test.dart -d windows
///
/// Screenshots of each step go to build/integration_shots/.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // On a phone the app can only write to its own storage; pull the shots with
  // `adb exec-out run-as au.mollaworkshop.continuum_dex cat <file>`.
  final shots = Directory(
    Platform.isAndroid || Platform.isIOS
        ? '${Directory.systemTemp.path}/integration_shots'
        : 'build/integration_shots',
  )..createSync(recursive: true);
  const shotKey = Key('shot');

  Future<void> shot(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${shots.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  /// Pumps until [finder] shows, for screens that wait on real asset loading.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
    await tester.pumpAndSettle();
  }

  setUpAll(() => debugPrint('Screenshots: ${shots.path}'));

  for (final (name, size) in [
    ('phone', const Size(412, 900)),
    ('tablet', const Size(800, 1100)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$name: the real app loads and navigates', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const RepaintBoundary(key: shotKey, child: DexApp()));
      await pumpUntil(tester, find.bySemanticsLabel(RegExp('^The Next Generation,')));
      await shot(tester, '${name}_1_home');

      await tester.tap(find.bySemanticsLabel(RegExp('^The Next Generation,')));
      await pumpUntil(tester, find.text('FEDERATION'));
      await shot(tester, '${name}_2_factions');

      await tester.tap(find.text('FEDERATION'));
      await pumpUntil(tester, find.byType(ShipList));
      await tester.scrollUntilVisible(find.text('Galaxy'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Galaxy').first);
      await tester.pumpAndSettle();
      // Let the icons decode for real before the screenshot.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();
      await shot(tester, '${name}_3_ship');

      final saucer = find.widgetWithText(ChoiceChip, 'Saucer');
      await tester.ensureVisible(saucer);
      await tester.pumpAndSettle();
      await tester.tap(saucer);
      await tester.pumpAndSettle();
      expect(find.text('65,100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

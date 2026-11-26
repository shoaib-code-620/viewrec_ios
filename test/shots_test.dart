import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewrec/screens/caption_studio.dart';
import 'package:viewrec/screens/media_profile.dart';
import 'package:viewrec/screens/pricing.dart';
import 'package:viewrec/screens/welcome.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

/// Not part of the normal suite: run with `flutter test test/shots_test.dart` to write PNGs of key screens.
const out = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots');

void main() {
  final shots = <String, Widget Function()>{
    'home': () => const Shell(initialIndex: 0),
    'reviews': () => const Shell(initialIndex: 1),
    'welcome': () => const WelcomeScreen(),
    'phonebook': () => const Shell(initialIndex: 3),
    'studio': () => const CaptionStudioScreen(),
    'create': () => const Shell(initialIndex: 2),
    'profile': () => const PublicProfileScreen(businessId: 'b1'),
    'followers': () => const FollowListScreen(businessId: 'b1', name: 'Brightside Dental'),
    'phonebook_scrolled': () => const Shell(initialIndex: 3),
    'where': () => const Shell(initialIndex: 7),
    'pricing': () => const PricingScreen(),
    'more': () => const Shell(initialIndex: kMoreIndex),
    'media': () => const Shell(initialIndex: kMediaIndex),
    'settings': () => const Shell(initialIndex: 10),
  };
  for (final e in shots.entries) {
    testWidgets('shot ${e.key}', (tester) async {
      tester.view.physicalSize = Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      C.dark = false;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(theme: buildTheme(dark: false), debugShowCheckedModeBanner: false, home: e.value()),
      ));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));
      if (e.key == 'phonebook_scrolled') {
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -640));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File('$out/${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests normally draw text with a blocky placeholder font, which makes every
/// line look far too wide. Load the real Roboto from the Flutter SDK so
/// overflow checks match what a phone shows.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'D:/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-light.ttf', 'roboto-black.ttf', 'roboto-italic.ttf']) {
    final file = File('$dir/$f');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
  }
  await loader.load();

  // The app's own font (variable Manrope), so text is measured as it will be on a phone.
  final manrope = File('assets/fonts/Manrope.ttf');
  if (manrope.existsSync()) {
    final l = FontLoader('Manrope')..addFont(Future.value(ByteData.view(manrope.readAsBytesSync().buffer)));
    await l.load();
  }
  await testMain();
}

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
  // The new look's font, in the weights the app uses.
  final jakarta = FontLoader('PlusJakartaSans');
  var found = false;
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final f = File('assets/fonts/PlusJakartaSans-$w.ttf');
    if (f.existsSync()) {
      jakarta.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      found = true;
    }
  }
  if (found) await jakarta.load();
  await testMain();
}

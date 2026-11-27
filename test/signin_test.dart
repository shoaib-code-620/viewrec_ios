import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/screens/sign_in.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

void main() {
  testWidgets('Sign in has the name on top and Google, Apple and email at the bottom', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    C.dark = false;
    C.special = false;
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(theme: buildTheme(dark: false), home: const SignInScreen())));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('ViewRec'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    final nameY = t.getTopLeft(find.byKey(const ValueKey('signin_name'))).dy;
    final googleY = t.getTopLeft(find.byKey(const ValueKey('signin_google'))).dy;
    final emailY = t.getTopLeft(find.byKey(const ValueKey('signin_email'))).dy;
    expect(nameY, lessThan(200));
    expect(googleY, greaterThan(400));
    expect(emailY, greaterThan(googleY));
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/shots').createSync(recursive: true);
      File('build/shots/signin.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await t.tap(find.text('Continue with Google'));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Shell), findsOneWidget);
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}

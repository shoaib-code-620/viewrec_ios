import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/screens/media_explore.dart';
import 'package:viewrec/screens/media_profile.dart';
import 'package:viewrec/screens/media_widgets.dart';
import 'package:viewrec/repo.dart';
import 'package:viewrec/theme.dart';
import 'package:viewrec/theme_controller.dart';

Future<void> _phone(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
  C.special = false;
  SharedPreferences.setMockInitialValues({});
}

Future<void> _pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester t) async {
  await _pumpFor(t, 2000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('Special mode is a theme of its own and follows the phone brightness', (t) async {
    await _phone(t);
    final ctl = ThemeController.instance;
    await ctl.setMode(AppThemeMode.special);
    expect(C.special, isTrue);
    expect(ThemeController.instance.mode.name, 'special');
    await ctl.setMode(AppThemeMode.dark);
    expect(C.special, isFalse);
    expect(C.dark, isTrue);
    await ctl.setMode(AppThemeMode.light);
    expect(C.dark, isFalse);
    expect(AppThemeMode.values.map((m) => m.name), ['light', 'dark', 'special']);
    await ctl.setMode(AppThemeMode.light);
    C.special = false;
  });

  testWidgets('A caption shows tags in blue and a tap opens the tag page', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: CaptionText(name: 'Hartley Roofing', text: 'Great job #5stars @someone')))));
    await _pumpFor(t, 300);
    final rich = t.widget<RichText>(find.byType(RichText).first);
    final texts = <String>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.text != null) texts.add(s.text!);
      return true;
    });
    expect(texts, contains('#5stars'));
    expect(texts, contains('@someone'));
    await _finish(t);
  });

  testWidgets('The tag page lists the posts that use the tag', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const HashtagScreen(tag: '5stars')));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1500)));
    await _pumpFor(t, 800);
    expect(find.text('#5stars'), findsWidgets);
    expect(find.byType(ReelTile), findsWidgets);
    await _finish(t);
  });

  testWidgets('Your profile has Posts, Reels, Saved and Tagged tabs', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Scaffold(body: PublicProfileScreen(businessId: kMyBusinessId))));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1500)));
    await _pumpFor(t, 1500);
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.byKey(const ValueKey('gridtab_Saved')), 300, scrollable: list);
    expect(find.byKey(const ValueKey('gridtab_Reels')), findsOneWidget);
    expect(find.byKey(const ValueKey('gridtab_Tagged')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('gridtab_Tagged')));
    await _pumpFor(t, 500);
    expect(find.text('No tagged posts'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('gridtab_Saved')));
    await _pumpFor(t, 500);
    await _finish(t);
  });

  testWidgets('Comments can be liked and replied to', (t) async {
    await _phone(t);
    final reel = (await t.runAsync(() => MockRepo().reels()))!.first;
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => showCommentsSheet(c, reel, () {}), child: const Text('open'))))));
    await t.tap(find.text('open'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1500)));
    await _pumpFor(t, 1200);
    expect(find.text('Reply'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('like_c1')));
    await _pumpFor(t, 400);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await t.tap(find.text('Reply').first);
    await _pumpFor(t, 400);
    expect((t.widget(find.byType(TextField)) as TextField).controller!.text, startsWith('@Sophie'));
    await _finish(t);
  });
}
